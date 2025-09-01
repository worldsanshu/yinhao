import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// A compact, drop-in panel showing recent TRX & USDT (TRC20) activity for a Tron address,
/// plus quick jump buttons to open the address / individual tx on Tronscan (or any explorer origin).
///
/// How to use in your wallet_detail_page:
///   1) Add dependency in pubspec.yaml: url_launcher: ^6.3.0
///   2) In AppBar actions: TronActivityPanel.explorerAction(addressBase58)
///   3) In body: TronActivityPanel(addressBase58: entry.addressBase58)
///
class TronActivityPanel extends StatefulWidget {
  final String addressBase58;
  final String explorerOrigin; // e.g. 'https://tronscan.org/#'
  final String nodeApiBase; // e.g. 'https://api.trongrid.io'
  final String? tronProApiKey; // optional for TronGrid
  final String usdtContractBase58; // mainnet USDT default
  final int limit;

  const TronActivityPanel({
    super.key,
    required this.addressBase58,
    this.explorerOrigin = 'https://tronscan.org/#',
    this.nodeApiBase = 'https://api.trongrid.io',
    this.tronProApiKey,
    this.usdtContractBase58 = 'TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9',
    this.limit = 25,
  });

  /// Quick AppBar action to open the address on explorer.
  static Widget explorerAction(String addressBase58, {String explorerOrigin = 'https://tronscan.org/#'}) {
    return IconButton(
      tooltip: '在区块浏览器打开',
      icon: const Icon(Icons.open_in_new),
      onPressed: () {
        final url = Uri.parse('$explorerOrigin/address/$addressBase58');
        launchUrl(url, mode: LaunchMode.externalApplication);
      },
    );
  }

  @override
  State<TronActivityPanel> createState() => _TronActivityPanelState();
}

