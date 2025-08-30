import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _pinHashKey = 'app_pin_hash_v1';
  static const _pinSaltKey = 'app_pin_salt_v1';

  static Future<void> writePinHash(String hash, String saltB64) async {
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinSaltKey, value: saltB64);
  }

  static Future<(String?, String?)> readPinHashAndSalt() async {
    final h = await _storage.read(key: _pinHashKey);
    final s = await _storage.read(key: _pinSaltKey);
    return (h, s);
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
  }
}
