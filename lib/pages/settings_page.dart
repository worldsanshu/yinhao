import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _endpoint = TextEditingController(text: 'https://api.trongrid.io');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _endpoint, decoration: const InputDecoration(labelText: 'TRON 节点 Endpoint')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () {}, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}
