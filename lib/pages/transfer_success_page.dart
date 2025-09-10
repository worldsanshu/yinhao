// lib/pages/transfer_success_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../widgets/explorer_sheet.dart';
enum AssetType { trx, usdt }

class TransferSuccessPage extends StatefulWidget {
  final String txId;
  final String fromAddress; // base58
  final String toAddress;   // base58
  final String amount;      // 已格式化字符串
  final AssetType asset;
  final String? tronApiKey;
  final String endpoint;

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
  String? _status;
  int? _blockNumber;
  double? _feeTrx;
  int? _energy;
  int? _bandwidth;
  DateTime? _timestamp;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 初始化中文本地化（防止 intl 抛异常）
    initializeDateFormatting('zh_CN', null).catchError((_){});
    _fetchOnce();
    // 轮询直到确认；也支持手动下拉刷新
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

  // 将任何 dynamic 安全转换为 Map<String, dynamic>
  Map<String, dynamic> _asMap(dynamic x) {
    if (x is Map) {
      return x.map((k, v) => MapEntry(k?.toString() ?? '', v));
    }
    return <String, dynamic>{};
  }

  int _asInt(dynamic x) {
    if (x is int) return x;
    if (x is String) return int.tryParse(x) ?? 0;
    if (x is num) return x.toInt();
    return 0;
    }

  Future<void> _fetchOnce() async {
    try {
      setState(() {
        _error = null;
        _loading = true;
      });

      final infoUrl =
          Uri.parse('${widget.endpoint}/wallet/gettransactioninfobyid');
      final txUrl = Uri.parse('${widget.endpoint}/wallet/gettransactionbyid');

      final infoResp = await http.post(infoUrl,
          headers: _headers, body: jsonEncode({'value': widget.txId}));
      if (infoResp.statusCode != 200) {
        throw Exception('gettransactioninfobyid ${infoResp.statusCode}');
      }
      final infoAny = jsonDecode(infoResp.body);
      final info = _asMap(infoAny);

      final txResp = await http.post(txUrl,
          headers: _headers, body: jsonEncode({'value': widget.txId}));
      if (txResp.statusCode == 200) {
        final txAny = jsonDecode(txResp.body);
        final tx = _asMap(txAny);
        final rawData = _asMap(tx['raw_data']);
        final tsMs = rawData['timestamp'];
        if (tsMs is int) {
          _timestamp = DateTime.fromMillisecondsSinceEpoch(tsMs);
        } else if (tsMs is String) {
          final t = int.tryParse(tsMs);
          if (t != null) _timestamp = DateTime.fromMillisecondsSinceEpoch(t);
        }
      }

      final receipt = _asMap(info['receipt']);
      final status = receipt['result']?.toString();
      final block = info['blockNumber'];
      final feeSun = _asInt(info['fee']); // 单位 sun
      final energy = _asInt(receipt['energy_usage_total']);
      final netFee = _asInt(receipt['net_fee']); // sun
      final bandwidth = netFee ~/ 1000; // 仅展示参考

      setState(() {
        _status = status;
        _blockNumber = (block is int) ? block : int.tryParse(block?.toString() ?? '');
        _feeTrx = feeSun / 1e6;
        _energy = energy;
        _bandwidth = bandwidth;
        _confirmed = status == 'SUCCESS' && _blockNumber != null;
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
  String _fmtAddr(String a) => a.length <= 12 ? a : '${a.substring(0,6)}...${a.substring(a.length-6)}';
  String _fmtTime(DateTime? t) {
    final d = t ?? DateTime.now();
    try {
      if (DateFormat.localeExists('zh_CN')) {
        return DateFormat('yyyy年MM月dd日 aa h点mm分', 'zh_CN').format(d);
      }
    } catch (_) {}
    return DateFormat('yyyy-MM-dd HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final waiting = !_confirmed;
    final statusText = waiting ? '等待确认' : '已完成';

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易详情'),
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
      body: RefreshIndicator( // ✅ 下拉刷新
        onRefresh: _fetchOnce,
        child: _buildBody(context, statusText, waiting),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String statusText, bool waiting) {
    final theme = Theme.of(context);
    final ts = _fmtTime(_timestamp);
    final fee = _feeTrx != null ? _feeTrx!.toStringAsFixed(6) : '-';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                alignment: Alignment.center,
                child: waiting ? const Text('...', style: TextStyle(fontSize: 24))
                               : const Icon(Icons.check_circle, size: 36),
              ),
              const SizedBox(height: 10),
              Text(statusText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              _kvRow(context, '发送', '${widget.amount} $_assetLabel', bold: true),
              const SizedBox(height: 10),
              _addrRow(context, 'From', widget.fromAddress),
              const SizedBox(height: 8),
              _addrRow(context, 'To', widget.toAddress),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text('交易详情', style: TextStyle(fontWeight: FontWeight.w600, color: theme.hintColor)),
        const SizedBox(height: 8),
        _sectionCard(
          context,
          child: Column(
            children: [
              _kvRow(context, '网络', 'Tron'),
              if (_blockNumber != null) _kvRow(context, '区块高度', _blockNumber.toString()),
              _kvRow(context, '矿工费', '$fee TRX'),
              _kvRow(context, '资产类型', widget.asset == AssetType.usdt ? 'USDT（TRC20）' : 'TRX'),
              if (_status != null) _kvRow(context, '执行结果', (_status ?? '').toString()),
              if (_energy != null) _kvRow(context, '能量消耗', '$_energy'),
              if (_bandwidth != null) _kvRow(context, '带宽消耗', '$_bandwidth'),
              _kvRow(context, '交易号', widget.txId, mono: true, copyable: true),
              if (_error != null) ...[
                const Divider(height: 20),
                Text('拉取链上信息失败：$_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  final txId = widget.txId;
	                final url = Uri.parse('https://tronscan.org/#/transaction/${txId.toLowerCase()}').toString();
                  await Clipboard.setData(ClipboardData(text: url.toString()));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制 Tronscan 链接到剪贴板')),
                    );
                  }
                   ExplorerSheet.show(context, url: url);
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
          SizedBox(width: 80, child: Text(k, style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    v,
                    style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.normal, fontFamily: mono ? 'monospace' : null),
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addrRow(BuildContext context, String label, String addr) {
    final show = _fmtAddr(addr);
    return _kvRow(context, label, show, mono: true, copyable: true);
  }
}
