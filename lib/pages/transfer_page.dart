// lib/pages/transfer_page.dart
//
// 依赖：
//   mobile_scanner: ^3.5.7
//   permission_handler: ^11.3.1
//
// iOS: ios/Runner/Info.plist 必须有：
// <key>NSCameraUsageDescription</key>
// <string>用于扫描二维码</string>
// 且 Podfile 建议：platform :ios, '12.0'

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/crypto_service.dart';

import '../models/wallet_entry.dart';

/// 资产类型（详情页通过 initialAsset 预选）
enum AssetType { usdt, trx }

class TransferPage extends StatefulWidget {
  const TransferPage({
    super.key,
    required this.walletId,
    this.initialAsset = AssetType.usdt, // 支持 initialAsset
  });

  final String walletId;
  final AssetType initialAsset;

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _addrCtl = TextEditingController();
  final _amtCtl  = TextEditingController();
  final _p1Ctl   = TextEditingController();
  final _p2Ctl   = TextEditingController();
  final _p3Ctl   = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AssetType _asset; // 初始资产
  bool _submitting = false;
  bool _hideP1 = true, _hideP2 = true, _hideP3 = true;

  WalletEntry? _entry; // 当前钱包（用于名称/提示）

  @override
  void initState() {
    super.initState();
    _asset = widget.initialAsset;
    final box = Hive.box('wallets');
    _entry = WalletEntry.tryFrom(box.get(widget.walletId));
  }

  @override
  void dispose() {
    _addrCtl.dispose();
    _amtCtl.dispose();
    _p1Ctl.dispose();
    _p2Ctl.dispose();
    _p3Ctl.dispose();
    super.dispose();
  }

  // ---------------- 样式辅助 ----------------
  InputDecoration _filledInput(String hint, Color fill) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // 无明显边框
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  // ---------------- 地址提取 & 校验 ----------------

  // 允许多行文本中出现 tron: 或纯地址，提取有效 Tron 地址
  String? _extractTronAddress(String raw) {
    final s = raw.trim();
    final r = RegExp(r'(tron:)?(T[1-9A-HJ-NP-Za-km-z]{25,50})',
        caseSensitive: false, multiLine: true);
    final m = r.firstMatch(s);
    return m != null ? m.group(2) : null;
  }

  String? _validateAddress(String? v) {
    final addr = _extractTronAddress(v ?? '');
    if (addr == null) return '请粘贴/输入/扫描有效的 Tron 地址（以 T 开头）';
    return null;
  }

  String? _validateAmount(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '请输入金额';
    final d = double.tryParse(s);
    if (d == null || d <= 0) return '金额必须大于 0';
    return null;
  }

  String? _req(String? v) => (v == null || v.isEmpty) ? '必填' : null;

  bool get _canProceed =>
      _validateAddress(_addrCtl.text) == null &&
      _validateAmount(_amtCtl.text) == null &&
      _req(_p1Ctl.text) == null &&
      _req(_p2Ctl.text) == null &&
      _req(_p3Ctl.text) == null &&
      !_submitting;

  // ---------------- 扫码（权限 + 面板） ----------------

