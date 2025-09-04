// lib/pages/energy_purchase_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wallet_entry.dart';
import '../services/crypto_service.dart'; // TransferService + decrypt
import '../widgets/qr_scan_sheet.dart';

/// 购买能量 = 给指定地址转 TRX
/// 配置项（Hive 'settings' 中）：
///   - energy_purchase_to   购买能量固定收款地址（优先）
///   - trx_default_to       默认 TRX 转账地址（次优，作为兜底）
///   - energy_last_to       页面最近一次输入（历史记忆，最低优先级）
class EnergyPurchasePage extends StatefulWidget {
  final String walletId;
  const EnergyPurchasePage({super.key, required this.walletId});

  @override
  State<EnergyPurchasePage> createState() => _EnergyPurchasePageState();
}

class _EnergyPurchasePageState extends State<EnergyPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _toCtl = TextEditingController();
  final _totrxnum = TextEditingController();
  final _amtCtl = TextEditingController();
  final _p1Ctl = TextEditingController();
  final _p2Ctl = TextEditingController();
  final _p3Ctl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _addrLocked = false; // 如果命中配置，则默认锁定收款地址
  WalletEntry? _entry;

  @override
  void initState() {
    super.initState();
    _entry = _loadEntry();
    _prefillToFromSettings();
  }

  WalletEntry? _loadEntry() {
    final box = Hive.box('wallets');
    final raw = box.get(widget.walletId);
    return WalletEntry.tryFrom(raw);
  }

  void _prefillToFromSettings() {
    final settings = Hive.box('settings');
    // 优先级：energy_purchase_to > trx_default_to > energy_target_address(兼容旧键) > energy_last_to
    final preset = (settings.get('energy_purchase_to') as String?) ??
        (settings.get('trx_default_to') as String?) ??
        (settings.get('energy_target_address') as String?) ??
        (settings.get('energy_last_to') as String?);
    if (preset != null && preset.isNotEmpty) {
      _toCtl.text = preset;
      // 如果命中“固定地址”键，则默认锁住输入框
      _addrLocked = (settings.get('energy_purchase_to') as String?) == preset ||
          (settings.get('trx_default_to') as String?) == preset;
    }

    // 优先级：energy_purchase_to > trx_default_to > energy_target_address(兼容旧键) > energy_last_to
    final trxnum =
        (settings.get('energy_purchase_to_number') as String?) ?? '10';
    if (trxnum != null && trxnum.isNotEmpty) {
      _amtCtl.text = trxnum;
      // 如果命中“固定地址”键，则默认锁住输入框
      _addrLocked =
          (settings.get('energy_purchase_to_number') as String?) == trxnum ||
              (settings.get('energy_purchase_to_number') as String?) == trxnum;
    }
  }

  @override
  void dispose() {
    _toCtl.dispose();
    _amtCtl.dispose();
    _totrxnum.dispose();
    _p1Ctl.dispose();
    _p2Ctl.dispose();
    _p3Ctl.dispose();
    super.dispose();
  }

  String? _vAddress(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '请输入收款地址（Base58）';
    if (!s.startsWith('T')) return '地址格式看起来不像 Tron Base58（一般以 T 开头）';
    if (s.length < 26 || s.length > 48) return '地址长度异常';
    return null;
  }

  String? _vAmount(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '请输入 TRX 数量';
    final ok = RegExp(r'^\d+(?:\.\d{1,6})?$').hasMatch(s);
    if (!ok) return '请输入数字，最多 6 位小数';
    if (double.tryParse(s) == 0.0) return '数量需大于 0';
    return null;
  }

  String? _vPass(String? v) => (v == null || v.isEmpty) ? '必填' : null;

  BigInt _trxToSun(String s) {
    s = s.trim();
    if (s.contains('.')) {
      final parts = s.split('.');
      final intPart = parts[0];
      var frac = parts[1];
      if (frac.length > 6) frac = frac.substring(0, 6);
      while (frac.length < 6) frac += '0';
      return BigInt.parse(intPart) * BigInt.from(1000000) + BigInt.parse(frac);
    } else {
      return BigInt.parse(s) * BigInt.from(1000000);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    final entry = _entry;
    if (entry == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('钱包不存在或已被删除')));
      return;
    }

    setState(() => _loading = true);
    try {
      // 口令先验校验：失败会抛异常或返回 false
      final ok = await CryptoService.verifyPasswords(
          entry, _p1Ctl.text, _p2Ctl.text, _p3Ctl.text);
      if (!ok) throw Exception('口令错误');

      final pk = await CryptoService.decryptPrivateKeyWithThreePasswords(
          entry, _p1Ctl.text, _p2Ctl.text, _p3Ctl.text);

      final ep = (Hive.box('settings').get('tron_endpoint') as String?) ??
          'https://api.trongrid.io';
      final apiKey = Hive.box('settings').get('trongrid_api_key') as String?;
      final svc = TransferService(nodeUrl: ep, tronProApiKey: apiKey);

      final to = _toCtl.text.trim();
      final sun = _trxToSun(_amtCtl.text.trim());

      final txid = await svc.sendTrx(
        fromBase58: entry.addressBase58,
        toBase58: to,
        sunAmount: sun,
        privateKey: pk,
      );

      // 记忆上次（不覆盖固定配置）
      if ((Hive.box('settings').get('energy_purchase_to') as String?) == null &&
          (Hive.box('settings').get('trx_default_to') as String?) == null) {
        await Hive.box('settings').put('energy_last_to', to);
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('已发起转账（购买能量）'),
          content: SelectableText('TxID: $txid'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭')),
            FilledButton(
              onPressed: () {
                final url =
                    Uri.parse('https://tronscan.org/#/transaction/$txid');
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
              child: const Text('在区块浏览器查看'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, txid); // 返回上一页
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('购买能量失败：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('购买能量（转 TRX）'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (entry != null) ...[
                  Text('付款地址', style: text.labelMedium),
                  const SizedBox(height: 6),
                  _mono(entry.addressBase58, theme),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Text('收款地址（Base58）', style: text.labelMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: _addrLocked ? '已从配置自动填入，点此解锁编辑' : '未锁定，可编辑',
                      onPressed: () =>
                          setState(() => _addrLocked = !_addrLocked),
                      icon: Icon(_addrLocked ? Icons.lock : Icons.lock_open),
                    ),
                    IconButton(
                      tooltip: '前往设置',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/settings'),
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _toCtl,
                  readOnly: _addrLocked,
                  decoration: InputDecoration(
                    hintText: '例如：TKSQ...',
                    prefixIcon:
                        const Icon(Icons.account_balance_wallet_outlined),
                    suffixIcon: IconButton(
                      tooltip: '扫码填入',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final raw = await showQrScannerSheet(context);
                        if (raw == null || raw.isEmpty) return;
                        final addr = extractTronBase58(raw) ?? raw;
                        _toCtl.text = addr;
                        setState(() {});
                      },
                    ),
                  ),
                  validator: _vAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Text('TRX 数量', style: text.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amtCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '最多 6 位小数',
                    prefixIcon: Icon(Icons.numbers),
                    suffixText: 'TRX',
                  ),
                  validator: _vAmount,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('三组口令', style: text.labelMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: _obscure ? '显示口令' : '隐藏口令',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                    )
                  ],
                ),
                TextFormField(
                  controller: _p1Ctl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(hintText: '口令一'),
                  validator: _vPass,
                ),
                if ((_entry?.hint1?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('提示：${_entry!.hint1!}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(137, 200, 200, 200))),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _p2Ctl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(hintText: '口令二'),
                  validator: _vPass,
                ),
                if ((_entry?.hint2?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('提示：${_entry!.hint2!}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(137, 200, 200, 200))),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _p3Ctl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(hintText: '口令三'),
                  validator: _vPass,
                ),
                if ((_entry?.hint3?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('提示：${_entry!.hint3!}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(137, 200, 200, 200))),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt),
                    label: const Text('确认购买能量'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mono(String s, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: SelectableText(
        s,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}
