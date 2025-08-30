import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'app.dart'; // 你的 UsdtVaultApp
import 'security/app_lock_gate.dart';

class UsdtVaultApp extends StatelessWidget {
  const UsdtVaultApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USDT Vault',
       theme: darkTheme,

        home: const AppLockGate(child: SplashPage()),
      // 或者 routes 用 onGenerateRoute，但保证根部是 AppLockGate
    );
  }
}