import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/wallet_entry.dart';

class WalletImportPage extends StatefulWidget {
  const WalletImportPage({super.key});

  @override
  State<WalletImportPage> createState() => _WalletImportPageState();
}

class _WalletImportPageState extends State<WalletImportPage> {
  final _encCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入加密密文')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('粘贴之前导出的加密JSON：'),
            const SizedBox(height: 8),
            TextField(controller: _encCtrl, maxLines: 10, decoration: const InputDecoration(hintText: '{ ... }')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _import, child: const Text('导入')),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    try {
      final entry = WalletEntry.importJson(_encCtrl.text);
      final box =  Hive.box('wallets');
      await box.put(entry.id, entry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入成功: ${entry.addressBase58}')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }
}
