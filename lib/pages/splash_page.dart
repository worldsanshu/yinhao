import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/secure_store.dart';
import '../services/app_version_service.dart';

import 'pin_lock_page.dart';
import 'onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Hive.initFlutter();
    await Hive.openBox('wallets');
    final settingsBox = await Hive.openBox('settings');
    
    // 检查是否有通过通知点击设置的钱包ID
    final notificationWalletId = settingsBox.get('last_notification_wallet_id') as String?;
    if (notificationWalletId != null) {
      print('检测到通知点击，钱包ID: $notificationWalletId');
      // 先清除这个标记，避免重复导航
      await settingsBox.delete('last_notification_wallet_id');
      // 存储到secure_store中，以便身份验证后使用
      await SecureStore.saveNotificationWalletId(notificationWalletId);
    }

    final (pinHash, _) = await SecureStore.readPinHashAndSalt();
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    // 在导航到主页面前，检查App Store更新
    // 这里使用Future.microtask确保导航操作先完成
    // 然后在主页面加载完成后再显示更新提示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppVersionService.showUpdateDialog(context);
      }
    });
    
    if (pinHash == null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingPage()));
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinLockPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
