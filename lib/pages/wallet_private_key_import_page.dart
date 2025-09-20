// lib/pages/wallet_private_key_import_page.dart
import 'package:crypto/crypto.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:pointycastle/pointycastle.dart' as pc;
import 'package:bip39/bip39.dart' as bip39;

import '../models/wallet_entry.dart';
import '../services/crypto_service.dart';
import '../services/wallet_import_service.dart';
import '../services/wallet_validation_service.dart';
import '../utils/password_helper.dart';
import '../widgets/qr_scan_sheet.dart';

class WalletPrivateKeyImportPage extends StatefulWidget {
  const WalletPrivateKeyImportPage({Key? key}) : super(key: key);

  @override
  State<WalletPrivateKeyImportPage> createState() =>
      _WalletPrivateKeyImportPageState();
}

class _WalletPrivateKeyImportPageState
    extends State<WalletPrivateKeyImportPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _masterPasswordController = TextEditingController();
  final _paymentPasswordController = TextEditingController();
  final _recoveryPasswordController = TextEditingController();

  // 密码提示状态
  String _password1 = '';
  String _password2 = '';
  String _password3 = '';
  bool _showMasterPassword = false;
  bool _showPaymentPassword = false;
  bool _showRecoveryPassword = false;

  bool _isLoading = false;
  bool _isMnemonicMode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _privateKeyController.dispose();
    _masterPasswordController.dispose();
    _paymentPasswordController.dispose();
    _recoveryPasswordController.dispose();
    super.dispose();
  }

  /// 辅助方法：标准化私钥格式
  String? _normalizePrivateKey(String privateKey) {
    try {
      final s = privateKey.trim();
      // 移除可能的前缀
      String clean = s.startsWith('0x') ? s.substring(2) : s;

      // 确保是64个十六进制字符
      if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(clean)) {
        return clean.toLowerCase();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 从助记词生成私钥（使用标准BIP39协议）
  String _generatePrivateKeyFromMnemonic(String mnemonic) {
    try {
      // 使用标准的BIP39库从助记词生成seed
      final seed = bip39.mnemonicToSeed(mnemonic);

      // 使用HMAC-SHA512从seed生成主私钥（BIP32的第一步）
      final hmac = pc.Mac('SHA-512/HMAC');
      final hmacParams = pc.KeyParameter(utf8.encode('Bitcoin seed'));
      hmac.init(hmacParams);
      final i = hmac.process(seed);

      // 取i的前32字节作为主私钥并转换为十六进制字符串
      final privateKey = i.sublist(0, 32);
      return hex.encode(privateKey);
    } catch (e) {
      // 如果标准实现失败，回退到原始的双重SHA256方法
      try {
        final firstHash = sha256.convert(utf8.encode(mnemonic)).bytes;
        final secondHash = sha256.convert(firstHash).bytes;
        return hex.encode(secondHash);
      } catch (_) {
        return '';
      }
    }
  }

  // 更新密码提示
  void _updatePasswordHint(String password, String hintType) {
    final maskedPassword = PasswordHelper.maskKeep2Head1Tail(password);
    print(maskedPassword);
    setState(() {
      if (hintType == 'password1') {
        _password1 = maskedPassword;
      } else if (hintType == 'password2') {
        _password2 = maskedPassword;
      } else if (hintType == 'password3') {
        _password3 = maskedPassword;
      }
    });
  }

  // 切换密码显示/隐藏
  void _togglePasswordVisibility(String passwordType) {
    setState(() {
      if (passwordType == 'password1') {
        _showMasterPassword = !_showMasterPassword;
      } else if (passwordType == 'password2') {
        _showPaymentPassword = !_showPaymentPassword;
      } else if (passwordType == 'password3') {
        _showRecoveryPassword = !_showRecoveryPassword;
      }
    });
  }

  // 失焦收起键盘
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // 打开二维码扫描
  Future<void> _openScanner() async {
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      final result = await showQrScannerSheet(context);
      if (result != null && result.isNotEmpty) {
        setState(() {
          _privateKeyController.text = result;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相机权限才能扫描二维码')),
        );
      }
    }
  }

  // 自定义密码输入组件
  Widget _PwField(
      {required TextEditingController controller,
      required String label,
      required String hintText,
      required String hintType,
      required String showPasswordType,
      required bool showPassword,
      required Color tileBg}) {
   
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            fillColor: tileBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none, // 无明显边框
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            labelText: label,
            hintText: hintText,
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => _togglePasswordVisibility(showPasswordType),
            ),
          ),
          obscureText: !showPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入$label';
            }
            // 根据需求，不需要对密码长度做限制
            return null;
          },
          onChanged: (value) => _updatePasswordHint(value, hintType),
          onTapOutside: (event) => _dismissKeyboard(),
        ),
        const SizedBox(height: 4),

        // 密码提示
        Text(
          controller.text.isNotEmpty
              ? '密码提示：${PasswordHelper.maskKeep2Head1Tail(controller.text)}'
              : '请输入$label',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      WalletEntry walletEntry;

      if (_isMnemonicMode) {
        walletEntry = await WalletImportService.importFromMnemonic(
          _privateKeyController.text,
          _nameController.text,
          _masterPasswordController.text,
          _paymentPasswordController.text,
          _recoveryPasswordController.text,
        );
      } else {
        walletEntry = await WalletImportService.importFromPrivateKey(
          _privateKeyController.text,
          _nameController.text,
          _masterPasswordController.text,
          _paymentPasswordController.text,
          _recoveryPasswordController.text,
        );
      }

      // 注意：在WalletImportService.importFromPrivateKey和importFromMnemonic方法中已经包含了地址验证
      // 所以这里不再需要单独验证

      // 获取原始私钥（用于验证）
      final privateKeyHex = _isMnemonicMode
          ? _generatePrivateKeyFromMnemonic(_privateKeyController.text)
          : _normalizePrivateKey(_privateKeyController.text) ?? '';

      if (privateKeyHex.isEmpty) {
        throw Exception('无法提取有效的私钥进行验证');
      }

      // 使用增强的钱包验证服务进行验证
      final isWalletValid =
          await WalletValidationService.enhancedWalletValidation(
              walletEntry,
              privateKeyHex,
              _masterPasswordController.text,
              _paymentPasswordController.text,
              _recoveryPasswordController.text);

      if (!isWalletValid) {
        throw Exception('钱包验证失败，无法使用此钱包。请检查私钥和密码是否正确。');
      }

      // 保存钱包到数据库
      final box = Hive.box('wallets');
      await box.put(walletEntry.id, walletEntry.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('钱包导入成功！')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 与其它页同步的小卡底色/前景
    final tileBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.90);
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入钱包'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // 切换私钥/助记词模式
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ToggleButtons(
                      isSelected: [!_isMnemonicMode, _isMnemonicMode],
                      onPressed: (int index) {
                        setState(() {
                          _isMnemonicMode = index == 1;
                          _privateKeyController.clear();
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('私钥导入'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                      
                             child: Text('助记词导入'),
                         
                         
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 钱包名称
                TextFormField(
                  controller: _nameController,
                  decoration: _filledInput('钱包名称', tileBg),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入钱包名称';
                    }
                    return null;
                  },
                  onTapOutside: (event) => _dismissKeyboard(),
                ),
                const SizedBox(height: 16),

                // 私钥/助记词输入
                TextFormField(
                  controller: _privateKeyController,
                  decoration: InputDecoration(
                    fillColor: tileBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none, // 无明显边框
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    labelText: _isMnemonicMode ? '助记词' : '私钥',
                    hintText: _isMnemonicMode
                        ? '请输入12/15/18/21/24个单词的助记词，用空格分隔'
                        : '请输入64位十六进制私钥',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      // onPressed: _openScanner,
                      onPressed: () async {
                        final raw = await showQrScannerSheet(context);
                        if (raw == null || raw.isEmpty) return;
                        final addr = extractTronBase58(raw) ?? raw;
                        _privateKeyController.text = addr;
                        setState(() {});
                      },
                    ),
                  ),
                  maxLines: _isMnemonicMode ? 4 : 1,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _isMnemonicMode ? '请输入助记词' : '请输入私钥';
                    }
                    return null;
                  },
                  onTapOutside: (event) => _dismissKeyboard(),
                ),
                const SizedBox(height: 16),

                // 主密码（密码1）
                _PwField(
                    controller: _masterPasswordController,
                    label: '密码1',
                    hintText: '请输入密码1',
                    hintType: '密码1',
                    showPasswordType: 'password1',
                    showPassword: _showMasterPassword,
                    tileBg: tileBg),
                const SizedBox(height: 16),

                // 支付密码（密码2）
                _PwField(
                    controller: _paymentPasswordController,
                    label: '密码2',
                    hintText: '请输入密码2',
                    hintType: '密码2',
                    showPasswordType: 'password2',
                    showPassword: _showPaymentPassword,
                    tileBg: tileBg),
                const SizedBox(height: 16),

                // 恢复密码（密码3）
                _PwField(
                    controller: _recoveryPasswordController,
                    label: '密码3',
                    hintText: '请输入密码3',
                    hintType: '密码3',
                    showPasswordType: 'password3',
                    showPassword: _showRecoveryPassword,
                    tileBg: tileBg),
                const SizedBox(height: 24),

                // 导入按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _importWallet,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('导入钱包'),
                ),
                const SizedBox(height: 16),

                // 提示信息
                const Center(
                  child: Text(
                    '导入后，钱包将被转换为三密码模式存储',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
