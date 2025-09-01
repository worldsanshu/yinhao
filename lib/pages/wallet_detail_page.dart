// lib/pages/wallet_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/wallet_entry.dart';
import '../services/tron_client.dart';
import '../services/usdt_service.dart';

import 'transfer_page.dart'; // TransferPage + AssetType
import '../widgets/tron_activity.dart';
import '../widgets/explorer_sheet.dart';
import '../widgets/tron_resources.dart';
import 'energy_purchase_page.dart';
class WalletDetailPage extends StatefulWidget {
  const WalletDetailPage({super.key, required this.walletId});
  final String walletId;

  @override
  State<WalletDetailPage> createState() => _WalletDetailPageState();
}

class _WalletDetailPageState extends State<WalletDetailPage> {
  String? _usdt;
  String? _trx;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 可选：读取缓存，首屏显示更快（若之前有缓存）
    final cache =
        (Hive.box('settings').get('detail_balances_${widget.walletId}') as Map?) ??
            {};
    _usdt = cache['usdt'] as String?;
    _trx = cache['trx'] as String?;
  }

  // =============== UI & 监听合并 ===============

  @override
  Widget build(BuildContext context) {
    final wallets = Hive.box('wallets');
    final settings = Hive.box('settings');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg =
        isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.90);
    final tileFg = isDark ? Colors.white : Colors.black87;

    // 用 AnimatedBuilder 监听两个 box（避免 ValueListenable 类型不匹配）
    final merged = Listenable.merge([
      wallets.listenable(),
      settings.listenable(),
    ]);
    debugPrint('box=${wallets.name}, length=${wallets.length}');
 
    for (final key in wallets.keys) {
      debugPrint('[$key] => ${wallets.get(key)}');
    }
    debugPrint(wallets.toMap().toString()); // 内容多会自动分行
    final e = _entryOf(wallets, widget.walletId);
    final String? address = e?.addressBase58; // 可空

        // 打开地址页
   
    return Scaffold(
      appBar: AppBar(
        title: const Text('钱包详情'),
        actions: [
          // if (address != null && address.isNotEmpty)
          // TronActivityPanel.explorerAction(address),
        
           IconButton(
      tooltip: '在区块浏览器打开',
      icon: const Icon(Icons.open_in_new),
      onPressed: () {
         final url = ExplorerSheet.tronscanUrl(
              origin: 'https://tronscan.org/#', // 可改你喜欢的浏览器域名
              path: 'address/$address',
            );
             ExplorerSheet.show(context, url: url);
         },),
          IconButton(
            tooltip: '二维码',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () {
              final e = _entryOf(wallets, widget.walletId);
              if (e != null) _showQr(e);
            },
          ),
          IconButton(
            tooltip: '重命名',
            icon: const Icon(Icons.edit),
            onPressed: () {
              final e = _entryOf(wallets, widget.walletId);
              if (e != null) _renameWallet(e);
            },
          ),
          IconButton(
            tooltip: '刷新余额',
            icon: _loading
                ? const SizedBox(
                    width: 18, 
                    height: 18, 
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
                   onPressed: _loading
                ? null
                : () async {
                    final e = _entryOf(wallets, widget.walletId);
                    if (e != null) await _refresh(e);
               
                  },
          ),
          IconButton(
            tooltip: '导出钱包',
            icon: const Icon(Icons.ios_share),
            onPressed: () {
              final e = _entryOf(wallets, widget.walletId);
              if (e != null) _exportOne(e);
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: merged,
        builder: (context, _) {
          final e = _entryOf(wallets, widget.walletId);
          if (e == null) {
            return const Center(child: Text('未找到该钱包'));
          }

          final defaultId = settings.get('default_wallet_id') as String?;
          final isDefault = (e.isDefault ?? false) || (defaultId == e.id);
          final name = (e.name?.trim().isNotEmpty ?? false) ? e.name!.trim() : null;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ===== 基本信息卡 =====
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行（名称/星标/设为默认）
                    Row(
                      children: [
                        if (isDefault) const Icon(Icons.star, color: Colors.amber),
                        if (isDefault) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            name ?? e.addressBase58,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: tileFg,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isDefault)
                          TextButton.icon(
                            onPressed: () => _setDefault(e.id),
                            icon: const Icon(Icons.star),
                            label: const Text('设为默认'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('地址（Base58）',
                        style: TextStyle(color: tileFg.withOpacity(0.7))),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SelectableText(
                            e.addressBase58,
                            style:
                                TextStyle(fontFamily: 'monospace', color: tileFg),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '复制地址',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: e.addressBase58));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已复制地址')));
                          },
                          icon: Icon(Icons.copy, color: tileFg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('地址（Hex）',
                        style: TextStyle(color: tileFg.withOpacity(0.7))),
                    const SizedBox(height: 6),
                    SelectableText(
                      e.addressHex,
                      style: TextStyle(fontFamily: 'monospace', color: tileFg),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '创建于：${e.createdAt.toLocal().toString().split('.').first}',
                      style: const TextStyle(fontSize: 12, color: Color.fromARGB(137, 230, 230, 230)),
                    ),
                    const SizedBox(height: 8),
                    // 二维码快速入口（卡片内也给一个按钮，和 AppBar 的图标互补）
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _showQr(e),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('显示收款二维码'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 余额卡 =====
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('余额',
                        style:
                            TextStyle(fontWeight: FontWeight.w600, color: tileFg)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                              'USDT', _usdt ?? '--', Icons.attach_money,
                              fg: tileFg),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child:
                              _metricTile('TRX', _trx ?? '--', Icons.token, fg: tileFg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _refresh(e),
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: const Text('刷新余额'),
                      ),
                    ),
                  ],
                ),
              ),

const SizedBox(height: 8),

// 👉 新增：TRON 资源面板（能量/带宽）
// TronResourcesPanel(addressBase58: e.addressBase58),
TronResourcesPanel(
  addressBase58: e.addressBase58,
  dense: true,       // 紧凑
  showTip: false,    // 如需底部说明可设 true
),
              const SizedBox(height: 12),

              // ===== 快捷操作卡 =====
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('快捷操作',
                        style:
                            TextStyle(fontWeight: FontWeight.w600, color: tileFg)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text('转账 USDT'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransferPage(
                                  walletId: e.id,
                                  initialAsset: AssetType.usdt,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text('转账 TRX'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransferPage(
                                  walletId: e.id,
                                  initialAsset: AssetType.trx,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
const SizedBox(height: 8),
SizedBox(
  width: double.infinity,
  child: FilledButton.icon(
    icon: const Icon(Icons.bolt),
    label: const Text('购买能量'),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnergyPurchasePage(walletId: e.id),
      ),
    ),
  ),
),


                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _renameWallet(e),
                            icon: const Icon(Icons.edit),
                            label: const Text('重命名'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _exportOne(e),
                            icon: const Icon(Icons.ios_share),
                            label: const Text('导出该钱包'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      
        
        

            ],
          );
        },
      ),
    );
  }

  // =============== 逻辑 ===============

  WalletEntry? _entryOf(Box box, String id) {
    final raw = box.get(id);
    return WalletEntry.tryFrom(raw);
  }

  UsdtService _svc() {
    final ep =
        (Hive.box('settings').get('tron_endpoint') as String?) ??
            'https://api.trongrid.io';
    return UsdtService(TronClient(endpoint: ep));
  }

  Future<void> _refresh(WalletEntry e) async {
    setState(() => _loading = true);
    try {
      final s = _svc();
      final (trx, usdt) = await s.balances(e.addressBase58);
      _trx = trx;
      _usdt = usdt;
      await Hive.box('settings').put('detail_balances_${e.id}', {
        'trx': trx,
        'usdt': usdt,
        'ts': DateTime.now().toIso8601String(),
      });
      if (mounted) setState(() {});
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刷新失败: $err')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setDefault(String id) async {
    final wallets = Hive.box('wallets');
    final settings = Hive.box('settings');
    for (final k in wallets.keys) {
      final cur = WalletEntry.tryFrom(wallets.get(k));
      if (cur == null) continue;
      final updated = cur.copyWith(isDefault: cur.id == id);
      await wallets.put(cur.id, updated.toJson()); // 你当前用 Map 存
    }
    await settings.put('default_wallet_id', id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已设为默认')));
    }
  }

  Future<void> _exportOne(WalletEntry e) async {
    final json = jsonEncode(e.toJson());
    await Share.share(json, subject: 'Wallet backup: ${e.addressBase58}');
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName == null) return;
    final name = newName.trim();
    final updated = e.copyWith(name: name.isEmpty ? null : name);
    await Hive.box('wallets').put(e.id, updated.toJson());
    if (mounted) setState(() {});
  }

  void _showQr(WalletEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : const Color.fromARGB(221, 138, 138, 138);
          final fg2 = isDark ? Colors.white : Colors.black87;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 20),
                  const SizedBox(width: 8),
                  const Text('收款二维码'),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:  Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: e.addressBase58,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                e.addressBase58,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', color: fg),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: e.addressBase58));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('已复制地址')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('复制地址'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          Share.share(e.addressBase58, subject: 'TRON Address'),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('分享'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =============== 小部件 ===============

  Widget _metricTile(String title, String value, IconData icon,
      {required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
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
}
