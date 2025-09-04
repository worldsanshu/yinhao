import 'package:flutter/foundation.dart';

class AppLockController extends ChangeNotifier {
  AppLockController._();
  static final AppLockController instance = AppLockController._();
  bool _unlocked = false;
  bool get unlocked => _unlocked;
  void setUnlocked(bool v) {
    if (_unlocked == v) return;
    _unlocked = v;
    notifyListeners();
  }
}
