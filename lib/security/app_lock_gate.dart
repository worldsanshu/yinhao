import 'package:flutter/material.dart';
import 'app_lock_service.dart';
import 'app_lock_pages.dart';
import 'app_lock_controller.dart';
import 'app_lock_prefs.dart';

class AppLockGate extends StatelessWidget {
  final Widget child; // 真正的根页面（例如 Splash/Home）
  const AppLockGate({super.key, required this.child});

  Future<Map<String, bool>> _decide() async {
    final onboarded = await AppLockPrefs.isOnboarded();
    if (!onboarded) {
      await AppLockService.deleteAllLockKeys(); // 首启清理旧 Keychain
    }
    final has = await AppLockService.hasPin();
    return {'onboarded': onboarded, 'hasPin': has};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: _decide(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!;
        final onboarded = data['onboarded'] ?? false;
        final hasPin = data['hasPin'] ?? false;

        if (!onboarded) return const AppLockSetupPage(); // 首启必定设置
        if (!hasPin)   return const AppLockSetupPage();  // 异常兜底

        return AnimatedBuilder(
          animation: AppLockController.instance,
          builder: (_, __) =>
              AppLockController.instance.unlocked ? child : const AppLockUnlockPage(),
        );
      },
    );
  }
}