  Future<void> _openScanner() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.black,
        builder: (_) => _ScannerSheet(
          onDetected: (value) {
            final addr = _extractTronAddress(value);
            if (addr != null) {
              _addrCtl.text = addr;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已识别地址：$addr')),
              );
              Navigator.pop(context);
              setState(() {}); // 刷新按钮可用状态
            }
          },
        ),
      );
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('需要相机权限'),
          content: const Text('请在系统设置中开启相机权限后再试。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('前往设置')),
          ],
        ),
      );
      if (go == true) {
        await openAppSettings();
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未授予相机权限')),
      );
    }
  }

  // ---------------- 二次确认 → 最终确认 → 提交 ----------------

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;

    final normalized = _extractTronAddress(_addrCtl.text) ?? _addrCtl.text.trim();
    final amount     = _amtCtl.text.trim();
    final assetText  = _asset == AssetType.usdt ? 'USDT' : 'TRX';
  // ✅ 新增：先校验三口令（不返回私钥，仅验证正确性）
    final passOk = await CryptoService.verifyPasswords(
      _entry!, _p1Ctl.text, _p2Ctl.text, _p3Ctl.text,
    );
    if (!passOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('三组口令不正确')));
      return;
    }
    // 一级确认：底部面板勾选复核项
    final ok1 = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool c1 = false, c2 = false;
        return StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user, size: 20),
                    const SizedBox(width: 8),
                    Text('请再次确认转账信息',
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _confirmRow('资产', assetText),
                _confirmRow('金额', amount),
                _confirmRow('收款地址', normalized, mono: true),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: c1,
                  onChanged: (v) => setS(() => c1 = v ?? false),
                  title: const Text('我已核对收款地址（前后6位）无误'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: c2,
                  onChanged: (v) => setS(() => c2 = v ?? false),
                  title: const Text('我已核对转账金额无误'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: (c1 && c2) ? () => Navigator.pop(ctx, true) : null,
                  icon: const Icon(Icons.done),
                  label: const Text('已复核，继续'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (ok1 != true) return;

    // 二级最终确认对话框
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('最终确认'),
        content: Text('将向以下地址转账 $amount $assetText：\n$normalized'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认并发送')),
        ],
      ),
    );

    if (ok2 == true) {
      await _submit(normalized, amount);
    }
  }

  Widget _confirmRow(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64, child: Text(k, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              style: mono ? const TextStyle(fontFamily: 'monospace') : null,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 提交（接你的实际链上逻辑） ----------------

 Future<void> _submit(String toAddr, String amount) async {
  setState(() => _submitting = true);
  try {
    final entry = _entry!;
    final p1 = _p1Ctl.text.trim(), p2 = _p2Ctl.text.trim(), p3 = _p3Ctl.text.trim();

    // 1) 口令解密出 32 字节私钥（crypto_service.dart 里已做强校验）
    final pk = await CryptoService.decryptPrivateKeyWithThreePasswords(entry, p1, p2, p3);

    // 2) 构造发送器（TronGrid；如用自建节点，改 nodeUrl 即可）
    final tron = TransferService(
      nodeUrl: 'https://api.trongrid.io',
      tronProApiKey: null, // 若有 TronGrid Key 可填在这里
    );

    // 3) 解析金额为 6 位小数的整数（TRX=Sun、USDT=最小单位）
    BigInt _to6(String s) {
      final t = s.trim();
      if (t.isEmpty) return BigInt.zero;
      final parts = t.split('.');
      final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
      var frac = parts.length > 1 ? parts[1] : '0';
      if (frac.length > 6) frac = frac.substring(0, 6);
      final fracInt = BigInt.parse(frac.padRight(6, '0'));
      return whole * BigInt.from(1000000) + fracInt;
    }

    // 4) 真实广播
    late final String txId;
    if (_asset == AssetType.usdt) {
      // 主网 USDT（请再次核对）
      const usdtContract = 'TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9';
      txId = await tron.sendUsdt(
        fromBase58: entry.addressBase58,
        toBase58: toAddr,
        usdt6: _to6(amount),
        privateKey: pk,
        contractBase58: usdtContract,
      );
    } else {
      txId = await tron.sendTrx(
        fromBase58: entry.addressBase58,
        toBase58: toAddr,
        sunAmount: _to6(amount),
        privateKey: pk,
      );
    }

    if (!mounted) return;
    // 成功：回传真实 txID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已提交：$txId')),
    );
    Navigator.pop(context, true);
  } catch (e) {
    if (mounted) {
      // 友好化错误提示（口令错误 / 能量不足 / 节点报错等）
      final msg = e.toString().contains('口令') ? '三组口令不正确' : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转账失败：$msg')),
      );
    }
  } finally {
    if (mounted) setState(() => _submitting = false);
  }
}

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 与其它页同步的小卡底色/前景
    final tileBg = isDark ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.90);
    final tileFg = isDark ? Colors.white : Colors.black87;

    final assetText = _asset == AssetType.usdt ? 'USDT' : 'TRX';

    final walletName = (_entry?.name?.trim().isNotEmpty ?? false)
        ? _entry!.name!.trim()
        : (_entry?.addressBase58 ?? '');

    return Scaffold(
      appBar: AppBar(title: Text('转账 $assetText')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // 顶部：当前钱包
            if (walletName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text('当前钱包：$walletName',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),

            // 1) 收款地址（多行 + 粘贴 + 扫码）
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('收款地址', style: TextStyle(fontWeight: FontWeight.w600, color: tileFg)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addrCtl,
                          validator: _validateAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          minLines: 2,
                          maxLines: 4, // 多行显示，方便反复核对
                          keyboardType: TextInputType.multiline,
                          decoration: _filledInput('粘贴或扫描 Tron 地址（以 T 开头，可包含换行/前缀）', tileBg),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            tooltip: '粘贴',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              final t = data?.text ?? '';
                              if (t.isNotEmpty) {
                                _addrCtl.text = t;
                                setState(() {});
                              }
                            },
                            icon: Icon(Icons.paste, color: tileFg),
                          ),
                          IconButton(
                            tooltip: '扫码识别',
                            onPressed: _openScanner,
                            icon: Icon(Icons.qr_code_scanner, color: tileFg),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 识别出的标准地址回显
                  Builder(builder: (_) {
                    final normalized = _extractTronAddress(_addrCtl.text);
                    return Text(
                      normalized == null ? '未识别到有效地址' : '识别为：$normalized',
                      style: TextStyle(fontSize: 12, color: normalized == null ? Colors.red : Colors.black54),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2) 金额
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('金额（$assetText）', style: TextStyle(fontWeight: FontWeight.w600, color: tileFg)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amtCtl,
                    validator: _validateAmount,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: _filledInput('请输入转账金额', tileBg),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      // USDT/TRX 常见精度：保留 6 位
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}')),
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3) 三个密码（必须全部输入）
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('输入三个密码（与创建钱包时一致）',
                      style: TextStyle(fontWeight: FontWeight.w600, color: tileFg)),
                  const SizedBox(height: 8),

                  // 密码1
                  TextFormField(
                    controller: _p1Ctl,
                    validator: _req,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    obscureText: _hideP1,
                    decoration: _filledInput('密码1', tileBg).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideP1 = !_hideP1),
                        icon: Icon(_hideP1 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if ((_entry?.hint1?.trim().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('提示：${_entry!.hint1!}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),

                  const SizedBox(height: 10),

                  // 密码2
                  TextFormField(
                    controller: _p2Ctl,
                    validator: _req,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    obscureText: _hideP2,
                    decoration: _filledInput('密码2', tileBg).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideP2 = !_hideP2),
                        icon: Icon(_hideP2 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if ((_entry?.hint2?.trim().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('提示：${_entry!.hint2!}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),

                  const SizedBox(height: 10),

                  // 密码3
                  TextFormField(
                    controller: _p3Ctl,
                    validator: _req,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    obscureText: _hideP3,
                    decoration: _filledInput('密码3', tileBg).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideP3 = !_hideP3),
                        icon: Icon(_hideP3 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if ((_entry?.hint3?.trim().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('提示：${_entry!.hint3!}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4) 最后显示：下一步（仅当全部校验通过）
            FilledButton.icon(
              onPressed: _canProceed ? _onNext : null,
              icon: _submitting
                  ? SizedBox( // ← 去掉 const，避免 const+非常量子树
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_double_arrow_right),
              label: const Text('下一步'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              '安全提示：请务必核对收款地址与金额；USDT 为合约代币，TRX 为主币，请确保余额与网络费充足。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------- 扫码底部面板（兼容 mobile_scanner 3.5.7） ----------------

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet({required this.onDetected});
  final void Function(String raw) onDetected;

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final list = cap.barcodes;
    if (list.isEmpty) return;
    final raw = list.first.rawValue ?? '';
    if (raw.isEmpty) return;
    _handled = true;
    widget.onDetected(raw);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.70,
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // 相机被占用/出错时的兜底
            errorBuilder: (ctx, error, child) {
              return _ScanError(
                message: error.errorDetails?.message ?? error.toString(),
                onOpenSettings: () => openAppSettings(), // 来自 permission_handler
              );
            },
          ),

          // 顶部工具条
          Positioned(
            left: 8, right: 8, top: 8,
            child: Row(
              children: [
                IconButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                const Spacer(),
                IconButton(
                  color: Colors.white,
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flash_on),
                ),
                const SizedBox(width: 4),
                IconButton(
                  color: Colors.white,
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch),
                ),
              ],
            ),
          ),

          // 中心取景框
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.message, required this.onOpenSettings});
  final String message;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography, color: Colors.white, size: 64), // <- 换成通用图标
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onOpenSettings,
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }
}
