
// lib/widgets/backup_email_section.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BackupEmailSection extends StatefulWidget {
  const BackupEmailSection({super.key});

  @override
  State<BackupEmailSection> createState() => _BackupEmailSectionState();
}

class _BackupEmailSectionState extends State<BackupEmailSection> {
  final _backupEmail = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = Hive.isBoxOpen('settings') ? Hive.box('settings') : await Hive.openBox('settings');
    _backupEmail.text = (box.get('backup_email') as String?) ?? '';
    setState(() {});
  }

  Future<void> _save() async {
    final box = Hive.isBoxOpen('settings') ? Hive.box('settings') : await Hive.openBox('settings');
    await box.put('backup_email', _backupEmail.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份邮箱已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('邮箱备份', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _backupEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: '备份收件邮箱（可选）',
            hintText: '例如: yourname@gmail.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('保存邮箱'),
          ),
        ),
      ],
    );
  }
}
