import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WalletSecurityService {
  // 锁定配置
  static const int maxFailedAttempts = 3;
  static const Duration lockDuration = Duration(minutes: 30);
  static const String lockBoxName = 'wallet_locks';

  // 检查钱包是否被锁定
  static Future<bool> isWalletLocked(String walletId) async {
    try {
      final box = await Hive.openBox(lockBoxName);
      // 安全地处理类型转换
      final dynamic rawData = box.get(walletId);
      final lockData = _convertToMap(rawData);
      await box.close();

      if (lockData == null || lockData['lockedUntil'] == null) {
        return false;
      }

      final lockedUntil = DateTime.parse(lockData['lockedUntil'].toString());
      final currentTime = DateTime.now();

      // 检查锁定是否已过期
      if (currentTime.isAfter(lockedUntil)) {
        // 锁定已过期，清除锁定记录
        await resetFailedAttempts(walletId);
        return false;
      }

      return true;
    } catch (e) {
      print('检查钱包锁定状态失败: $e');
      return false;
    }
  }

  // 获取剩余锁定时间
  static Future<Duration?> getRemainingLockTime(String walletId) async {
    try {
      final box = await Hive.openBox(lockBoxName);
      // 安全地处理类型转换
      final dynamic rawData = box.get(walletId);
      final lockData = _convertToMap(rawData);
      await box.close();

      if (lockData == null || lockData['lockedUntil'] == null) {
        return null;
      }

      final lockedUntil = DateTime.parse(lockData['lockedUntil'].toString());
      final currentTime = DateTime.now();

      if (currentTime.isAfter(lockedUntil)) {
        return null;
      }

      return lockedUntil.difference(currentTime);
    } catch (e) {
      print('获取剩余锁定时间失败: $e');
      return null;
    }
  }

  // 记录一次失败的密码尝试
  static Future<void> recordFailedAttempt(String walletId) async {
    try {
      final box = await Hive.openBox(lockBoxName);
      // 安全地处理类型转换
      final dynamic rawData = box.get(walletId);
      final lockData = _convertToMap(rawData);

      if (lockData == null) {
        // 首次失败
        box.put(walletId, {
          'failedAttempts': 1,
          'lastAttemptTime': DateTime.now().toIso8601String(),
        });
      } else {
        // 已有失败记录
        final failedAttempts = (lockData['failedAttempts'] as int?) ?? 0 + 1;
        
        if (failedAttempts >= maxFailedAttempts) {
          // 达到最大失败次数，锁定钱包
          final lockedUntil = DateTime.now().add(lockDuration);
          box.put(walletId, {
            'failedAttempts': failedAttempts,
            'lockedUntil': lockedUntil.toIso8601String(),
            'lastAttemptTime': DateTime.now().toIso8601String(),
          });
        } else {
          // 更新失败次数
          box.put(walletId, {
            'failedAttempts': failedAttempts,
            'lastAttemptTime': DateTime.now().toIso8601String(),
          });
        }
      }

      await box.close();
    } catch (e) {
      print('记录失败尝试失败: $e');
    }
  }

  // 重置失败尝试次数
  static Future<void> resetFailedAttempts(String walletId) async {
    try {
      final box = await Hive.openBox(lockBoxName);
      await box.delete(walletId);
      await box.close();
    } catch (e) {
      print('重置失败尝试次数失败: $e');
    }
  }

  // 私有方法：将动态类型转换为Map<String, dynamic>
  static Map<String, dynamic>? _convertToMap(dynamic rawData) {
    if (rawData == null) {
      return null;
    }
    
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    
    if (rawData is Map) {
      // 将Map<dynamic, dynamic>转换为Map<String, dynamic>
      final Map<String, dynamic> result = {};
      rawData.forEach((key, value) {
        if (key is String) {
          result[key] = value;
        } else if (key != null) {
          result[key.toString()] = value;
        }
      });
      return result;
    }
    
    return null;
  }

  // 检查安全风险
  static Future<Map<String, String>> checkSecurityRisks() async {
    final risks = <String, String>{};
    
    // 1. 检查设备是否越狱/root
    if (await _isDeviceCompromised()) {
      risks['rootedDevice'] = '设备已被越狱/root，存在安全风险';
    }

    // 2. 检查存储权限
    if (await _hasInsecureStoragePermissions()) {
      risks['storagePermission'] = '应用有过于宽松的存储权限，可能导致数据泄露';
    }

    // 3. 检查剪贴板监听
    if (await _hasClipboardMonitors()) {
      risks['clipboardMonitor'] = '检测到可能的剪贴板监听程序，可能导致敏感信息泄露';
    }

    // 4. 检查调试模式
    if (await _isDebugMode()) {
      risks['debugMode'] = '应用正在调试模式下运行，存在安全风险';
    }

    return risks;
  }

  // 安全提示
  static String getSecurityTips() {
    return '''
    1. 请勿在公共设备上导入钱包
    2. 请勿将助记词或私钥告诉任何人
    3. 请勿截图或拍照保存助记词和私钥
    4. 请勿在不信任的网络环境下进行转账操作
    5. 定期备份钱包到安全的物理存储设备
    6. 如怀疑设备被入侵，请立即转移资产
    ''';
  }

  // 私有方法：检测设备是否越狱/root
  static Future<bool> _isDeviceCompromised() async {
    try {
      if (Platform.isAndroid) {
        // 检查常见的root路径和文件
        final paths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su',
          '/su/bin/su',
          '/system/xbin/daemonsu',
          '/system/etc/init.d/99SuperSUDaemon',
          '/system/bin/.ext/.su',
          '/system/usr/we-need-root/su',
          '/etc/.has_su_daemon',
          '/etc/.installed_su_daemon',
          '/proc/1/environ',
          '/dev/com.koushikdutta.superuser.daemon/',
        ];

        for (final path in paths) {
          if (await File(path).exists()) {
            return true;
          }
        }
      } else if (Platform.isIOS) {
        // iOS越狱检测
        final paths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt/',
          '/Applications/WinterBoard.app',
          '/Applications/SBSettings.app',
          '/Applications/MxTube.app',
        ];

        for (final path in paths) {
          if (await File(path).exists()) {
            return true;
          }
        }
      }
    } catch (e) {
      print('设备安全检测失败: $e');
    }
    return false;
  }

  // 私有方法：检查存储权限
  static Future<bool> _hasInsecureStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        // 检查Android设备的存储权限
        final storageStatus = await Permission.storage.status;
        final mediaStatus = await Permission.photos.status;
        final audioStatus = await Permission.audio.status;
        
        // 检查是否有过于宽松的存储权限
        if (storageStatus.isGranted || 
            mediaStatus.isGranted || 
            audioStatus.isGranted) {
          // 在Android 10及以上，存储权限模型已更改，但仍需谨慎
          if (Platform.isAndroid && 
              (await _getAndroidSdkVersion()) >= 29) {
            // 检查是否有MANAGE_EXTERNAL_STORAGE权限（危险权限）
            final manageStorageStatus = await Permission.manageExternalStorage.status;
            if (manageStorageStatus.isGranted) {
              return true;
            }
          } else {
            // 旧版Android，存储权限较宽松
            return true;
          }
        }
      } else if (Platform.isIOS) {
        // 检查iOS设备的相册权限
        final photosStatus = await Permission.photos.status;
        final mediaLibraryStatus = await Permission.mediaLibrary.status;
        
        if (photosStatus.isGranted || mediaLibraryStatus.isGranted) {
          return true;
        }
      }
    } catch (e) {
      print('检查存储权限失败: $e');
    }
    return false;
  }
  
  // 获取Android SDK版本（用于权限检查）
  static Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final MethodChannel channel = MethodChannel('android_sdk_version');
      final int version = await channel.invokeMethod('getSdkVersion');
      return version;
    } catch (e) {
      print('获取Android SDK版本失败: $e');
      return 0;
    }
  }

  // 私有方法：检查剪贴板监听
  static Future<bool> _hasClipboardMonitors() async {
    try {
      // 剪贴板监听检测是一个复杂的问题，这里实现一个简单的检测方法
      
      // 1. 检查剪贴板内容变化频率
      const maxChecks = 3;
      const checkInterval = Duration(seconds: 1);
      
      for (int i = 0; i < maxChecks; i++) {
        await Future.delayed(checkInterval);
        final data = await Clipboard.getData('text/plain');
        if (data?.text != null) {
          // 检查是否包含敏感模式（如助记词、私钥模式）
          if (_containsSensitivePattern(data!.text!)) {
            // 如果剪贴板包含敏感信息，可能被监听
            return true;
          }
        }
      }
      
      // 2. 检查是否有可疑的剪贴板访问行为
      // 在Android上，可以通过AccessibilityService或ContentObserver监听剪贴板
      // 但在Flutter中直接检测比较困难，这里简化处理
      
      // 3. 对于iOS，可以检查是否有应用使用了UIPasteboardChanged通知
      // 同样在Flutter中直接检测比较困难
      
      // 4. 检查是否有可疑的应用包名（Android）
      if (Platform.isAndroid) {
        // 实际项目中可以使用platform channel调用原生API检查已安装应用
        // 这里仅作示意
        // final suspiciousPackages = [
        //   'com.example.spyapp',
        //   'com.malicious.clipboardmonitor',
        //   'com.spyware.app',
        // ];
        
        // 实际项目中应使用平台通道获取已安装应用列表并进行比对
        // 这里简化处理，返回false
      }
      
    } catch (e) {
      print('检查剪贴板监听失败: $e');
    }
    return false;
  }
  
  // 检查文本是否包含敏感模式
  static bool _containsSensitivePattern(String text) {
    // 检查助记词模式（12-24个单词）
    final mnemonicPattern = RegExp(r'\b(\w+\s+){11,23}\w+\b');
    if (mnemonicPattern.hasMatch(text)) {
      return true;
    }
    
    // 检查私钥模式（64位十六进制字符）
    final privateKeyPattern = RegExp(r'\b[0-9a-fA-F]{64}\b');
    if (privateKeyPattern.hasMatch(text)) {
      return true;
    }
    
    // 检查TRON地址模式（以T开头，长度约为34）
    final tronAddressPattern = RegExp(r'\bT[0-9a-zA-Z]{33}\b');
    if (tronAddressPattern.hasMatch(text)) {
      return true;
    }
    
    // 检查敏感关键词
    final sensitiveKeywords = [
      'mnemonic', 'seed phrase', 'private key', 'wallet import',
      '助记词', '私钥', '钱包导入', '密钥'
    ];
    
    for (final keyword in sensitiveKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }

  // 私有方法：检查调试模式
  static Future<bool> _isDebugMode() async {
    try {
      // 方法1：使用assert（仅在debug模式下为true）
      bool isDebug = false;
      assert(isDebug = true);
      if (isDebug) return true;
      
      // 方法2：使用kDebugMode（更可靠的方式）
      if (kDebugMode) return true;
      
      // 方法3：检查是否通过调试器连接
      // 在Dart中，可以使用inspector来检查
      if (await Isolate.packageConfig != null) {
        // 包配置存在可能表示调试模式
        return true;
      }
      
      // 方法4：检查是否有调试标志
      final arguments = Platform.executableArguments;
      if (arguments.contains('--enable-checked-mode') ||
          arguments.contains('--enable-asserts') ||
          arguments.contains('--debug')) {
        return true;
      }
      
      // 方法5：检查日志级别
      // 在release模式下，某些日志功能可能被禁用
      // 这里简化处理
      
      // 方法6：平台特定的调试检查
      if (Platform.isAndroid) {
        // 检查Android是否处于调试模式
        try {
          final MethodChannel channel = MethodChannel('debug_mode_check');
          final bool isDebugging = await channel.invokeMethod('isDebugging');
          if (isDebugging) return true;
        } catch (e) {
          // 忽略平台通道错误
        }
      } else if (Platform.isIOS) {
        // 检查iOS是否处于调试模式
        try {
          final MethodChannel channel = MethodChannel('debug_mode_check');
          final bool isDebugging = await channel.invokeMethod('isDebugging');
          if (isDebugging) return true;
        } catch (e) {
          // 忽略平台通道错误
        }
      }
      
    } catch (e) {
      print('检查调试模式失败: $e');
    }
    
    // 综合判断后返回结果
    return false;
  }
}