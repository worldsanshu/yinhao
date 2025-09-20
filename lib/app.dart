import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme.dart';
import 'pages/splash_page.dart';
import 'security/app_lock_gate.dart';
import 'pages/wallet_detail_page.dart';
import 'pages/wallet_create_page.dart';
import 'pages/wallet_import_page.dart';
import 'pages/wallet_list_page.dart';
import 'pages/auth_page.dart';

class UsdtVaultApp extends StatelessWidget {
  const UsdtVaultApp({super.key});
  @override
  Widget build(BuildContext context) {
    // 检查是否有需要导航的钱包ID
    checkForNotificationNavigation();
    
    return MaterialApp(
      title: 'USDT Vault',
      theme: darkTheme,
      routes: {
        '/wallets': (_) => const WalletListPage(),
        '/create': (_) => const WalletCreatePage(),
        '/wallet_detail': (context) {
          final walletId = ModalRoute.of(context)?.settings.arguments as String?;
          if (walletId == null) {
            // 如果没有提供walletId，导航回钱包列表页
            return WalletListPage();
          }
          return WalletDetailPage(walletId: walletId);
        },
        '/auth': (context) {
          final walletId = ModalRoute.of(context)?.settings.arguments as String?;
          return AuthPage(walletId: walletId);
        },
      },
      home: const AppLockGate(child: SplashPage()),
      // 或者 routes 用 onGenerateRoute，但保证根部是 AppLockGate
    );
  }
  
  Future<void> checkForNotificationNavigation() async {
    try {
      // 检查是否有通过通知点击设置的钱包ID
      final settings = await Hive.openBox('settings');
      final walletId = settings.get('last_notification_wallet_id') as String?;
      
      if (walletId != null) {
        print('检测到通知点击，准备导航到钱包ID: $walletId');
        // 在设置中清除这个标记，避免重复导航
        await settings.delete('last_notification_wallet_id');
        
        // 检查应用是否已经启动
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // 检查是否已经有导航器上下文
          final navigatorKey = GlobalKey<NavigatorState>();
          
          // 如果应用已经启动但导航器上下文不可用，我们可以存储这个ID
          // 并让SplashPage或AuthPage在合适的时候处理它
        });
      }
    } catch (e) {
      print('检查通知导航失败: $e');
    }
  }
}
