// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/qr_scan_sheet.dart';
import '../widgets/backup_email_section.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 你的原有控制器（保持命名不变）
  final _endpoint = TextEditingController();          // TRON 节点 HTTP/RPC
  final _apiKey = TextEditingController();            // trongas.io API Key
  final _energyTo = TextEditingController();          // 购能目标地址（可选）
  final _energyTonumber = TextEditingController();    // 购买能量数量( payNums )
  final _trxDefaultTo = TextEditingController();
  // 新增：备份收件邮箱（可选）
  final _backupEmail = TextEditingController();
 final _smtpHost = TextEditingController();
 final _smtpPort = TextEditingController();
  final _smtpUser = TextEditingController();
   final _smtpPass = TextEditingController();

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
   // 新增：备份邮箱
    _backupEmail.text     = (s.get('backup_email') as String?) ?? '';
    // 新增：SMTP 设置
    _smtpHost.text     = (s.get('smtpHost') as String?) ?? '';
    //发件服务器端口，默认587
    _smtpPort.text     =(s.get('smtpPort')as int?)?.toString() ?? '587';
    //发件邮箱用户名
    _smtpUser.text     = (s.get('smtpUser') as String?) ?? '';
    //发件邮箱密码（应用专用密码）
    _smtpPass.text     = (s.get('smtpPass') as String?) ?? '';
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _apiKey.dispose();
    _energyTo.dispose();
        _energyTonumber.dispose();
    _trxDefaultTo.dispose();
        _backupEmail.dispose();
   
                _smtpHost.dispose();
                    _smtpPort.dispose();
                        _smtpUser.dispose();
                            _smtpPass.dispose();
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
        // 新增：备份邮箱
    await s.put('backup_email', _backupEmail.text.trim());
        // 新增：SMTP 设置
    await s.put('smtpHost', _smtpHost.text.trim());
    await s.put('smtpPort', int.tryParse(_smtpPort.text.trim()) ?? 587);
    await s.put('smtpUser', _smtpUser.text.trim());
    await s.put('smtpPass', _smtpPass.text.trim());
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
                   border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.http),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            decoration: const InputDecoration(
              labelText: 'TRON-PRO-API-KEY（可选）',
              hintText: '如使用 TronGrid Pro，填入 API Key',
                   border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 18),
         
          Text('购买能量固定地址', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _energyTo,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                 labelText: '购买能量固定收款地址（Base58）',
              hintText: '例如：TKSQ...',
                   border: OutlineInputBorder(),
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
                   border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.bolt),
            ),
          ),
          const SizedBox(height: 12),
        //   TextField(
        //     controller: _trxDefaultTo,
        //     decoration: const InputDecoration(
        //       labelText: '默认 TRX 转账收款地址（Base58，可选）',
        //       hintText: '例如：TXxx...',
        //            border: OutlineInputBorder(),
        //       prefixIcon: Icon(Icons.send),
        //     ),
        //   ),
        //  const SizedBox(height: 18),
           //  const BackupEmailSection(),
                    // ----------------- 邮箱备份 -----------------
          const SizedBox(height: 24),
          Text('邮箱备份/邮件服务器', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _backupEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '备份收件邮箱（可选）',
              hintText: '例如：yourname@gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
              Text('设置后创建钱包会自动发送加密后的备份，在别的设备上可用密码解密恢复', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w200)),



     const SizedBox(height: 8),





            TextField(
            controller: _smtpHost,
        
            decoration: const InputDecoration(
              labelText: '发件服务器 SMTP 设置（可选）',
              hintText: '例如：smtp.gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),     const SizedBox(height: 8),
           TextField(
            controller: _smtpPort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '发件服务器端口（可选）',
              hintText: '例如：587',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),     const SizedBox(height: 8),
            TextField(
            controller: _smtpUser,
     
            decoration: const InputDecoration(
              labelText: '发件邮箱用户名（可选）',
              hintText: '例如：yourname@gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),     const SizedBox(height: 8),
            TextField(
            controller: _smtpPass,
            keyboardType: TextInputType.visiblePassword,
            decoration: const InputDecoration(
              labelText: '发件邮箱密码（应用专用密码）（可选）',
              hintText: '例如：yourname@gmail.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
         Text('不了解的可以自行百度搜索“qq邮箱/163邮箱SMTP配置”', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w200)),



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
