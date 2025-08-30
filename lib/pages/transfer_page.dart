import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/wallet_entry.dart';
import '../services/tron_client.dart';
import '../services/crypto_service.dart';
import '../services/usdt_service.dart';

enum AssetType { usdt, trx }

class TransferPage extends StatefulWidget {
  final String walletId;
  final AssetType? initialAsset;
  const TransferPage({super.key, required this.walletId, this.initialAsset});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _to = TextEditingController();
  final _amount = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();

  bool _busy = false;
  final _client = TronClient(endpoint: 'https://api.trongrid.io');
  WalletEntry? _entry;

  @override
  void initState() {
    super.initState();
    _entry = Hive.box<WalletEntry>('wallets').get(widget.walletId);
  }

  @override
  Widget build(BuildContext context) {
    final hint1 = _entry?.hint1;
    final hint2 = _entry?.hint2;
    final hint3 = _entry?.hint3;

    return Scaffold(
      appBar: AppBar(title: const Text('发送 USDT / TRX')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _to,
              decoration: const InputDecoration(
                labelText: '收款地址（TRON 地址，T 开头或 0x41...）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '金额'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('转账 USDT'),
                    onPressed: _busy ? null : () => _send(AssetType.usdt),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on),
                    label: const Text('转账 TRX'),
                    onPressed: _busy ? null : () => _send(AssetType.trx),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('输入三个密码以解密私钥：'),
            const SizedBox(height: 8),
            TextField(
              controller: _p1,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码1',
                helperText:
                    (hint1 != null && hint1.isNotEmpty) ? '提示：$hint1' : null,
                suffixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _p2,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码2',
                helperText:
                    (hint2 != null && hint2.isNotEmpty) ? '提示：$hint2' : null,
                suffixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _p3,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码3',
                helperText:
                    (hint3 != null && hint3.isNotEmpty) ? '提示：$hint3' : null,
                suffixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(AssetType asset) async {
    final toInput = _to.text.trim();
    final amountText = _amount.text.trim();
    if (toInput.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入收款地址和金额')),
      );
      return;
    }
    final amount = (double.tryParse(amountText) ?? 0);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金额不正确')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final e = _entry;
      if (e == null) throw Exception('找不到钱包');

      final pk = await CryptoService.decryptPrivateKeyWithThreePasswords(
        pass1: _p1.text,
        pass2: _p2.text,
        pass3: _p3.text,
        ciphertextB64: e.encPrivateKeyB64,
        nonceB64: e.nonceB64,
        salt1B64: e.salt1B64,
        salt2B64: e.salt2B64,
        salt3B64: e.salt3B64,
        masterSaltB64: e.masterSaltB64,
        iterations: e.pbkdf2Iterations,
      );

      final to = _client.normalizeToBase58(toInput);

      Map<String, dynamic> tx;
      if (asset == AssetType.usdt) {
        tx = await _client.buildTrc20Transfer(
          fromBase58: e.addressBase58,
          toBase58: to,
          amount: BigInt.from((amount * 1e6).round()),
          contractBase58: UsdtService.defaultUsdtContract,
        );
      } else {
        tx = await _client.buildTrxTransfer(
          fromBase58: e.addressBase58,
          toBase58: to,
          amountSun: BigInt.from((amount * 1e6).round()),
        );
      }

      final signed = await _client.signTransaction(tx, pk);
      final txid = await _client.broadcastTransaction(signed);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已广播: $txid')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}