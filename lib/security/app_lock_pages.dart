import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_lock_service.dart';
import 'app_lock_controller.dart';
import 'app_lock_prefs.dart';

class AppLockSetupPage extends StatefulWidget {
  const AppLockSetupPage({super.key});
  @override
  State<AppLockSetupPage> createState() => _AppLockSetupPageState();
}

class _AppLockSetupPageState extends State<AppLockSetupPage> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  bool _bioSupported = false;
  bool _bioOn = true;

  @override
  void initState() {
    super.initState();
    AppLockService.canUseBiometrics().then((ok) {
      if (mounted) setState(() { _bioSupported = ok; _bioOn = ok; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _openDebugPanel,
          child: const Text('设置应用密码'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('首次使用，请设置 6 位数字密码（用于解锁应用）'),
            const SizedBox(height: 16),
            TextField(
              controller: _p1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '输入密码（仅数字）'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _p2,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '确认密码'),
            ),
            const SizedBox(height: 12),
            if (_bioSupported)
              SwitchListTile(
                value: _bioOn,
                onChanged: (v) => setState(() => _bioOn = v),
                title: const Text('启用 Face ID / 指纹解锁'),
                subtitle: const Text('更快捷地解锁应用'),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock),
              label: const Text('设为应用密码并继续'),
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final a = _p1.text.trim(), b = _p2.text.trim();
    if (a != b || a.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入不一致，或长度不足 4 位')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AppLockService.setPin(a, enableBiometrics: _bioOn);
      await AppLockPrefs.setOnboarded(true);   // 记录首启完成
      AppLockController.instance.setUnlocked(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDebugPanel() async {
    final snap = await AppLockService.debugSnapshot();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AppLock 调试', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: AppLockPrefs.isOnboarded(),
              builder: (_, s) => Text('onboarded: ${s.data}'),
            ),
            Text('hasPin: ${snap['hash'] != null && snap['salt'] != null}'),
            Text('bio: ${snap['bio']}'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await AppLockService.deleteAllLockKeys();
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除 AppLock Keychain')));
                  },
                  child: const Text('清除锁数据'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await AppLockPrefs.setOnboarded(false);
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下次启动会进入设置页')));
                  },
                  child: const Text('清除首启标记'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppLockUnlockPage extends StatefulWidget {
  const AppLockUnlockPage({super.key});
  @override
  State<AppLockUnlockPage> createState() => _AppLockUnlockPageState();
}

class _AppLockUnlockPageState extends State<AppLockUnlockPage> {
  final _pin = TextEditingController();
  bool _busy = false;
  bool _bioEnabled = false;
  bool _bioTried = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await AppLockService.biometricsEnabled();
    if (!mounted) return;
    setState(() => _bioEnabled = ok);
    if (ok && !_bioTried) {
      _bioTried = true;
      final pass = await AppLockService.authWithBiometrics();
      if (pass) AppLockController.instance.setUnlocked(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _openDebugPanel,
          child: const Text('解锁'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pin,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '输入应用密码（仅数字）'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open),
              label: const Text('解锁'),
              onPressed: _busy ? null : _unlock,
            ),
            const SizedBox(height: 8),
            if (_bioEnabled)
              OutlinedButton.icon(
                icon: const Icon(Icons.face_6),
                label: const Text('使用 Face ID'),
                onPressed: () async {
                  final pass = await AppLockService.authWithBiometrics();
                  if (pass) AppLockController.instance.setUnlocked(true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    try {
      final ok = await AppLockService.verifyPin(_pin.text);
      if (ok) {
        AppLockController.instance.setUnlocked(true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('密码不正确')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDebugPanel() async {
    final snap = await AppLockService.debugSnapshot();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AppLock 调试', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: AppLockPrefs.isOnboarded(),
              builder: (_, s) => Text('onboarded: ${s.data}'),
            ),
            Text('hasPin: ${snap['hash'] != null && snap['salt'] != null}'),
            Text('bio: ${snap['bio']}'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await AppLockService.deleteAllLockKeys();
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除 AppLock Keychain')));
                  },
                  child: const Text('清除锁数据'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await AppLockPrefs.setOnboarded(false);
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下次启动会进入设置页')));
                  },
                  child: const Text('清除首启标记'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
