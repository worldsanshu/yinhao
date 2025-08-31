import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/wallet_entry.dart';
import '../services/usdt_service.dart';
import '../services/tron_client.dart';
import 'settings_page.dart';
import 'wallet_detail_page.dart';
import 'wallet_create_page.dart';
import 'wallet_import_page.dart';
import 'wallet_list_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<WalletEntry> _box;
  late Box _settings;
  final _client = TronClient(endpoint: 'https://api.trongrid.io');
  String? _defaultId;
  String _dTrx = '--', _dUsdt = '--';
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _box = Hive.box('wallets');
    _settings = Hive.box('settings');
    _defaultId = _settings.get('default_wallet_id') as String?;
    _loadDefaultSummary();
  }

  Future<void> _loadDefaultSummary() async {
    if (_defaultId == null) return;
    final e = _box.get(_defaultId!);
    if (e == null) return;
    final s = UsdtService(_client);
    final (trx, usdt) = await s.balances(e.addressBase58);
    final txs = await _client.recentUsdtTransfers(e.addressBase58, limit: 5);
    if (!mounted) return;
    setState(() { _dTrx = trx; _dUsdt = usdt; _recent = txs; });
  }

  void _setDefault(String id) {
    _settings.put('default_wallet_id', id);
    setState(() { _defaultId = id; });
    _loadDefaultSummary();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已设为默认钱包')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USDT Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(),
        label: const Text('添加'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_defaultId != null) _defaultCard(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _box.listenable(),
              builder: (_, Box<WalletEntry> box, __) {
                final keys = box.keys.cast<String>().toList().reversed.toList();
                if (keys.isEmpty) {
                  return const Center(child: Text('暂无钱包，点击右下角添加或导入。'));
                }
                return ListView.separated(
                  itemCount: keys.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.2),
                  itemBuilder: (_, i) {
                    final id = keys[i];
                    final entry = box.get(id)!;
                    final isDefault = id == _defaultId;
                    return ListTile(
                      leading: Icon(isDefault ? Icons.star : Icons.account_balance_wallet_outlined, color: isDefault ? Colors.amber : null),
                      title: Text(entry.addressBase58, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('创建时间：${entry.createdAt.toLocal()}'),
                      trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => _walletActions(entry)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletDetailPage(walletId: entry.id))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCard() {
    final e = _box.get(_defaultId!);
    if (e == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(child: Text('默认钱包：${e.addressBase58}', overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDefaultSummary),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _metric('TRX', _dTrx)),
              const SizedBox(width: 12),
              Expanded(child: _metric('USDT', _dUsdt)),
            ]),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('最近交易（TRC20）：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final t in _recent)
                Text('${t['type'] ?? ''} ${t['value'] ?? ''} -> ${t['to'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Column(children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 18)),
    ]);
  }

  void _walletActions(WalletEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.copy), title: const Text('复制地址'), onTap: () {
              Clipboard.setData(ClipboardData(text: entry.addressBase58));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制地址')));
            }),
           ListTile(
  leading: const Icon(Icons.qr_code),
  title: const Text('查看二维码'),
  onTap: () async {
    Navigator.pop(context); // 先收起底部面板
    await Future.delayed(const Duration(milliseconds: 60));
    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'address-qr',
      barrierColor: Colors.black87,
      pageBuilder: (ctx, a1, a2) {
        final size = MediaQuery.of(ctx).size;
        final side = (size.shortestSide * 0.82).clamp(240.0, 420.0);
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: side + 32,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('地址二维码', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: side, height: side,
                      child: Center(child: FittedBox(child: QrImageView(data: entry.addressBase58, size: side))),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(entry.addressBase58, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
),
 ListTile(leading: const Icon(Icons.ios_share), title: const Text('快捷导出备份(JSON)'), onTap: () async {
              await Share.share(entry.exportJson());
              if (mounted) Navigator.pop(context);
            }),
            ListTile(leading: const Icon(Icons.star), title: const Text('设为默认钱包'), onTap: () {
              Navigator.pop(context);
              _setDefault(entry.id);
            }),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
               ListTile(
              leading: const Icon(Icons.key),
              title: const Text('U钱包列表'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletListPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('创建新钱包'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletCreatePage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入加密密文'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletImportPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
