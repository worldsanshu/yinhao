// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/qr_scan_sheet.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _endpoint = TextEditingController();
  final _apiKey = TextEditingController();
  final _energyTo = TextEditingController();
    final _energyTonumber = TextEditingController();
  final _trxDefaultTo = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = Hive.box('settings');
    _endpoint.text = (s.get('tron_endpoint') as String?) ?? 'https://api.trongrid.io';
    _apiKey.text = (s.get('trongrid_api_key') as String?) ?? '';
    // 兼容旧键：energy_target_address
    _energyTo.text = (s.get('energy_purchase_to') as String?) ??
        (s.get('energy_target_address') as String?) ?? '';
    _energyTonumber.text = (s.get('energy_purchase_to_number') as String?) ?? '10';
    _trxDefaultTo.text = (s.get('trx_default_to') as String?) ?? '';
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _apiKey.dispose();
    _energyTo.dispose();
        _energyTonumber.dispose();
    _trxDefaultTo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = Hive.box('settings');
    await s.put('tron_endpoint', _endpoint.text.trim());
    await s.put('trongrid_api_key', _apiKey.text.trim());
    await s.put('energy_purchase_to', _energyTo.text.trim());
     await s.put('energy_purchase_to_number', _energyTonumber.text.trim());
    await s.put('trx_default_to', _trxDefaultTo.text.trim());
    await s.put('trx_default_to', _trxDefaultTo.text.trim());
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('TRON 节点', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: '节点 Endpoint',
              hintText: 'https://api.trongrid.io',
              prefixIcon: Icon(Icons.http),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            decoration: const InputDecoration(
              labelText: 'TRON-PRO-API-KEY（可选）',
              hintText: '如使用 TronGrid Pro，填入 API Key',
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 18),
          Text('固定地址', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _energyTo,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                 labelText: '购买能量固定收款地址（Base58）',
              hintText: '例如：TKSQ...',
                suffixIcon: IconButton(
                  tooltip: '扫码填入',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final raw = await showQrScannerSheet(context);
                    if (raw == null || raw.isEmpty) return;
                    final addr = extractTronBase58(raw) ?? raw;
                    _energyTo.text = addr;
                    setState(() {});
                  },
                ),
            ),





            // decoration: const InputDecoration(
            //   labelText: '购买能量固定收款地址（Base58）',
            //   hintText: '例如：TKSQ...',
            //   prefixIcon: Icon(Icons.bolt),
            // ),
          ),
              const SizedBox(height: 8),
          TextField(
            controller: _energyTonumber,
            decoration: const InputDecoration(
              labelText: '购买能量固定trx数量（整数，单位：trx）',
              hintText: '例如：10...',
              prefixIcon: Icon(Icons.bolt),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _trxDefaultTo,
            decoration: const InputDecoration(
              labelText: '默认 TRX 转账收款地址（Base58，可选）',
              hintText: '例如：TXxx...',
              prefixIcon: Icon(Icons.send),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
