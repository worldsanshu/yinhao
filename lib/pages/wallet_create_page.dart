import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/crypto_service.dart';
import '../models/wallet_entry.dart';
import 'dart:async';
import '../services/email_share.dart';
import 'package:flutter/material.dart';

class WalletCreatePage extends StatefulWidget {
  const WalletCreatePage({super.key});
  @override
  State<WalletCreatePage> createState() => _WalletCreatePageState();
}

class _WalletCreatePageState extends State<WalletCreatePage> {
  final _name = TextEditingController(); // 👈 新增
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
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '钱包名称（可选）',
                hintText: '例如：常用账户/冷钱包',
              ),
            ),
            const SizedBox(height: 16),
            const Text('请设置三个独立的密码（务必妥善保存）', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            _PwField(controller: _p1, label: '密码1'),
            const SizedBox(height: 8),
            TextField(
                controller: _h1,
                decoration: const InputDecoration(labelText: '密码1提示(可选)')),
            const SizedBox(height: 20),
            _PwField(controller: _p2, label: '密码2'),
            const SizedBox(height: 8),
            TextField(
                controller: _h2,
                decoration: const InputDecoration(labelText: '密码2提示(可选)')),
            const SizedBox(height: 20),
            _PwField(controller: _p3, label: '密码3'),
            const SizedBox(height: 8),
            TextField(
                controller: _h3,
                decoration: const InputDecoration(labelText: '密码3提示(可选)')),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('三个密码均不能为空')));
      return;
    }

    setState(() => _busy = true);
    try {
      final pk = CryptoService.generatePrivateKey32();
      final (addrB58, addrHex) = CryptoService.deriveTronAddress(pk);

      const iterations = 310000;
      final enc = await CryptoService.encryptPrivateKeyWithThreePasswords(
        privateKey32: pk,
        pass1: p1,
        pass2: p2,
        pass3: p3,
        iterations: iterations,
      );

      /// 前2位 + *...* + 最后1位；长度特殊场景做了保护：
      /// len==1 → 原样返回；len==2 → 显示首1 + *；len==3 → 显示前2 + 末1
      String _maskKeep2Head1Tail(String? s) {
        final t = (s ?? '').trim();
        if (t.isEmpty) return '';
        if (t.length == 1) return t;
        if (t.length == 2) return t[0] + '*';
        if (t.length == 3) return t.substring(0, 2) + t.substring(2); // 前2 + 后1

        final start = t.substring(0, 2);
        final end = t.substring(t.length - 1);
        final middle = List.filled(t.length - 3, '*').join();
        return '$start$middle$end';
      }

      final hint1 =
          _h1.text.trim().isEmpty ? _maskKeep2Head1Tail(p1) : _h1.text.trim();
      final hint2 =
          _h2.text.trim().isEmpty ? _maskKeep2Head1Tail(p2) : _h2.text.trim();
      final hint3 =
          _h3.text.trim().isEmpty ? _maskKeep2Head1Tail(p3) : _h3.text.trim();

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
        hint1: hint1,
        hint2: hint2,
        hint3: hint3,
        createdAt: DateTime.now(),
        version: 1,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );

      final box = Hive.box('wallets');
      await box.put(entry.id, entry.toJson());
// 邮件备份：如果设置中配置了收件邮箱，则发送钱包导出信息作为附件
      try {
        final settingsBox = Hive.isBoxOpen('settings')
            ? Hive.box('settings')
            : await Hive.openBox('settings');
        final String? toEmail =
            (settingsBox.get('backup_email') as String?)?.trim();
        if (toEmail != null && toEmail.isNotEmpty) {
          final export = Map<String, dynamic>.from(entry.toJson());
          export['github'] = 'https://github.com/worldsanshu/yinhao.git';
          export['note'] = '具体操作使用信息前往github查看操作';
          // final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(export));
          final bytes = utf8.encode(jsonEncode(export));

          await EmailShare.sendWalletBackup(
            to: toEmail,
            subject: '个人重要数字财产备份邮件',
            textBody:
                '本邮件是USDT钱包创建时自动发送，这个邮件内容附件是与创建人有关的数字资产备份，备用以便不时之需，具体使用方法是https://github.com/worldsanshu/yinhao.git',
            filename: 'wallet_backup_${entry.id}.json',
            data: bytes,
          );
        }
      } catch (e) {
        // 邮件发送失败不影响创建流程
        debugPrint('Email backup skipped or failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('钱包已创建并保存')));

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PwField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _PwField({required this.controller, required this.label});
  @override
  State<_PwField> createState() => _PwFieldState();
}

class _PwFieldState extends State<_PwField> {
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
