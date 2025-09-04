import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'app.dart'; // 你的 UsdtVaultApp
import 'security/app_lock_gate.dart';
import 'pages/wallet_detail_page.dart';
import 'pages/wallet_create_page.dart';
import 'pages/wallet_import_page.dart';
import 'pages/wallet_list_page.dart';

class UsdtVaultApp extends StatelessWidget {
  const UsdtVaultApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USDT Vault',
      theme: darkTheme,
      routes: {
        '/wallets': (_) => const WalletListPage(),
        '/create': (_) => const WalletCreatePage(),
      },
      home: const AppLockGate(child: SplashPage()),
      // 或者 routes 用 onGenerateRoute，但保证根部是 AppLockGate
    );
  }
}
