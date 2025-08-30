import 'dart:convert';
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
  bool _biometricAvailable = false;
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      _biometricAvailable = await _auth.canCheckBiometrics;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _tryBiometric() async {
    if (!_biometricAvailable) return;
    final ok = await _auth.authenticate(
      localizedReason: '使用 Face ID/指纹解锁',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text;
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入至少4位的解锁密码')));
      return;
    }
    final (hashStored, saltB64) = await SecureStore.readPinHashAndSalt();
    if (hashStored == null || saltB64 == null) {
      final salt = _randomBytes(16);
      final hash = await _pbkdf2Hash(pin, salt);
      await SecureStore.writePinHash(hash, base64Encode(salt));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('解锁密码已设置')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingPage()));
      return;
    }
    final salt = base64Decode(saltB64);
    final hash = await _pbkdf2Hash(pin, salt);
    if (hash == hashStored && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码错误')));
    }
  }

  Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => rnd.nextInt(256)));
  }

  Future<String> _pbkdf2Hash(String pin, Uint8List salt) async {
    final algo = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 200000, bits: 256);
    final key = await algo.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    final b = await key.extractBytes();
    return base64Encode(b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('输入解锁密码', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '解锁密码'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(onPressed: _submit, child: const Text('解锁')),
                ),
                const SizedBox(width: 12),
                if (_biometricAvailable)
                  IconButton(onPressed: _tryBiometric, icon: const Icon(Icons.fingerprint, size: 32)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
