// lib/pages/wallet_list_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/wallet_entry.dart';
import '../services/tron_client.dart';
import '../services/usdt_service.dart';

import 'wallet_create_page.dart';
import 'wallet_detail_page.dart';
import 'settings_page.dart';

class WalletListPage extends StatefulWidget {
  const WalletListPage({super.key});
  @override
  State<WalletListPage> createState() => _WalletListPageState();
}

class _WalletListPageState extends State<WalletListPage> {
  // 首屏缓存 + 偏好
  bool _hideBalances = false;

  // 资产汇总/默认余额（字符串，便于直接展示）
  String? _totalUsdt;
  String? _totalTrx;
  String? _defaultUsdt;
  String? _defaultTrx;

  @override
  void initState() {
    super.initState();
    final s = Hive.box('settings');
    _hideBalances = (s.get('hide_balances') as bool?) ?? false;

    // 读取缓存，保证首屏有数
    final t = s.get('totals_balances') as Map?;
    _totalUsdt = t?['usdt'] as String?;
    _totalTrx = t?['trx'] as String?;
    final d = s.get('default_balances') as Map?;
    _defaultUsdt = d?['usdt'] as String?;
    _defaultTrx = d?['trx'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = Hive.box('wallets');
    final settings = Hive.box('settings');

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的钱包'),
        actions: [
          IconButton(
            tooltip: '新增钱包',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletCreatePage()),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: wallets.listenable(),
        builder: (_, __, ___) {
          // 排序 keys（最新创建在前）
          final keys = wallets.keys.toList();
          keys.sort((a, b) {
            final ea = WalletEntry.tryFrom(wallets.get(a));
            final eb = WalletEntry.tryFrom(wallets.get(b));
            return (eb?.createdAt.millisecondsSinceEpoch ?? 0)
                .compareTo(ea?.createdAt.millisecondsSinceEpoch ?? 0);
          });

          // —— 默认钱包识别逻辑
          final defaultId = settings.get('default_wallet_id') as String?;
          WalletEntry? defaultWallet;

          // 1) 优先用 settings 指定的 id
          if (defaultId != null) {
            defaultWallet = _findById(defaultId);
          }
          // 2) 其次找 isDefault==true 的
          defaultWallet ??= keys
              .map((k) => WalletEntry.tryFrom(wallets.get(k)))
              .whereType<WalletEntry>()
              .cast<WalletEntry?>()
              .firstWhere(
                (e) => (e?.isDefault ?? false),
                orElse: () => null,
              );
          // 3) 兜底：没有任何默认时，用第一条作为“临时默认”仅用于展示（不写回设置）
          defaultWallet ??= keys.isNotEmpty
              ? WalletEntry.tryFrom(wallets.get(keys.first))
              : null;

          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async => _refreshAll(keys, defaultWallet),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // —— 顶部：资产总览（总资产 + 默认钱包卡）
                SliverToBoxAdapter(
                  child: _buildHeader(
                    count: keys.length,
                    defaultWallet: defaultWallet,
                  ),
                ),

                if (keys.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('还没有钱包')),
                  )
                else
                  SliverList.separated(
                    itemCount: keys.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, thickness: 0.2),
                    itemBuilder: (_, i) {
                      final e = WalletEntry.tryFrom(wallets.get(keys[i]));
                      if (e == null) {
                        return const ListTile(title: Text('未知条目'));
                      }

                      // 星标：isDefault==true 或 id == settings.default_wallet_id
                      final isDefault = (e.isDefault ?? false) ||
                          (defaultId != null && e.id == defaultId);

                      final hasName = (e.name?.trim().isNotEmpty ?? false);
                      final title = hasName ? e.name!.trim() : e.addressBase58;
                      final subtitle = hasName
                          ? e.addressBase58
                          : '创建于 ${e.createdAt.toLocal().toString().split('.').first}';

                      return ListTile(
                        leading: Icon(isDefault
                            ? Icons.star
                            : Icons.account_balance_wallet),
                        title: Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            switch (v) {
                              case 'default':
                                _setDefault(e.id);
                                break;
                              case 'rename':
                                _renameWallet(e);
                                break;
                              case 'export':
                                _exportOne(e);
                                break;
                              case 'detail':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          WalletDetailPage(walletId: e.id)),
                                );
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            if (!isDefault)
                              const PopupMenuItem(
                                  value: 'default', child: Text('设为默认')),
                            const PopupMenuItem(
                                value: 'rename', child: Text('重命名')),
                            const PopupMenuItem(
                                value: 'export', child: Text('导出该钱包')),
                            const PopupMenuItem(
                                value: 'detail', child: Text('查看详情')),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => WalletDetailPage(walletId: e.id)),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================== UI：资产总览（美化配色 + 显示/隐藏 + 刷新） ==================

  Widget _buildHeader({
    required int count,
    required WalletEntry? defaultWallet,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 渐变：浅色蓝→青 / 深色石板
    final gradient = LinearGradient(
      colors: isDark
          ? const [
              Color(0xFF1E293B),
              Color(0xFF0F172A)
            ] // slate-800 → slate-900
          : const [Color(0xFF2563EB), Color(0xFF06B6D4)], // blue-600 → cyan-500
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // 卡片内块底色 & 前景色（保证对比度）
    final tileBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.90);
    final tileFg = isDark ? Colors.white : Colors.black87;

    // 展示值（可隐藏）
    final usdt = _hideBalances ? '***' : (_totalUsdt ?? '--');
    final trx = _hideBalances ? '***' : (_totalTrx ?? '--');
    final defUsdt = _hideBalances ? '***' : (_defaultUsdt ?? '--');
    final defTrx = _hideBalances ? '***' : (_defaultTrx ?? '--');

    // 上次更新时间
    final ts =
        (Hive.box('settings').get('totals_balances') as Map?)?['ts'] as String?;
    final tsText = ts == null ? '' : '上次 ${ts.split(".").first}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工具行：标题 + 钱包数 + 眼睛 + 刷新
          Row(
            children: [
              Text('资产总览',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('钱包数',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ),
              const SizedBox(width: 6),
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: _hideBalances ? '显示金额' : '隐藏金额',
                icon: Icon(
                    _hideBalances ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white),
                onPressed: _toggleHide,
              ),
              IconButton(
                tooltip: '刷新（下拉也可）',
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () async {
                  final keys = Hive.box('wallets').keys.toList();
                  await _refreshAll(keys, defaultWallet);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 指标块（总资产）
          Row(
            children: [
              Expanded(
                child: _metricTile(
                    title: '总 USDT',
                    value: usdt,
                    icon: Icons.attach_money,
                    bg: tileBg,
                    fg: tileFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricTile(
                    title: '总 TRX',
                    value: trx,
                    icon: Icons.token,
                    bg: tileBg,
                    fg: tileFg),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 默认钱包卡（找不到也不影响汇总展示）
          if (defaultWallet != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (defaultWallet.name?.trim().isNotEmpty ?? false)
                              ? defaultWallet.name!.trim()
                              : defaultWallet.addressBase58,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: tileFg),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _chip('USDT', defUsdt, fg: tileFg),
                            _chip('TRX', defTrx, fg: tileFg),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新默认',
                    icon: Icon(Icons.refresh, color: tileFg),
                    onPressed: () => _refreshDefaultBalances(defaultWallet),
                  ),
                ],
              ),
            ),

          if (tsText.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: Colors.white24),
            const SizedBox(height: 6),
            Text(tsText,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ],
      ),
    );
  }

  Widget _metricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          ),
          Text(value, style: TextStyle(fontSize: 16, color: fg)),
        ],
      ),
    );
  }

  Widget _chip(String k, String v, {required Color fg}) {
    return Chip(
      label: Text('$k: $v', style: TextStyle(color: fg)),
      backgroundColor: fg.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide(color: fg.withOpacity(0.12)),
    );
  }

  // ================== 交互逻辑 ==================

  void _toggleHide() async {
    setState(() => _hideBalances = !_hideBalances);
    await Hive.box('settings').put('hide_balances', _hideBalances);
  }

  // 下拉或按钮刷新：总资产 + 默认余额
  Future<void> _refreshAll(
      List<dynamic> keys, WalletEntry? defaultWallet) async {
    await Future.wait([
      _refreshTotals(keys),
      if (defaultWallet != null) _refreshDefaultBalances(defaultWallet),
    ]);
  }

  // 根据当前设置的网关创建服务（即时生效）
  UsdtService _svc() {
    final ep = (Hive.box('settings').get('tron_endpoint') as String?) ??
        'https://api.trongrid.io';
    return UsdtService(TronClient(endpoint: ep));
  }

  Future<void> _refreshTotals(List<dynamic> keys) async {
    try {
      final s = _svc();
      double sumUsdt = 0.0, sumTrx = 0.0;
      for (final k in keys) {
        final e = WalletEntry.tryFrom(Hive.box('wallets').get(k));
        if (e == null) continue;
        final (trx, usdt) = await s.balances(e.addressBase58);
        sumUsdt += double.tryParse(usdt) ?? 0.0;
        sumTrx += double.tryParse(trx) ?? 0.0;
      }
      _totalUsdt = _fmt(sumUsdt);
      _totalTrx = _fmt(sumTrx);
      await Hive.box('settings').put('totals_balances', {
        'usdt': _totalUsdt,
        'trx': _totalTrx,
        'ts': DateTime.now().toIso8601String(),
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('汇总失败: $e')));
      }
    }
  }

