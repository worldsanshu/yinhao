
// lib/pages/pin_lock_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/secure_store.dart';
import 'home_page.dart';
import 'onboarding_page.dart';

class PinLockPage extends StatefulWidget {
  const PinLockPage({super.key});

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends State<PinLockPage> {
  final _pinCtrl = TextEditingController();
  final _auth = LocalAuthentication();

  bool _biometricAvailable = false;
  List<BiometricType> _biometricTypes = const [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final types = supported ? await _auth.getAvailableBiometrics() : <BiometricType>[];
      if (!mounted) return;
      setState(() {
        _biometricTypes = types;
        _biometricAvailable = supported && canCheck && types.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _biometricAvailable = false;
        _biometricTypes = const [];
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) return;
    try {
      final ok = await _auth.authenticate(
        localizedReason: Platform.isIOS
            ? '使用 Face ID / Touch ID 解锁'
            : (_biometricTypes.contains(BiometricType.fingerprint)
                  ? '使用指纹解锁'
                  : '使用面部解锁'),
        options: const AuthenticationOptions(
          biometricOnly: true,        // 仅生物识别。如果想允许系统口令回退，把这行改为 false
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生物识别不可用：$e')),
      );
    }
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入至少4位的解锁密码')),
      );
      return;
    }

    final (hashStored, saltB64) = await SecureStore.readPinHashAndSalt();
    if (hashStored == null || saltB64 == null) {
      // 首次设置 PIN：生成盐 + 计算哈希并保存
      final salt = _randomBytes(16);
      final hash = await _pbkdf2Hash(pin, salt);
      await SecureStore.writePinHash(hash, base64Encode(salt));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('解锁密码已设置')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
      return;
    }

    // 有已保存的 PIN：校验
    final salt = base64Decode(saltB64);
    final hash = await _pbkdf2Hash(pin, salt);
    if (!mounted) return;
    if (hash == hashStored) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码错误')),
      );
    }
  }

  // --- PBKDF2(SHA-256) ---
  Future<String> _pbkdf2Hash(String pin, Uint8List salt) async {
    // 采用 PBKDF2-HMAC(SHA256) 派生 32 字节；迭代次数可按需调整
    final algo = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 120000,
      bits: 256,
    );
    final key = await algo.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    // 存储十六进制字符串，和你现有实现尽量保持一致
    return _toHex(bytes);
  }

  Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
  }

  String _toHex(List<int> bytes) {
    const hex = '0123456789abcdef';
    final out = StringBuffer();
    for (final b in bytes) {
      out.write(hex[(b >> 4) & 0x0f]);
      out.write(hex[b & 0x0f]);
    }
    return out.toString();
  }

  @override
  void dispose() {
    try { _auth.stopAuthentication(); } catch (_) {}
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('解锁')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('请输入解锁密码', style: text.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 32,
              decoration: const InputDecoration(
                hintText: '至少 4 位数字/字母',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('解锁'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_biometricAvailable)
                  IconButton(
                    onPressed: _tryBiometric,
                    icon: Icon(
                      _biometricTypes.contains(BiometricType.face) && !Platform.isIOS
                        ? Icons.face
                        : Icons.fingerprint,
                      size: 32,
                    ),
                    tooltip: Platform.isIOS ? 'Face ID / Touch ID' : '生物识别',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _biometricAvailable
                  ? (Platform.isIOS
                      ? '支持：Face ID / Touch ID'
                      : '支持：' + (_biometricTypes.contains(BiometricType.fingerprint) ? '指纹' : '人脸'))
                  : '此设备不支持生物识别或未录入',
              style: text.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
