import 'dart:async';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/wallet_entry.dart';
import './usdt_service.dart';
import './tron_client.dart';

class AccountMonitorService {
  // 单例模式
  static final AccountMonitorService _instance = 
      AccountMonitorService._internal();
  factory AccountMonitorService() => _instance;

  AccountMonitorService._internal() {
    print('初始化账户监控服务');
    // 初始化通知插件
    _initializeNotifications();
  }
  
  // 使用真实的通知插件实例
  final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // 初始化通知插件
  Future<void> _initializeNotifications() async {
    try {
      // Android 平台的初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid = 
          AndroidInitializationSettings('app_icon');
      
      // iOS 平台的初始化设置
  final DarwinInitializationSettings initializationSettingsIOS = 
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
      print('iOS 通知接收: $title - $body');
    },
  );

  // macOS 平台的初始化设置
  final DarwinInitializationSettings initializationSettingsMacOS = 
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
      
      // 统一的初始化设置
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
        macOS: initializationSettingsMacOS,
      );
      
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final payload = response.payload;
          if (payload != null && payload.startsWith('wallet:')) {
            print('通知被点击，钱包ID: ${payload.substring(7)}');
            // 保存被点击的钱包ID，供App启动时使用
            final settings = await Hive.openBox('settings');
            await settings.put('last_notification_wallet_id', payload.substring(7));
          }
        },
      );
    } catch (e) {
      print('通知插件初始化失败: $e');
    }
  }

  // 定时器
  Timer? _timer;

  // 上次余额记录
  final Map<String, double> _lastBalances = {};

  // 启动账户监听
  Future<void> startMonitoring() async {
    print('开始监听账户...');

    // 初始化定时器，每20秒检查一次
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      await _checkBalances();
    });

    // 立即检查一次
    await _checkBalances();
  }

  // 停止账户监听
  void stopMonitoring() {
    print('停止监听账户...');
    _timer?.cancel();
  }

  // 检查账户余额变化
  Future<void> _checkBalances() async {
    try {
      // 从Hive获取所有钱包，不关闭box以避免与应用其他部分冲突
      final wallets = <WalletEntry>[];

      // 使用Hive.box而不是打开后再关闭，保持box在应用生命周期内打开
      final box = Hive.box('wallets');

      // 遍历所有钱包并使用WalletEntry.tryFrom解析
      for (final k in box.keys) {
        final e = WalletEntry.tryFrom(box.get(k));
        if (e != null) {
          wallets.add(e);
        }
      }

      for (final wallet in wallets) {
        // 获取当前余额
        final address = wallet.addressBase58;
        // 从设置中获取TRON API Key
        final settings = Hive.box('settings');
        final apiKey = settings.get('trongrid_api_key') as String?;
        final tronClient = TronClient(apiKey: apiKey);
        final usdtService = UsdtService(tronClient);

        // 使用正确的balances方法获取余额
        final balances = await usdtService.balances(address);
        final currentTrx = double.tryParse(balances.$1) ?? 0.0;
        final currentUsdt = double.tryParse(balances.$2) ?? 0.0;

        // 检查TRX余额变化
        if (!_lastBalances.containsKey('$address:trx')) {
          _lastBalances['$address:trx'] = currentTrx;
        } else {
          final lastTrx = _lastBalances['$address:trx'] ?? 0.0;
          if (currentTrx > lastTrx) {
            // TRX余额增加，显示通知
            final amount = currentTrx - lastTrx;
            _showNotification(
              '收到TRX',
              '钱包 ${wallet.name ?? address.substring(0, 8)} 收到 $amount TRX',
              walletId: wallet.id,
            );
          }
          _lastBalances['$address:trx'] = currentTrx;
        }

        // 检查USDT余额变化
        if (!_lastBalances.containsKey('$address:usdt')) {
          _lastBalances['$address:usdt'] = currentUsdt;
        } else {
          final lastUsdt = _lastBalances['$address:usdt'] ?? 0.0;
          if (currentUsdt > lastUsdt) {
            // USDT余额增加，显示通知
            final amount = currentUsdt - lastUsdt;
            _showNotification(
              '收到USDT',
              '钱包 ${wallet.name ?? address.substring(0, 8)} 收到 $amount USDT',
              walletId: wallet.id,
            );
          }
          _lastBalances['$address:usdt'] = currentUsdt;
        }
      }
    } catch (e) {
      print('检查余额时发生错误: $e');
    }
  }

  // 显示通知
  void _showNotification(String title, String message, {String? walletId}) {
    try {
      // Android 平台的通知详情
      const AndroidNotificationDetails androidPlatformChannelSpecifics = 
          AndroidNotificationDetails(
        'account_monitor_channel',
        '账户监控',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        channelDescription: '监控账户余额变化的通知',
        // Android特有的点击行为设置
        setAsGroupSummary: false,
        groupKey: 'account_updates',
        channelShowBadge: true,
      );
      
      // iOS 平台的通知详情
      const DarwinNotificationDetails iOSPlatformChannelSpecifics = 
          DarwinNotificationDetails();
      
      // 统一的通知详情
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      // 准备payload，包含钱包ID
      final payload = walletId != null ? 'wallet:$walletId' : 'account_monitor';
      
      // 发送通知
      _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      // 如果通知发送失败，回退到日志输出
      print('通知: $title - $message (发送失败: $e)');
    }
  }

  // 检查通知权限
  Future<bool> checkNotificationPermission() async {
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        // 统一使用permission_handler检查权限
        return await Permission.notification.isGranted;
      }
    } catch (e) {
      print('检查通知权限失败: $e');
    }
    
    return false;
  }

  // 请求通知权限
  Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        // 统一使用permission_handler请求权限
        return await Permission.notification.request().isGranted;
      }
    } catch (e) {
      print('请求通知权限失败: $e');
    }
    
    return false;
  }
}
