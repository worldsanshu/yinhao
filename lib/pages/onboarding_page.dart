import 'package:flutter/material.dart';
import 'wallet_create_page.dart';
import 'wallet_import_page.dart';
import 'wallet_list_page.dart';
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('USDT Vault')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('欢迎使用', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('本地加密 · 三密码解锁 · 无需服务端 · 支持Face ID'),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('钱包列表'),
              onPressed: () =>Navigator.pushReplacementNamed(context, '/wallets'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('创建新钱包'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletCreatePage())),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('导入加密密文'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletImportPage())),
            ),
          ],
        ),
      ),
    );
  }
}
