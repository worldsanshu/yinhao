import 'package:flutter/material.dart';
import 'app.dart'; // 你的 UsdtVaultApp
import 'security/app_lock_gate.dart';
import 'pages/splash_page.dart'; // 你现有的启动页

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UsdtVaultApp());
}
