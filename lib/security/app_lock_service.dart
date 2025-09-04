import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  static const _kHash = 'app_lock_hash';
  static const _kSalt = 'app_lock_salt';
  static const _kBio = 'app_lock_bio_enabled';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static final _auth = LocalAuthentication();

  static Future<bool> hasPin() async {
    final h = await _storage.read(key: _kHash);
    final s = await _storage.read(key: _kSalt);
    return (h != null && s != null && h.isNotEmpty && s.isNotEmpty);
  }

  static String _hash(String pin, String saltB64) {
    final data = utf8.encode('$pin:$saltB64');
    return crypto.sha256.convert(data).toString();
  }

  static String _randomSaltB64() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// 仅数字 PIN；统一 trim，长度 4–8
  static Future<void> setPin(String pin,
      {bool enableBiometrics = false}) async {
    final p = pin.trim();
    if (p.isEmpty || p.length < 4 || p.length > 8 || int.tryParse(p) == null) {
      throw PlatformException(code: 'INVALID_PIN', message: 'PIN 必须为 4–8 位数字');
    }
    final salt = _randomSaltB64();
    final hash = _hash(p, salt);
    await _storage.write(key: _kHash, value: hash);
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kBio, value: enableBiometrics ? '1' : '0');
  }

  static Future<bool> verifyPin(String pin) async {
    final p = pin.trim();
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) return false;
    return _hash(p, salt) == hash;
  }

  static Future<bool> biometricsEnabled() async =>
      (await _storage.read(key: _kBio)) == '1';

  static Future<void> setBiometricsEnabled(bool on) async =>
      _storage.write(key: _kBio, value: on ? '1' : '0');

  static Future<bool> canUseBiometrics() async {
    final supported = await _auth.isDeviceSupported();
    final can = await _auth.canCheckBiometrics;
    return supported && can;
  }

  static Future<bool> authWithBiometrics() async {
    final ok = await canUseBiometrics();
    if (!ok) return false;
    return _auth.authenticate(
      localizedReason: '使用 Face ID / 指纹解锁',
      options: const AuthenticationOptions(biometricOnly: true),
    );
  }

  /// 清除 AppLock 相关 Keychain（不影响钱包 Hive 数据）
  static Future<void> deleteAllLockKeys() async {
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kSalt);
    await _storage.delete(key: _kBio);
  }

  /// 调试：读取当前状态
  static Future<Map<String, String?>> debugSnapshot() async => {
        'hash': await _storage.read(key: _kHash),
        'salt': await _storage.read(key: _kSalt),
        'bio': await _storage.read(key: _kBio),
      };
}
