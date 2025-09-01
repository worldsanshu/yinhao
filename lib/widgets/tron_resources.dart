// lib/widgets/tron_resources.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/crypto_service.dart';

/// 更贴合整页风格的紧凑版 TRON 资源组件：在余额下方以两个“统计胶囊”显示
/// - 左：能量  可用/总量
/// - 右：带宽  可用/总量
/// 右上角提供微型刷新按钮；轻触任一胶囊会弹出底部卡片显示“已用”细节。
class TronResourcesPanel extends StatefulWidget {
  final String addressBase58;
  final EdgeInsetsGeometry padding;
  final String? tronEndpointOverride;
  final bool dense;           // 紧凑模式（默认 true）
  final bool showTip;         // 是否显示提示文案（默认 false，减少占位）

  const TronResourcesPanel({
    super.key,
    required this.addressBase58,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 6),
    this.tronEndpointOverride,
    this.dense = true,
    this.showTip = false,
  });

  @override
  State<TronResourcesPanel> createState() => _TronResourcesPanelState();
}

class _TronResourcesPanelState extends State<TronResourcesPanel> {
  bool _loading = false;
  int _energyLimit = 0;
  int _energyUsed = 0;
  int _netLimit = 0;
  int _netUsed = 0;
  DateTime? _ts;

  @override
  void initState() {
    super.initState();
    _restoreFromCache();
    _fetch();
  }

  String _endpoint() {
    final ep = widget.tronEndpointOverride ?? (Hive.box('settings').get('tron_endpoint') as String?);
    return (ep == null || ep.isEmpty) ? 'https://api.trongrid.io' : ep;
  }

  void _restoreFromCache() {
    final key = 'detail_resources_${widget.addressBase58}';
    final m = Hive.box('settings').get(key);
    if (m is Map) {
      setState(() {
        _energyLimit = (m['energyLimit'] ?? 0) as int;
        _energyUsed = (m['energyUsed'] ?? 0) as int;
        _netLimit = (m['netLimit'] ?? 0) as int;
        _netUsed = (m['netUsed'] ?? 0) as int;
        final s = m['ts'] as String?;
        _ts = (s != null) ? DateTime.tryParse(s) : null;
      });
    }
  }

