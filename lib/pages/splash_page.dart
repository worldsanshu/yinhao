import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/secure_store.dart';
import '../models/wallet_entry.dart';
import 'pin_lock_page.dart';
import 'onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Hive.initFlutter();
  await Hive.openBox('wallets');
  await Hive.openBox('settings');
   
    final (pinHash, _) = await SecureStore.readPinHashAndSalt();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (pinHash == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingPage()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PinLockPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
