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

        // 关键：始终根据 AppLockController 的 unlocked 切换，
        // 即使在首次(onboarded=false)也能在设置成功后直接进入 child。
        return AnimatedBuilder(
          animation: AppLockController.instance,
          builder: (_, __) {
            final unlocked = AppLockController.instance.unlocked;
            if (!onboarded) {
              // 首启：未设置 -> Setup；一旦 unlocked=true（设置完成），直接进入 child。
              return unlocked ? child : const AppLockSetupPage();
            }
            if (!hasPin) {
              // 已 on-board 但无 Pin（异常），进入 Setup
              return const AppLockSetupPage();
            }
            // 正常：根据 unlocked 切换
            return unlocked ? child : const AppLockUnlockPage();
          },
        );
      },
    );
  }
}