  Future<void> _saveToCache() async {
    final key = 'detail_resources_${widget.addressBase58}';
    await Hive.box('settings').put(key, {
      'energyLimit': _energyLimit,
      'energyUsed': _energyUsed,
      'netLimit': _netLimit,
      'netUsed': _netUsed,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final ep = _endpoint();
      bool ok = await _tryV1(ep);
      if (!ok) ok = await _tryWalletGetAccountResource(ep);
      if (ok) {
        await _saveToCache();
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取资源失败: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _tryV1(String ep) async {
    try {
      final url = Uri.parse('${ep.replaceAll(RegExp(r'/+$'), '')}/v1/accounts/${widget.addressBase58}/resources');
      final r = await http.get(url, headers: {'accept': 'application/json'});
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      Map<String, dynamic>? m;
      if (j is Map && j['data'] is List && (j['data'] as List).isNotEmpty) {
        m = Map<String, dynamic>.from((j['data'] as List).first as Map);
      } else if (j is Map) {
        m = Map<String, dynamic>.from(j);
      }
      if (m == null) return false;
      _assignFromMap(m);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryWalletGetAccountResource(String ep) async {
    try {
      final hex41 = TronAddressUtils.base58ToHex41(widget.addressBase58);
      final url = Uri.parse('${ep.replaceAll(RegExp(r'/+$'), '')}/wallet/getaccountresource');
      final r = await http.post(url,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'address': hex41}));
      if (r.statusCode != 200) return false;
      final m0 = jsonDecode(r.body);
      if (m0 is! Map) return false;
      _assignFromMap(Map<String, dynamic>.from(m0 as Map));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _assignFromMap(Map<String, dynamic> m) {
    int energyLimit = _pickInt(m, const ['energyLimit', 'EnergyLimit']);
    int energyUsed  = _pickInt(m, const ['energyUsed', 'EnergyUsed']);
    int freeNetLimit = _pickInt(m, const ['freeNetLimit', 'FreeNetLimit']);
    int freeNetUsed  = _pickInt(m, const ['freeNetUsed', 'FreeNetUsed']);
    int netLimit     = _pickInt(m, const ['netLimit', 'NetLimit']);
    int netUsed      = _pickInt(m, const ['netUsed', 'NetUsed']);
    final bwLimit = (freeNetLimit > 0 || freeNetUsed > 0) ? (freeNetLimit + netLimit) : netLimit;
    final bwUsed  = (freeNetLimit > 0 || freeNetUsed > 0) ? (freeNetUsed + netUsed)   : netUsed;
    setState(() {
      _energyLimit = energyLimit;
      _energyUsed  = energyUsed;
      _netLimit    = bwLimit;
      _netUsed     = bwUsed;
      _ts = DateTime.now();
    });
  }

  int _pickInt(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  String _fmtNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final j = s.length - 1 - i;
      buf.write(s[i]);
      if (j > 0 && j % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  void _showDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final energyAvail = (_energyLimit - _energyUsed).clamp(0, _energyLimit);
        final netAvail = (_netLimit - _netUsed).clamp(0, _netLimit);
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('TRON 资源详情', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_ts != null)
                    Text('更新: ${_ts!.toLocal().toIso8601String().substring(0,19).replaceFirst('T',' ')}',
                        style: text.bodySmall?.copyWith(color: theme.hintColor)),
                ],
              ),
              const SizedBox(height: 12),
              _detailLine(theme, '能量 (Energy)',
                  '${_fmtNum(energyAvail)} / ${_fmtNum(_energyLimit)}', '已用 ${_fmtNum(_energyUsed)}', Icons.bolt),
              const SizedBox(height: 8),
              _detailLine(theme, '带宽 (Bandwidth / Net)',
                  '${_fmtNum(netAvail)} / ${_fmtNum(_netLimit)}', '已用 ${_fmtNum(_netUsed)}', Icons.network_check),
              if (widget.showTip) ...[
                const SizedBox(height: 8),
                Text('提示：能量足够可显著降低 USDT 转账手续费；能量不足将消耗 TRX。',
                    style: text.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final chipBorder = BorderSide(color: theme.dividerColor.withOpacity(0.35));
    final fg = theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;

    final energyAvail = (_energyLimit - _energyUsed).clamp(0, _energyLimit);
    final netAvail = (_netLimit - _netUsed).clamp(0, _netLimit);

    final chipTextStyle = widget.dense
        ? text.bodySmall?.copyWith(fontWeight: FontWeight.w600)
        : text.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TRON 资源', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              if (_ts != null)
                Text('· ${_ts!.toLocal().toIso8601String().substring(11, 19)}',
                    style: text.bodySmall?.copyWith(color: theme.hintColor)),
              const Spacer(),
              IconButton(
                splashRadius: 18,
                iconSize: 18,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                tooltip: '刷新资源',
                onPressed: _loading ? null : _fetch,
              )
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _statChip(
                context,
                icon: Icons.bolt,
                label: '能量',
                value: '${_fmtNum(energyAvail)} / ${_fmtNum(_energyLimit)}',
                textStyle: chipTextStyle,
                fg: fg,
                chipBorder: chipBorder,
              ),
              _statChip(
                context,
                icon: Icons.network_check,
                label: '带宽',
                value: '${_fmtNum(netAvail)} / ${_fmtNum(_netLimit)}',
                textStyle: chipTextStyle,
                fg: fg,
                chipBorder: chipBorder,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      TextStyle? textStyle,
      required Color fg,
      required BorderSide chipBorder}) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showDetailSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent, // 跟随背景，不额外加卡片底色
          borderRadius: BorderRadius.circular(999),
          border: Border.fromBorderSide(chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: textStyle),
            const SizedBox(width: 6),
            Text(value, style: textStyle?.copyWith(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(ThemeData theme, String title, String value, String sub, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(value),
        const SizedBox(width: 12),
        Text(sub, style: TextStyle(color: theme.hintColor)),
      ],
    );
  }
}
