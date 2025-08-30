import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/crypto_service.dart';
import '../models/wallet_entry.dart';

class WalletCreatePage extends StatefulWidget {
  const WalletCreatePage({super.key});

  @override
  State<WalletCreatePage> createState() => _WalletCreatePageState();
}

class _WalletCreatePageState extends State<WalletCreatePage> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();
  final _h1 = TextEditingController();
  final _h2 = TextEditingController();
  final _h3 = TextEditingController();

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建新钱包')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('请设置三个独立的密码（务必妥善保存）', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            PwField(controller: _p1, label: '密码1'),
            const SizedBox(height: 8),
            TextField(controller: _h1, decoration: const InputDecoration(labelText: '密码1提示(可选)')),

            const SizedBox(height: 20),
            PwField(controller: _p2, label: '密码2'),
            const SizedBox(height: 8),
            TextField(controller: _h2, decoration: const InputDecoration(labelText: '密码2提示(可选)')),

            const SizedBox(height: 20),
            PwField(controller: _p3, label: '密码3'),
            const SizedBox(height: 8),
            TextField(controller: _h3, decoration: const InputDecoration(labelText: '密码3提示(可选)')),

            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
              label: const Text('创建并保存'),
              onPressed: _busy ? null : _create,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final p1 = _p1.text, p2 = _p2.text, p3 = _p3.text;
    if (p1.isEmpty || p2.isEmpty || p3.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('三个密码均不能为空')));
      return;
    }

    setState(() => _busy = true);
    try {
      final pk = CryptoService.generatePrivateKey32();
      final (addrB58, addrHex) = CryptoService.deriveTronAddress(pk);

      const iterations = 310000;
      final enc = await CryptoService.encryptPrivateKeyWithThreePasswords(
        privateKey32: pk, pass1: p1, pass2: p2, pass3: p3, iterations: iterations,
      );

      final entry = WalletEntry(
        id: const Uuid().v4(),
        addressBase58: addrB58,
        addressHex: addrHex,
        encPrivateKeyB64: enc['ciphertextB64']!,
        nonceB64: enc['nonceB64']!,
        salt1B64: enc['salt1B64']!,
        salt2B64: enc['salt2B64']!,
        salt3B64: enc['salt3B64']!,
        masterSaltB64: enc['masterSaltB64']!,
        pbkdf2Iterations: iterations,
        hint1: _h1.text, hint2: _h2.text, hint3: _h3.text,
        createdAt: DateTime.now(), version: 1,
      );

      // 兼容：以 Map 存储（不要求 TypeAdapter）；旧数据若是对象也能被列表读取
      final box = Hive.box('wallets');
      await box.put(entry.id, entry.toJson());
       print( mounted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('钱包已创建并保存')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        print( Text('创建失败: $e'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class PwField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const PwField({super.key, required this.controller, required this.label});
  @override
  State<PwField> createState() => _PwFieldState();
}

class _PwFieldState extends State<PwField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
