import 'package:share_plus/share_plus.dart';

class EmailShare {
  static Future<void> compose({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    final text = 'mailto:$toEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    await Share.share(text);
  }
}
