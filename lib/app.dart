import 'package:flutter/material.dart';
import 'theme.dart';
import 'security/app_lock_gate.dart';
import 'pages/splash_page.dart'; // 或你的 Home

class UsdtVaultApp extends StatelessWidget {
  const UsdtVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USDT Vault',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      // home: const SplashPage(),
       home: const AppLockGate(child: SplashPage()),
    );
  }
}
