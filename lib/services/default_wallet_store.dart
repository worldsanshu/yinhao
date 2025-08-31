import 'package:shared_preferences/shared_preferences.dart';

class DefaultWalletStore {
  static const _kDefaultId = 'default_wallet_id_v1';

  static Future<String?> get() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kDefaultId);
  }

  static Future<void> set(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDefaultId, id);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kDefaultId);
  }
}
