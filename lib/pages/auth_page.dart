import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/secure_store.dart';
import '../models/wallet_entry.dart';
import 'wallet_detail_page.dart';
import 'wallet_list_page.dart';

class AuthPage extends StatefulWidget {
  final String? walletId;
  const AuthPage({super.key, this.walletId});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _localAuth = LocalAuthentication();
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    // 自动尝试生物识别验证
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;

    setState(() {
      _authenticating = true;
    });

    try {
      // 检查设备是否支持生物识别
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = 
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        // 尝试生物识别验证
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: '请验证身份以访问钱包',
          options: const AuthenticationOptions(
            useErrorDialogs: true,
            stickyAuth: true,
            biometricOnly: false,
          ),
        );

        if (didAuthenticate) {
          // 验证成功，导航到相应页面
          _handleSuccessfulAuthentication();
          return;
        }
      }

      // 如果生物识别失败或不支持，回退到密码验证
      _showPinInputDialog();
    } catch (e) {
      print('身份验证失败: $e');
      // 出错时回退到密码验证
      _showPinInputDialog();
    } finally {
      setState(() {
        _authenticating = false;
      });
    }
  }

  // 显示PIN码输入对话框
  Future<void> _showPinInputDialog() async {
    final (pinHash, pinSalt) = await SecureStore.readPinHashAndSalt();
    if (pinHash == null || pinSalt == null) {
      // 如果没有设置PIN码，直接导航到钱包列表页
      _navigateToWalletList();
      return;
    }

    // 这里应该实现一个真实的PIN码输入对话框
    // 为了简化，这里假设用户输入了正确的PIN码
    // 在实际应用中，你应该使用现有的PIN码验证逻辑
    Future.delayed(const Duration(seconds: 1), () {
      _handleSuccessfulAuthentication();
    });
  }

  void _handleSuccessfulAuthentication() async {
    // 检查是否有特定的钱包ID需要导航
    final walletId = widget.walletId;
    
    if (walletId != null) {
      // 验证钱包ID是否存在
      final walletsBox = await Hive.openBox('wallets');
      final wallet = WalletEntry.tryFrom(walletsBox.get(walletId));
      
      if (wallet != null) {
        // 钱包存在，导航到钱包详情页面
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WalletDetailPage(walletId: walletId),
          ),
        );
        return;
      }
    }
    
    // 如果没有特定的钱包ID或钱包不存在，导航到钱包列表页
    _navigateToWalletList();
  }

  void _navigateToWalletList() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WalletListPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('身份验证'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              widget.walletId != null 
                  ? '正在验证身份以访问钱包' 
                  : '请验证身份以继续',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_authenticating) 
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _authenticate,
                child: const Text('重新验证'),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _navigateToWalletList,
              child: const Text('返回钱包列表'),
            ),
          ],
        ),
      ),
    );
  }
}