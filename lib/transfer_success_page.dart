// lib/pages/transfer_success_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

enum AssetType { trx, usdt }

class TransferSuccessPage extends StatefulWidget {
  final String txId;
  final String fromAddress; // base58
  final String toAddress;   // base58
  final String amount;      // 原始字符串，已按资产单位格式化（如 "757" / "0.123456"）
  final AssetType asset;
  final String? tronApiKey;
  final String endpoint; // TronGrid 或自建节点 REST 入口

  const TransferSuccessPage({
    super.key,
    required this.txId,
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
    required this.asset,
    this.tronApiKey,
    this.endpoint = 'https://api.trongrid.io',
  });

  @override
  State<TransferSuccessPage> createState() => _TransferSuccessPageState();
}

class _TransferSuccessPageState extends State<TransferSuccessPage> {
  Timer? _timer;
  bool _loading = true;
  bool _confirmed = false;
  String? _status; // SUCCESS / REVERT / OUT_OF_ENERGY / null
  int? _blockNumber;
  int? _confirmations; // 粗略：当前最新块 - _blockNumber
  double? _feeTrx; // 交易费用（单位 TRX）
  int? _energy;
  int? _bandwidth;
  DateTime? _timestamp; // 从交易信息里拿（ms）
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOnce();
    // 轮询直到确认
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchOnce());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (widget.tronApiKey?.isNotEmpty == true)
          'TRON-PRO-API-KEY': widget.tronApiKey!,
      };

  Future<void> _fetchOnce() async {
    try {
      final infoUrl =
          Uri.parse('${widget.endpoint}/wallet/gettransactioninfobyid');
      final txUrl =
          Uri.parse('${widget.endpoint}/wallet/gettransactionbyid');

      // 交易执行信息（包含确认状态、区块号、费用）
      final infoResp = await http.post(infoUrl,
          headers: _headers, body: jsonEncode({'value': widget.txId}));
      if (infoResp.statusCode != 200) {
        throw Exception('gettransactioninfobyid ${infoResp.statusCode}');
      }
      final info = jsonDecode(infoResp.body) as Map<String, dynamic>;

      // 原始交易（拿时间戳）
      final txResp = await http.post(txUrl,
          headers: _headers, body: jsonEncode({'value': widget.txId}));
      if (txResp.statusCode == 200) {
        final tx = jsonDecode(txResp.body) as Map<String, dynamic>;
        final rawData = (tx['raw_data'] ?? {}) as Map<String, dynamic>;
        final tsMs = rawData['timestamp'];
        if (tsMs is int) {
          _timestamp = DateTime.fromMillisecondsSinceEpoch(tsMs);
        }
      }

      // 解析信息
      final receipt = (info['receipt'] ?? {}) as Map<String, dynamic>;
      final status = receipt['result'] as String?; // SUCCESS / REVERT ...
      final block = info['blockNumber'] as int?;
      final feeSun = (info['fee'] ?? 0) as int; // 单位 sun
      final energy = (receipt['energy_usage_total'] ?? 0) as int;
      final netFee = (receipt['net_fee'] ?? 0) as int; // 带宽消耗的 sun
      final bandwidth = netFee ~/ 1000; // 近似：1k sun ≈ 1 带宽, 仅展示参考

      setState(() {
        _status = status;
        _blockNumber = block;
        _feeTrx = feeSun / 1e6;
        _energy = energy;
        _bandwidth = bandwidth;
        _confirmed = status == 'SUCCESS' && block != null;
        _loading = false;
      });

      if (_confirmed) {
        _timer?.cancel();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _assetLabel => widget.asset == AssetType.trx ? 'TRX' : 'USDT';

  String _fmtAddr(String a) {
    if (a.length <= 12) return a;
    return '${a.substring(0, 6)}...${a.substring(a.length - 6)}';
  }

  String _fmtTime(DateTime? t) {
    final tt = t ?? DateTime.now();
    final f = DateFormat('yyyy年MM月dd日 aa h点mm分', 'zh_CN');
    return f.format(tt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = _confirmed;
    final waiting = !_confirmed;

    final title = ok ? '交易详情' : '交易详情';
    final statusText = waiting ? '等待确认' : '已完成';
    final statusColor = waiting
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final data =
                  'txID: ${widget.txId}\nfrom: ${widget.fromAddress}\nto: ${widget.toAddress}\namount: ${widget.amount} $_assetLabel';
              await Clipboard.setData(ClipboardData(text: data));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制交易信息到剪贴板')),
                );
              }
            },
          )
        ],
      ),
      body: _buildBody(context, statusText, statusColor, waiting),
    );
  }

  Widget _buildBody(
      BuildContext context, String statusText, Color statusColor, bool waiting) {
    final theme = Theme.of(context);
    final ts = _fmtTime(_timestamp);
    final fee = _feeTrx != null ? _feeTrx!.toStringAsFixed(6) : '-';
    final amountStr = '${widget.amount} $_assetLabel';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 状态块
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                alignment: Alignment.center,
                child: waiting
                    ? const Text('...', style: TextStyle(fontSize: 24))
                    : const Icon(Icons.check_circle, size: 36),
              ),
              const SizedBox(height: 10),
              Text(statusText,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text(ts, style: TextStyle(color: theme.hintColor, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 概览卡
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kvRow(context, '发送', amountStr, bold: true),
              const SizedBox(height: 10),
              _addrRow(context, 'From', widget.fromAddress),
              const SizedBox(height: 8),
              _addrRow(context, 'To', widget.toAddress),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text('交易详情',
            style:
                TextStyle(fontWeight: FontWeight.w600, color: theme.hintColor)),
        const SizedBox(height: 8),
        _sectionCard(
          context,
          child: Column(
            children: [
              _kvRow(context, '网络', 'Tron'),
              if (_blockNumber != null)
                _kvRow(context, '区块高度', _blockNumber.toString()),
              _kvRow(context, '矿工费', '$fee TRX'),
              if (widget.asset == AssetType.usdt)
                _kvRow(context, '资产类型', 'USDT（TRC20）')
              else
                _kvRow(context, '资产类型', 'TRX'),
              if (_energy != null) _kvRow(context, '能量消耗', '$_energy'),
              if (_bandwidth != null) _kvRow(context, '带宽消耗', '$_bandwidth'),
              _kvRow(context, '交易号', widget.txId, mono: true, copyable: true),
              if (_error != null) ...[
                const Divider(height: 20),
                Text('拉取链上信息失败：$_error',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 打开浏览器查看
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Tronscan 查看'),
                onPressed: () async {
                  final url = Uri.parse('https://tronscan.org/#/transaction/${widget.txId}');
                  await Clipboard.setData(ClipboardData(text: url.toString()));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制 Tronscan 链接到剪贴板')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
      ),
      child: child,
    );
  }

  Widget _kvRow(BuildContext context, String k, String v,
      {bool mono = false, bool bold = false, bool copyable = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(k,
                  style: TextStyle(
                      color: theme.hintColor, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    v,
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: mono ? 'monospace' : null,
                    ),
                  ),
                ),
                if (copyable)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: v));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已复制$k')),
                        );
                      }
                    },
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _addrRow(BuildContext context, String label, String addr) {
    return _kvRow(context, label, _fmtAddr(addr), mono: true, copyable: true);
  }
}
