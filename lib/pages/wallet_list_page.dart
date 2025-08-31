import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/wallet_entry.dart';
import '../services/backup_service.dart';
import '../services/default_wallet_store.dart';
import 'wallet_create_page.dart';
import 'wallet_detail_page.dart';
import 'backup_import_page.dart';
import 'package:flutter/services.dart';        // 需要有Clipboard

class WalletListPage extends StatefulWidget {
  const WalletListPage({super.key});
  @override
  State<WalletListPage> createState() => _WalletListPageState();
}

class _WalletListPageState extends State<WalletListPage> {
  String? _defaultId;

  @override
  void initState() {
    super.initState();
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    final id = await DefaultWalletStore.get();
    if (mounted) setState(() => _defaultId = id);
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('wallets');
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的钱包'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: '导出全部',
            onPressed: () {
              final json = BackupService.exportAll(box);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _ExportSheet(content: json),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '导入备份',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupImportPage()));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletCreatePage())),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (_, __, ___) {
          final keys = box.keys.toList();
          if (keys.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有钱包'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletCreatePage())),
                    icon: const Icon(Icons.add),
                    label: const Text('创建钱包'),
                  ),
                ],
              ),
            );
          }
          keys.sort((a, b) {
            final ea = WalletEntry.tryFrom(box.get(a));
            final eb = WalletEntry.tryFrom(box.get(b));
            return (eb?.createdAt.millisecondsSinceEpoch ?? 0).compareTo(ea?.createdAt.millisecondsSinceEpoch ?? 0);
          });
          return ListView.separated(
            itemCount: keys.length,
            separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.2),
            itemBuilder: (_, i) {
              final key = keys[i];
              final e = WalletEntry.tryFrom(box.get(key));
              if (e == null) return const ListTile(title: Text('未知条目'));
              final isDefault = (e.isDefault == true) || (e.id == _defaultId);
              return ListTile(
                leading: Icon(isDefault ? Icons.star : Icons.account_balance_wallet),
                title: Text(e.addressBase58, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('创建于 ${e.createdAt}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'default') {
                      await _setDefault(box, e.id);
                    } else if (v == 'export') {
                      final json = BackupService.exportAll(box);
                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _ExportSheet(content: json),
                      );
                    } else if (v == 'delete') {
                      await box.delete(e.id);
                      if (_defaultId == e.id) {
                        await DefaultWalletStore.clear();
                        if (mounted) setState(() => _defaultId = null);
                      }
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'default', child: Text('设为默认钱包')),
                    PopupMenuItem(value: 'export', child: Text('导出（所有）')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletDetailPage(walletId: e.id))),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _setDefault(Box box, String id) async {
    for (final k in box.keys) {
      final e = WalletEntry.tryFrom(box.get(k));
      if (e == null) continue;
      final updated = WalletEntry(
        id: e.id,
        addressBase58: e.addressBase58,
        addressHex: e.addressHex,
        encPrivateKeyB64: e.encPrivateKeyB64,
        nonceB64: e.nonceB64,
        salt1B64: e.salt1B64,
        salt2B64: e.salt2B64,
        salt3B64: e.salt3B64,
        masterSaltB64: e.masterSaltB64,
        pbkdf2Iterations: e.pbkdf2Iterations,
        hint1: e.hint1,
        hint2: e.hint2,
        hint3: e.hint3,
        createdAt: e.createdAt,
        version: e.version,
        isDefault: e.id == id,
      );
      await box.put(e.id, updated.toJson());
    }
    await DefaultWalletStore.set(id);
    if (mounted) setState(() => _defaultId = id);
  }
}

class _ExportSheet extends StatelessWidget {
  final String content;
  const _ExportSheet({required this.content});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('导出 JSON（可复制/分享保存）', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: ctrl,
                    child: SelectableText(content),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: content));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done),
                        label: const Text('完成'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
