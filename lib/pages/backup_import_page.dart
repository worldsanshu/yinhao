import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import '../services/backup_service.dart';

class BackupImportPage extends StatefulWidget {
  const BackupImportPage({super.key});
  @override
  State<BackupImportPage> createState() => _BackupImportPageState();
}

class _BackupImportPageState extends State<BackupImportPage> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入备份')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: const Text('从剪贴板粘贴'),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) setState(() { _text.text = data!.text!; });
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('清空'),
                  onPressed: () => setState(() => _text.clear()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _text,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '将导出的 JSON 粘贴在这里（支持单条 or 批量）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_done),
                label: const Text('导入'),
                onPressed: _busy ? null : _importNow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importNow() async {
    setState(() => _busy = true);
    try {
      final box = Hive.box('wallets');
      final n = BackupService.importFromJson(box, _text.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入完成：$n 条')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