  Future<void> _refreshDefaultBalances(WalletEntry e) async {
    try {
      final s = _svc();
      final (trx, usdt) = await s.balances(e.addressBase58);
      await Hive.box('settings').put('default_balances', {
        'usdt': usdt,
        'trx': trx,
        'ts': DateTime.now().toIso8601String(),
      });
      _defaultUsdt = usdt;
      _defaultTrx = trx;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刷新失败: $e')));
      }
    }
  }

  Future<void> _setDefault(String id) async {
    final wallets = Hive.box('wallets');
    final settings = Hive.box('settings');

    for (final k in wallets.keys) {
      final cur = WalletEntry.tryFrom(wallets.get(k));
      if (cur == null) continue;
      final updated = cur.copyWith(isDefault: cur.id == id);
      await wallets.put(cur.id, updated.toJson()); // 你当前是 Map 存储
    }
    await settings.put('default_wallet_id', id);

    if (!mounted) return;
    setState(() {});
    final e = _findById(id);
    if (e != null) _refreshDefaultBalances(e);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已设为默认')));
  }

  Future<void> _renameWallet(WalletEntry e) async {
    final ctl = TextEditingController(text: e.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名钱包'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            hintText: '输入新的名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (newName == null) return;

    final name = newName.trim();
    final updated = e.copyWith(name: name.isEmpty ? null : name);
    await Hive.box('wallets').put(e.id, updated.toJson());
    if (mounted) setState(() {});
  }

  Future<void> _exportOne(WalletEntry e) async {
    final json = jsonEncode(e.toJson());
    await Share.share(json, subject: 'Wallet backup: ${e.addressBase58}');
  }

  // ================== utils ==================

  String _fmt(double v) {
    final s = v.toStringAsFixed(6);
    return s.contains('.')
        ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : s;
  }

  WalletEntry? _findById(String id) {
    final box = Hive.box('wallets');
    for (final k in box.keys) {
      final e = WalletEntry.tryFrom(box.get(k));
      if (e != null && e.id == id) return e;
    }
    return null;
  }
}
