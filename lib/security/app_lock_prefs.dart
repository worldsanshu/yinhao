import 'package:shared_preferences/shared_preferences.dart';

class AppLockPrefs {
  static const _kOnboarded = 'app_lock_onboarded_v1';

  static Future<bool> isOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOnboarded) ?? false;
  }

  static Future<void> setOnboarded(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboarded, v);
  }
}
