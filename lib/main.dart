import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart'; // 你的 UsdtVaultApp
import 'security/app_lock_gate.dart';
import 'pages/splash_page.dart'; // 你现有的启动页
import 'models/address_book.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive数据库
  await Hive.initFlutter();
  
  // 注册AddressBookEntry适配器
  Hive.registerAdapter(AddressBookEntryAdapter());
  
  // 打开必要的Hive box
  await Hive.openBox('wallets');
  await Hive.openBox('settings');
  
  runApp(const UsdtVaultApp());
}
