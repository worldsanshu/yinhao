// lib/utils/password_helper.dart

/// 密码帮助工具类
class PasswordHelper {
  /// 隐藏密码中间部分，只显示前2位和后1位
  static String maskKeep2Head1Tail(String password) {
    if (password.isEmpty) {
      return '';
    }
    
    if (password.length <= 3) {
      return password; // 密码太短，不做隐藏处理
    }
    
    final head = password.substring(0, 2);
    final tail = password.substring(password.length - 1);
    final middle = '*' * (password.length - 3);
    
    return '$head$middle$tail';
  }
  
  /// 检查密码是否包含足够的复杂性（字母、数字和特殊字符）
  static bool isPasswordComplex(String password) {
    if (password.isEmpty) {
      return false;
    }
    
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSpecial = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);
    
    return hasLetter && hasDigit && hasSpecial;
  }
  
  /// 获取密码强度评级
  static String getPasswordStrength(String password) {
    if (password.isEmpty) {
      return '弱';
    }
    
    if (password.length < 8) {
      return '弱';
    }
    
    if (isPasswordComplex(password)) {
      return '强';
    }
    
    return '中';
  }
}