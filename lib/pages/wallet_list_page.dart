import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/wallet_entry.dart';
import 'wallet_create_page.dart';
import 'wallet_detail_page.dart';

class WalletListPage extends StatefulWidget {
  const WalletListPage({super.key});
  @override
  State<WalletListPage> createState() => _WalletListPageState();
}

class _WalletListPageState extends State<WalletListPage> {
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('wallets'); // 泛型 Box，兼容 Map/对象
    return Scaffold(
      appBar: AppBar(title: const Text('我的钱包')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalletCreatePage()),
        ),
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletCreatePage()),
                    ),
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
              return ListTile(
                leading: Icon(e.isDefault ? Icons.star : Icons.account_balance_wallet),
                title: Text(e.addressBase58, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('创建于 ${e.createdAt}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WalletDetailPage(walletId: e.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
