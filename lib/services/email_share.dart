// lib/services/email_share.dart
import 'dart:async';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmailShare {
  // static const String _smtpHost = 'smtp.gmail.com';
  // static const int _smtpPort = 587; // STARTTLS
  // static const String _smtpUser = 'lastlifxxxxips@gmail.com';
  // static const String _smtpPass = 'psfcxxxxxxnphuvyoz'; // 应用专用密码

  /// 发送钱包备份（JSON 附件）
  static Future<void> sendWalletBackup({
    required String to,
    required String subject,
    required String textBody,
    required String filename,
    required List<int> data,
  }) async {
        final settingsBox = Hive.isBoxOpen('settings') ? Hive.box('settings') : await Hive.openBox('settings');
       final String? toEmail = (settingsBox.get('backup_email') as String?)?.trim();
        final String? _smtpHost = (settingsBox.get('smtpHost') as String?)?.trim();
        final int _smtpPort = settingsBox.get('smtpPort') as int? ?? 587;
        final String _smtpUser = (settingsBox.get('smtpUser') as String).trim();
        final String? _smtpPass =  (settingsBox.get('smtpPass') as String?)?.trim();
        final message = Message()
          ..from = Address(_smtpUser, 'USDT Vault')
          ..recipients.add(to)
          ..subject = subject
          ..text = textBody
          ..attachments = [
            // mailer 6.5.0 的 StreamAttachment 签名：StreamAttachment(Stream, String contentType, {String? fileName})
            StreamAttachment(
              Stream<List<int>>.fromIterable([data]),
              'application/json',
              fileName: filename,
            ),
          ];
         debugPrint('准备验证发邮箱');
     
          debugPrint('toEmail:$toEmail');
          debugPrint('_smtpHost：$_smtpHost');
          debugPrint('_smtpPort：$_smtpPort');
          debugPrint('_smtpUser：$_smtpUser');
          debugPrint('_smtpPass：$_smtpPass');
          debugPrint('准备发送邮件');
    if (toEmail != null && toEmail.isNotEmpty && _smtpHost != null && _smtpHost.isNotEmpty &&_smtpUser!=null&&_smtpUser.isNotEmpty&&_smtpPass!=null&&_smtpPass.isNotEmpty&&_smtpPort>0) {
      final server = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUser,
        password: _smtpPass,
        ssl: false, // 使用 STARTTLS
      );

      await send(message, server);
    }
          debugPrint('发送完毕');
  }
}
