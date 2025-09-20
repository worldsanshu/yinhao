import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import '../services/secure_store.dart';
import '../pages/auth_page.dart';
import 'app_lock_service.dart';
import 'app_lock_pages.dart';
import 'app_lock_controller.dart';
import 'app_lock_prefs.dart';

class AppLockGate extends StatefulWidget {
  final Widget child; // 真正的根页面（例如 Splash/Home）
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  Future<Map<String, dynamic>> _decide() async {
    final onboarded = await AppLockPrefs.isOnboarded();
    if (!onboarded) {
      await AppLockService.deleteAllLockKeys(); // 首启清理旧 Keychain
    }
    final has = await AppLockService.hasPin();
    
    // 检查是否有通过通知点击设置的钱包ID
    final notificationWalletId = await SecureStore.readNotificationWalletId();
    
    return {
      'onboarded': onboarded, 
      'hasPin': has,
      'notificationWalletId': notificationWalletId
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _decide(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!;
        final onboarded = data['onboarded'] ?? false;
        final hasPin = data['hasPin'] ?? false;
        final notificationWalletId = data['notificationWalletId'] as String?;

        return AnimatedBuilder(
          animation: AppLockController.instance,
          builder: (_, __) {
            final unlocked = AppLockController.instance.unlocked;
            
            // 如果有通知钱包ID，优先处理
            if (notificationWalletId != null) {
              return AuthPage(walletId: notificationWalletId);
            }
            
            if (!onboarded) {
              return unlocked ? widget.child : const AppLockSetupPage();
            }
            if (!hasPin) {
              return const AppLockSetupPage();
            }
            return unlocked ? widget.child : const AppLockUnlockPage();
          },
        );
      },
    );
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查是否有通过通知点击设置的钱包ID
    _checkNotificationNavigation();
  }
  
  Future<void> _checkNotificationNavigation() async {
    try {
      // 检查是否有通过通知点击设置的钱包ID
      final settings = await Hive.openBox('settings');
      final walletId = settings.get('last_notification_wallet_id') as String?;
      
      if (walletId != null && context.mounted) {
        print('检测到通知点击，准备导航到钱包ID: $walletId');
        // 在设置中清除这个标记，避免重复导航
        await settings.delete('last_notification_wallet_id');
        // 存储到secure_store中，以便身份验证后使用
        await SecureStore.saveNotificationWalletId(walletId);
        
        // 触发重建以导航到AuthPage
        setState(() {});
      }
    } catch (e) {
      print('检查通知导航失败: $e');
    }
  }
}