class _TronActivityPanelState extends State<TronActivityPanel> {
  bool _loading = false;
  String? _error;
  List<_TxRow> _items = [];

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (widget.tronProApiKey != null && widget.tronProApiKey!.isNotEmpty) 'TRON-PRO-API-KEY': widget.tronProApiKey!,
      };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trx = await _fetchTrxTransfers(widget.addressBase58, limit: widget.limit);
      final usdt = await _fetchTrc20Transfers(
        widget.addressBase58,
        widget.usdtContractBase58,
        limit: widget.limit,
      );
      final all = [...trx, ...usdt]
        ..sort((a, b) => b.blockTs.compareTo(a.blockTs));
      if (!mounted) return;
      setState(() {
        _items = all;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<_TxRow>> _fetchTrxTransfers(String addr, {int limit = 25}) async {
    final uri = Uri.parse('${widget.nodeApiBase}/v1/accounts/$addr/transactions'
        '?limit=$limit&only_confirmed=true&order_by=block_timestamp,desc');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('TRX历史查询失败：HTTP ${res.statusCode}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final List data = (m['data'] as List?) ?? const [];
    final out = <_TxRow>[];

    for (final it in data) {
      try {
        final txId = (it['txID'] ?? it['txid'] ?? '') as String;
        if (txId.isEmpty) continue;
        final ts = (it['block_timestamp'] ?? it['raw_data']?['timestamp'] ?? 0) as int;

        // success
        bool success = true;
        if (it['ret'] is List && (it['ret'] as List).isNotEmpty) {
          final r0 = (it['ret'] as List).first;
          final cr = (r0 is Map && r0['contractRet'] is String) ? r0['contractRet'] as String : 'SUCCESS';
          success = cr == 'SUCCESS';
        }

        // parse contract
        final contracts = (it['raw_data']?['contract'] as List?) ?? const [];
        if (contracts.isEmpty) continue;
        final c0 = contracts.first as Map<String, dynamic>;
        final type = (c0['type'] ?? c0['contract_type'] ?? '') as String;
        if (!type.contains('TransferContract')) continue; // only TRX transfers
        final val = (c0['parameter']?['value'] ?? c0['parameter'] ?? const {}) as Map<String, dynamic>;
        // TronGrid有时返回base58字段，也有时是41hex字段，尽量同时兼容
        final from = (val['owner_address'] ?? val['ownerAddress'] ?? '') as String;
        final to = (val['to_address'] ?? val['toAddress'] ?? '') as String;
        final rawAmount = (val['amount'] ?? 0) as int; // TRX用sun整数

        final dir = from == addr ? _Direction.out : _Direction._in;
        final meSide = dir == _Direction._in ? to : from; // 对端地址

        out.add(_TxRow(
          txId: txId,
          asset: 'TRX',
          amount6: BigInt.from(rawAmount),
          blockTs: ts,
          dir: dir,
          peer: dir == _Direction._in ? from : to,
          success: success,
        ));
      } catch (_) {
        // ignore a bad row; keep resilient
      }
    }
    return out;
  }

  Future<List<_TxRow>> _fetchTrc20Transfers(String addr, String contract, {int limit = 25}) async {
    final uri = Uri.parse('${widget.nodeApiBase}/v1/accounts/$addr/transactions/trc20'
        '?limit=$limit&only_confirmed=true&contract_address=$contract&order_by=block_timestamp,desc');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('TRC20历史查询失败：HTTP ${res.statusCode}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final List data = (m['data'] as List?) ?? const [];
    final out = <_TxRow>[];

    for (final it in data) {
      try {
        final txId = (it['transaction_id'] ?? '') as String;
        if (txId.isEmpty) continue;
        final ts = (it['block_timestamp'] ?? 0) as int;
        final from = (it['from'] ?? '') as String;
        final to = (it['to'] ?? '') as String;
        final valStr = (it['value'] ?? '0') as String; // decimal string
        final tokenInfo = (it['token_info'] ?? const {}) as Map<String, dynamic>;
        final symbol = (tokenInfo['symbol'] ?? 'USDT') as String;
        final decimals = (tokenInfo['decimals'] is int) ? tokenInfo['decimals'] as int : 6;
        // value 可能超大，用BigInt
        final amount = BigInt.parse(valStr);
        final dir = from == addr ? _Direction.out : _Direction._in;
        out.add(_TxRow(
          txId: txId,
          asset: symbol,
          amount6: _scaleTo6(amount, decimals),
          blockTs: ts,
          dir: dir,
          peer: dir == _Direction._in ? from : to,
          success: true,
        ));
      } catch (_) {
        // ignore bad row
      }
    }
    return out;
  }

  static BigInt _scaleTo6(BigInt amount, int fromDecimals) {
    if (fromDecimals == 6) return amount;
    if (fromDecimals > 6) {
      final diff = fromDecimals - 6;
      return amount ~/ BigInt.from(pow(10, diff));
    } else {
      final diff = 6 - fromDecimals;
      return amount * BigInt.from(pow(10, diff));
    }
  }

  String _fmtAmount6(BigInt v) {
    final neg = v.isNegative;
    final u = v.abs();
    final whole = u ~/ BigInt.from(1000000);
    final frac = (u % BigInt.from(1000000)).toString().padLeft(6, '0');
    final trimmedFrac = frac.replaceFirst(RegExp(r'0+\$'), '');
    final s = trimmedFrac.isEmpty ? whole.toString() : '${whole.toString()}.$trimmedFrac';
    return neg ? '-$s' : s;
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.addressBase58;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('在浏览器查看'),
              onPressed: () {
                final url = Uri.parse('${widget.explorerOrigin}/address/$address');
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = _items[i];
                      final dt = DateTime.fromMillisecondsSinceEpoch(t.blockTs).toLocal();
                      final sign = t.dir == _Direction._in ? '+' : '-';
                      final color = t.dir == _Direction._in ? Colors.green : Colors.red;
                      final amount = _fmtAmount6(t.amount6);
                      final title = Text('$sign $amount ${t.asset}', style: TextStyle(color: color, fontWeight: FontWeight.w600));
                      final sub = Text(
                        '${t.dir == _Direction._in ? '来自' : '发往'}: ${_short(t.peer)}\n${dt.toString()}${t.success ? '' : ' · 失败'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                      return ListTile(
                        leading: CircleAvatar(child: Text(t.asset == 'TRX' ? 'T' : 'U')),
                        title: title,
                        subtitle: sub,
                        trailing: IconButton(
                          tooltip: '在浏览器查看交易',
                          icon: const Icon(Icons.link),
                          onPressed: () {
                            final url = Uri.parse('${widget.explorerOrigin}/transaction/${t.txId}');
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                        ),
                        onTap: () {
                          final url = Uri.parse('${widget.explorerOrigin}/transaction/${t.txId}');
                          launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _short(String s) => s.length <= 12 ? s : '${s.substring(0, 6)}…${s.substring(s.length - 4)}';
}

enum _Direction { _in, out }

class _TxRow {
  final String txId;
  final String asset; // TRX or USDT
  final BigInt amount6; // scaled to 6 decimals
  final int blockTs; // ms
  final _Direction dir;
  final String peer; // counterparty address (base58)
  final bool success;
  _TxRow({
    required this.txId,
    required this.asset,
    required this.amount6,
    required this.blockTs,
    required this.dir,
    required this.peer,
    required this.success,
  });
}
