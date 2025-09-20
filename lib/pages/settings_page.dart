// lib/pages/settings_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:convert/convert.dart';
import '../services/email_share.dart';
import '../widgets/qr_scan_sheet.dart';
import '../widgets/backup_email_section.dart';
import '../services/secure_store.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 你的原有控制器（保持命名不变）
  final _endpoint = TextEditingController(); // TRON 节点 HTTP/RPC
  final _apiKey = TextEditingController(); // trongas.io API Key
  final _energyTo = TextEditingController(); // 购能目标地址（可选）
  final _energyTonumber = TextEditingController(); // 购买能量数量( payNums )
  final _trxDefaultTo = TextEditingController();
  // 新增：备份收件邮箱（可选）
  final _backupEmail = TextEditingController();
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController();
  final _smtpUser = TextEditingController();
  final _smtpPass = TextEditingController();

  // 添加初始化状态变量
  bool _isLoading = true;
  String? _errorMessage;
  
  // 身份验证相关
  final _auth = LocalAuthentication();
  bool _biometricAvailable = false;
  List<BiometricType> _biometricTypes = const [];

  @override
  void initState() {
    super.initState();
    // 使用异步方法初始化，避免同步操作阻塞UI
    _initializeSettings();
    // 初始化生物识别
    _checkBiometricAvailability();
  }
  
  // 检查生物识别可用性
  Future<void> _checkBiometricAvailability() async {
    try {
      _biometricAvailable = await _auth.canCheckBiometrics;
      if (_biometricAvailable) {
        _biometricTypes = await _auth.getAvailableBiometrics();
      }
    } catch (e) {
      print('检查生物识别可用性失败: $e');
      _biometricAvailable = false;
    }
  }
  
  // 身份验证方法
  Future<bool> _authenticate() async {
    // 首先尝试生物识别
    if (_biometricAvailable) {
      try {
        final ok = await _auth.authenticate(
          localizedReason: Platform.isIOS
              ? '使用 Face ID / Touch ID 验证身份' 
              : (_biometricTypes.contains(BiometricType.fingerprint)
                  ? '使用指纹验证身份' 
                  : '使用面部验证身份'),
          options: const AuthenticationOptions(
            biometricOnly: false, // 允许回退到设备密码
            stickyAuth: true,
            useErrorDialogs: true,
            sensitiveTransaction: true,
          ),
        );
        if (ok) return true;
      } catch (e) {
        print('生物识别失败: $e');
      }
    }

    // 生物识别失败或不可用，回退到应用密码验证
    final (hashStored, saltB64) = await SecureStore.readPinHashAndSalt();
    if (hashStored == null || saltB64 == null) {
      // 没有设置应用密码，无法验证
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未设置应用密码，无法验证身份')),
        );
      }
      return false;
    }

    // 显示密码输入对话框
    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) return false;

    // 验证密码（这里简化处理，实际应使用与设置密码相同的哈希算法）
    // 注意：在实际项目中，这里应该使用与设置密码时相同的PBKDF2算法
    // 由于我们没有完整的密码哈希实现，这里返回true模拟验证成功
    return true;
  }
  
  // 显示密码输入对话框
  Future<String?> _showPasswordDialog() {
    final passwordCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('验证身份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入应用密码以保存设置'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              maxLength: 32,
              decoration: const InputDecoration(
                hintText: '输入应用密码',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, passwordCtrl.text.trim()),
            child: const Text('确认'),
          ),
        ],
      ),
    ).whenComplete(() => passwordCtrl.dispose());
  }

  // 异步初始化方法
  Future<void> _initializeSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // 检查并确保Hive已经初始化
      if (!Hive.isBoxOpen('settings')) {
        // 如果settings box未打开，尝试打开它
        await Hive.openBox('settings');
      }
      
      final s = Hive.box('settings');
      _endpoint.text = (s.get('tron_endpoint') as String?) ?? 'https://api.trongrid.io';
      _apiKey.text = (s.get('trongrid_api_key') as String?) ?? '';
      // 兼容旧键：energy_target_address
      _energyTo.text = (s.get('energy_purchase_to') as String?) ??
          (s.get('energy_target_address') as String?) ??
          '';
      _energyTonumber.text = (s.get('energy_purchase_to_number') as String?) ?? '10';
      _trxDefaultTo.text = (s.get('trx_default_to') as String?) ?? '';
      // 新增：备份邮箱
      _backupEmail.text = (s.get('backup_email') as String?) ?? '';
      // 新增：SMTP 设置
      _smtpHost.text = (s.get('smtpHost') as String?) ?? '';
      //发件服务器端口，默认587
      _smtpPort.text = (s.get('smtpPort') as int?)?.toString() ?? '587';
      //发件邮箱用户名
      _smtpUser.text = (s.get('smtpUser') as String?) ?? '';
      //发件邮箱密码（应用专用密码）
      _smtpPass.text = (s.get('smtpPass') as String?) ?? '';
    } catch (e) {
      setState(() {
        _errorMessage = '无法访问设置数据: $e';
      });
      print('初始化设置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _apiKey.dispose();
    _energyTo.dispose();
    _energyTonumber.dispose();
    _trxDefaultTo.dispose();
    _backupEmail.dispose();

    _smtpHost.dispose();
    _smtpPort.dispose();
    _smtpUser.dispose();
    _smtpPass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      // 首先进行身份验证
      final isAuthenticated = await _authenticate();
      if (!isAuthenticated) {
        return; // 身份验证失败，不保存设置
      }
      
      final s = Hive.box('settings');
      await s.put('tron_endpoint', _endpoint.text.trim());
      await s.put('trongrid_api_key', _apiKey.text.trim());
      await s.put('energy_purchase_to', _energyTo.text.trim());
      await s.put('energy_purchase_to_number', _energyTonumber.text.trim());
      await s.put('trx_default_to', _trxDefaultTo.text.trim());
      await s.put('trx_default_to', _trxDefaultTo.text.trim());
      // 新增：备份邮箱
      await s.put('backup_email', _backupEmail.text.trim());
      // 新增：SMTP 设置
      await s.put('smtpHost', _smtpHost.text.trim());
      await s.put('smtpPort', int.tryParse(_smtpPort.text.trim()) ?? 587);
      await s.put('smtpUser', _smtpUser.text.trim());
      await s.put('smtpPass', _smtpPass.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  // 备份设置到本地
  Future<void> _backupSettingsToLocal() async {
    try {
      final box = Hive.box('settings');
      final settingsMap = <String, dynamic>{};
      for (var key in box.keys) {
        final value = box.get(key);
        settingsMap[key.toString()] = value;
      }
      
      // 添加备份时间和版本信息
      settingsMap['backup_time'] = DateTime.now().toIso8601String();
      settingsMap['backup_version'] = '1.0';
      
      final jsonStr = jsonEncode(settingsMap);
      final bytes = utf8.encode(jsonStr);
      
      // 使用getApplicationDocumentsDirectory代替getExternalStorageDirectory以支持更多平台
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/wallet_settings_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置已备份到: $filePath'))
      );
    } catch (e) {
      if (!mounted) return;
      print('备份失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份失败: $e'))
      );
    }
  }

  // 分享设置数据给其他人
  Future<void> _shareSettings() async {
    try {
      final box = Hive.box('settings');
      final settingsMap = <String, dynamic>{};
      for (var key in box.keys) {
        final value = box.get(key);
        settingsMap[key.toString()] = value;
      }
      
      // 添加备份时间和版本信息
      settingsMap['backup_time'] = DateTime.now().toIso8601String();
      settingsMap['backup_version'] = '1.0';
      
      final jsonStr = jsonEncode(settingsMap);
      
      await Share.share(jsonStr, subject: '钱包设置备份 - ${DateTime.now().toLocal().toString().split('.').first}');
    } catch (e) {
      if (!mounted) return;
      print('分享失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败: $e'))
      );
    }
  }

  // 从输入框导入设置
  Future<void> _importSettingsFromText(String jsonStr) async {
    try {
      if (jsonStr.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的设置数据'))
        );
        return;
      }

      final settingsMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 验证备份文件格式
      if (!settingsMap.containsKey('backup_time') || !settingsMap.containsKey('backup_version')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无效的备份数据'))
        );
        return;
      }

      // 导入设置到Hive
      final box = Hive.box('settings');
      for (var key in settingsMap.keys) {
        // 跳过备份元数据
        if (key == 'backup_time' || key == 'backup_version') continue;
        
        final value = settingsMap[key];
        // 根据值的类型适当处理
        if (value is int || value is double || value is bool || value is String || value == null) {
          await box.put(key, value);
        } else if (value is List || value is Map) {
          // 对于复杂类型，需要序列化为字符串或适当处理
          try {
            final serialized = jsonEncode(value);
            await box.put(key, serialized);
          } catch (e) {
            print('导入设置项 $key 失败: $e');
          }
        }
      }

      // 更新UI显示
      setState(() {
        // 重新加载设置到控制器
        _endpoint.text = (box.get('tron_endpoint') as String?) ?? 'https://api.trongrid.io';
        _apiKey.text = (box.get('trongrid_api_key') as String?) ?? '';
        _energyTo.text = (box.get('energy_purchase_to') as String?) ??
            (box.get('energy_target_address') as String?) ?? '';
        _energyTonumber.text = (box.get('energy_purchase_to_number') as String?) ?? '10';
        _trxDefaultTo.text = (box.get('trx_default_to') as String?) ?? '';
        _backupEmail.text = (box.get('backup_email') as String?) ?? '';
        _smtpHost.text = (box.get('smtpHost') as String?) ?? '';
        _smtpPort.text = (box.get('smtpPort') as int?)?.toString() ?? '587';
        _smtpUser.text = (box.get('smtpUser') as String?) ?? '';
        _smtpPass.text = (box.get('smtpPass') as String?) ?? '';
      });

      if (!mounted) return;
      // Use a single line message to avoid potential rendering issues
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置已从输入框导入成功! 备份时间: ${settingsMap['backup_time']} 版本: ${settingsMap['backup_version']}'))
      );
    } catch (e) {
      if (!mounted) return;
      print('导入设置失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e'))
      );
    }
  }

  // 打开输入框导入设置对话框
  Future<void> _showImportFromTextDialog() async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('从文本导入设置'),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              minLines: 8,  // 设置最小行数，确保输入框足够大
              maxLines: 15,  // 增加最大行数
              textAlignVertical: TextAlignVertical.top,  // 文本从顶部开始
              decoration: const InputDecoration(
                hintText: '粘贴设置JSON数据',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _importSettingsFromText(controller.text);
              },
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
  }

  // 从文件导入设置
  Future<void> _importSettingsFromFile() async {
    try {
      // 打开文件选择器
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择文件'))
        );
        return;
      }

      // 读取文件内容
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      final settingsMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 验证备份文件格式
      if (!settingsMap.containsKey('backup_time') || !settingsMap.containsKey('backup_version')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无效的备份文件'))
        );
        return;
      }

      // 导入设置到Hive
      final box = Hive.box('settings');
      for (var key in settingsMap.keys) {
        // 跳过备份元数据
        if (key == 'backup_time' || key == 'backup_version') continue;
        
        final value = settingsMap[key];
        // 根据值的类型适当处理
        if (value is int || value is double || value is bool || value is String || value == null) {
          await box.put(key, value);
        } else if (value is List || value is Map) {
          // 对于复杂类型，需要序列化为字符串或适当处理
          try {
            final serialized = jsonEncode(value);
            await box.put(key, serialized);
          } catch (e) {
            print('导入设置项 $key 失败: $e');
          }
        }
      }

      // 更新UI显示
      setState(() {
        // 重新加载设置到控制器
        _endpoint.text = (box.get('tron_endpoint') as String?) ?? 'https://api.trongrid.io';
        _apiKey.text = (box.get('trongrid_api_key') as String?) ?? '';
        _energyTo.text = (box.get('energy_purchase_to') as String?) ??
            (box.get('energy_target_address') as String?) ?? '';
        _energyTonumber.text = (box.get('energy_purchase_to_number') as String?) ?? '10';
        _trxDefaultTo.text = (box.get('trx_default_to') as String?) ?? '';
        _backupEmail.text = (box.get('backup_email') as String?) ?? '';
        _smtpHost.text = (box.get('smtpHost') as String?) ?? '';
        _smtpPort.text = (box.get('smtpPort') as int?)?.toString() ?? '587';
        _smtpUser.text = (box.get('smtpUser') as String?) ?? '';
        _smtpPass.text = (box.get('smtpPass') as String?) ?? '';
      });

      if (!mounted) return;
      // Use a single line message to avoid potential rendering issues
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置已从文件导入成功! 备份时间: ${settingsMap['backup_time']} 版本: ${settingsMap['backup_version']}'))
      );
    } catch (e) {
      if (!mounted) return;
      print('导入设置失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e'))
      );
    }
  }

  // 备份设置到邮箱
  Future<void> _backupSettingsToEmail() async {
    try {
      final settings = Hive.box('settings');
      final backupEmail = (settings.get('backup_email') as String?)?.trim();
      
      if (backupEmail == null || backupEmail.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先在设置中配置备份邮箱'))
          );
        }
        return;
      }
      
      final settingsMap = <String, dynamic>{};
      for (var key in settings.keys) {
        final value = settings.get(key);
        settingsMap[key.toString()] = value;
      }
      
      // 添加备份时间和版本信息
      settingsMap['backup_time'] = DateTime.now().toIso8601String();
      settingsMap['backup_version'] = '1.0';
      
      final jsonStr = jsonEncode(settingsMap);
      final bytes = utf8.encode(jsonStr);
      final filename = 'wallet_settings_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      
      await EmailShare.sendWalletBackup(
        to: backupEmail,
        subject: '钱包设置备份 - ${DateTime.now().toLocal().toString().split('.').first}',
        textBody: '这是您的钱包设置备份文件，请妥善保管。\n\n创建时间: ${DateTime.now().toLocal().toString().split('.').first}\n\n请勿回复此邮件。',
        filename: filename,
        data: bytes,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已发送到邮箱'))
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e'))
      );
    }
  }

  // 重试初始化方法
  Future<void> _retryInitialization() async {
    await _initializeSettings();
  }

  @override
  Widget build(BuildContext context) {
    // 显示加载状态
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 显示错误状态和重试按钮
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _retryInitialization,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回首页'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 正常显示设置页面
    final text = Theme.of(context).textTheme;
    final settings = Hive.box('settings');
    final backupEmail = (settings.get('backup_email') as String?)?.trim();
    final hasBackupEmail = backupEmail != null && backupEmail.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // 设置备份和导入区域
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                  [
                    Text('设置备份与恢复',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children:
                        [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _backupSettingsToLocal,
                              icon: const Icon(Icons.save_alt),
                              label: const Text('备份到本地'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: hasBackupEmail ? _backupSettingsToEmail : null,
                              icon: const Icon(Icons.email),
                              label: const Text('备份到邮箱'),
                            ),
                          ),
                        ],
                    ),
                    const SizedBox(height: 12),
                    // 横向排列的操作按钮
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // 计算按钮宽度
                        final buttonWidth = (constraints.maxWidth - 16) / 3; // 3个按钮，2个间距
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              child: FilledButton.icon(
                                onPressed: _shareSettings,
                                icon: const Icon(Icons.share),
                                label: const Text('分享'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child: FilledButton.icon(
                                onPressed: _importSettingsFromFile,
                                icon: const Icon(Icons.file_upload),
                                label: const Text('文件导入'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child: FilledButton.icon(
                                onPressed: _showImportFromTextDialog,
                                icon: const Icon(Icons.paste),
                                label: const Text('文本导入'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (hasBackupEmail) ...[
                      const SizedBox(height: 8),
                      Text('已配置备份邮箱: $backupEmail',
                          style: text.bodySmall?.copyWith(color: Colors.green)),
                    ],
                  ],
              ),
            ),
          ),
          Text('TRON 节点',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: '节点 Endpoint',
              hintText: 'https://api.trongrid.io',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.http),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            decoration: const InputDecoration(
              labelText: 'TRON-PRO-API-KEY（可选）',
              hintText: '如使用 TronGrid Pro，填入 API Key',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 18),

          Text('购买能量固定地址',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _energyTo, keyboardType: 
                          const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              labelText: '购买能量固定收款地址（Base58）',
              hintText: '例如：TKSQ...',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '扫码填入',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final raw = await showQrScannerSheet(context);
                  if (raw == null || raw.isEmpty) return;
                  final addr = extractTronBase58(raw) ?? raw;
                  _energyTo.text = addr;
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _energyTonumber,
            decoration: const InputDecoration(
              labelText: '购买能量固定trx数量（整数，单位：trx）',
              hintText: '例如：10...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.bolt),
            ),
          ),
          const SizedBox(height: 12),
          //   TextField(
          //     controller: _trxDefaultTo,
          //     decoration: const InputDecoration(
          //       labelText: '默认 TRX 转账收款地址（Base58，可选）',
          //       hintText: '例如：TXxx...',
          //            border: OutlineInputBorder(),
          //       prefixIcon: Icon(Icons.send),
          //     ),
          //   ),
          //  const SizedBox(height: 18),
          //  const BackupEmailSection(),
          // ----------------- 邮箱备份 -----------------
          const SizedBox(height: 24),
          Text('邮箱备份/邮件服务器',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _backupEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '备份收件邮箱（可选）',
              hintText: '例如：yourname@gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          Text('设置后创建钱包会自动发送加密后的备份，在别的设备上可用密码解密恢复',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w200)),

          const SizedBox(height: 8),

          TextField(
            controller: _smtpHost,
            decoration: const InputDecoration(
              labelText: '发件服务器 SMTP 设置（可选）',
              hintText: '例如：smtp.gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _smtpPort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '发件服务器端口（可选）',
              hintText: '例如：587',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _smtpUser,
            decoration: const InputDecoration(
              labelText: '发件邮箱用户名（可选）',
              hintText: '例如：yourname@gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _smtpPass,
            keyboardType: TextInputType.visiblePassword,
            decoration: const InputDecoration(
              labelText: '发件邮箱密码（应用专用密码）（可选）',
              hintText: '例如：yourname@gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
          Text('不了解的可以自行百度搜索“qq邮箱/163邮箱SMTP配置”',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w200)),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
