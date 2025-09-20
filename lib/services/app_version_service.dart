import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App版本检查服务
class AppVersionService {
  static const String _appStoreId = 'com.yinhao.me.usdtvault'; // 替换为你的App Store ID
  static const String _appStoreUrl = 'https://apps.apple.com/app/id$_appStoreId';
  static const String _checkUpdateInterval = 'update_check_interval';
  static const String _lastUpdateCheck = 'last_update_check';
  static const int _defaultCheckInterval = 24; // 24小时检查一次

  /// 检查App Store是否有新版本
  static Future<bool> hasNewVersion() async {
    try {
      // 1. 获取当前应用版本
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. 从App Store获取最新版本信息
      final Map<String, dynamic>? appStoreInfo = await _fetchAppStoreInfo();
      if (appStoreInfo == null) {
        return false;
      }

      final String? latestVersion = appStoreInfo['version'] as String?;
      final int? latestBuildNumber = appStoreInfo['buildNumber'] as int?;

      if (latestVersion == null || latestBuildNumber == null) {
        return false;
      }

      // 3. 比较版本号
      return _compareVersions(currentVersion, latestVersion) < 0 || 
             (currentBuildNumber < latestBuildNumber);
    } catch (e) {
      print('检查App版本更新失败: $e');
      return false;
    }
  }

  /// 获取App Store上的最新版本信息
  static Future<Map<String, dynamic>?> _fetchAppStoreInfo() async {
    try {
      // 使用appstore-sdk-proxy或其他可靠的API获取App Store信息
      // 这里使用一个简化的API作为示例
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/lookup?id=$_appStoreId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('results') && data['results'] is List && data['results'].isNotEmpty) {
          final Map<String, dynamic> appInfo = data['results'][0];
          return {
            'version': appInfo['version'],
            'buildNumber': int.tryParse(appInfo['bundleId']?.split('.').last ?? '0'),
            'releaseNotes': appInfo['releaseNotes'],
            'trackViewUrl': appInfo['trackViewUrl'],
          };
        }
      }
    } catch (e) {
      print('获取App Store信息失败: $e');
    }
    return null;
  }

  /// 比较两个版本号
  static int _compareVersions(String version1, String version2) {
    final List<int> v1 = version1.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final List<int> v2 = version2.split('.').map((part) => int.tryParse(part) ?? 0).toList();

    final int maxLength = v1.length > v2.length ? v1.length : v2.length;
    for (int i = 0; i < maxLength; i++) {
      final int num1 = i < v1.length ? v1[i] : 0;
      final int num2 = i < v2.length ? v2[i] : 0;
      if (num1 > num2) return 1;
      if (num1 < num2) return -1;
    }
    return 0;
  }

  /// 检查是否需要执行版本检查（基于用户设置的检查间隔）
  static Future<bool> shouldCheckForUpdates() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int intervalHours = prefs.getInt(_checkUpdateInterval) ?? _defaultCheckInterval;
    final int lastCheck = prefs.getInt(_lastUpdateCheck) ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // 如果距离上次检查的时间超过了设置的间隔，则执行检查
    if (now - lastCheck > intervalHours * 3600) {
      await prefs.setInt(_lastUpdateCheck, now);
      return true;
    }
    return false;
  }

  /// 显示升级提示对话框
  static Future<void> showUpdateDialog(BuildContext context) async {
    try {
      if (!await shouldCheckForUpdates()) {
        return;
      }

      if (await hasNewVersion()) {
        final Map<String, dynamic>? appInfo = await _fetchAppStoreInfo();
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('发现新版本'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('App Store上有更新的版本可用。'),
                  if (appInfo != null && appInfo.containsKey('releaseNotes'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '更新内容：\n${appInfo['releaseNotes']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('稍后再说'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('立即更新'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // 打开App Store
                    await launchUrlString(_appStoreUrl, 
                        mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('显示更新对话框失败: $e');
    }
  }
}