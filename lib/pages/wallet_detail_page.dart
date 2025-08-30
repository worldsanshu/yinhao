import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/wallet_entry.dart';
import '../services/tron_client.dart';
import '../services/usdt_service.dart';
import 'transfer_page.dart';

class WalletDetailPage extends StatefulWidget {
  final String walletId;
  const WalletDetailPage({super.key, required this.walletId});

  @override
  State<WalletDetailPage> createState() => _WalletDetailPageState();
}

class _WalletDetailPageState extends State<WalletDetailPage> {
  WalletEntry? _entry;
  String _trx = '--';
  String _usdt = '--';
  final _client = TronClient(endpoint: 'https://api.trongrid.io');
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    final box = Hive.box<WalletEntry>('wallets');
    _entry = box.get(widget.walletId);
    _refresh();
  }

  Future<void> _refresh() async {
    if (_entry == null) return;
    final s = UsdtService(_client);
    final (trx, usdt) = await s.balances(_entry!.addressBase58);
    final txs =
        await _client.recentUsdtTransfers(_entry!.addressBase58, limit: 10);
    if (!mounted) return;
    setState(() {
      _trx = trx;
      _usdt = usdt;
      _recent = txs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    if (e == null) {
      return const Scaffold(body: Center(child: Text('未找到钱包')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('钱包详情'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showQrOverlay(e.addressBase58)),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: e.addressBase58));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制地址')));
              }
            },
          ),
          IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () async {
                await Share.share(e.exportJson());
              }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('地址: ${e.addressBase58}',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metric('TRX', _trx)),
                const SizedBox(width: 12),
                Expanded(child: _metric('USDT', _usdt)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('转账 USDT'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransferPage(
                          walletId: e.id,
                          initialAsset: AssetType.usdt,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on),
                    label: const Text('转账 TRX'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransferPage(
                          walletId: e.id,
                          initialAsset: AssetType.trx,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('最近交易（TRC20）',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: _recent.isEmpty
                  ? const Center(child: Text('暂无数据'))
                  : ListView.separated(
                      itemCount: _recent.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.2),
                      itemBuilder: (_, i) {
                        final t = _recent[i];
                        final to = t['to'] ?? '';
                        final from = t['from'] ?? '';
                        final value = t['value']?.toString() ?? '';
                        final type = t['type'] ?? '';
                        return ListTile(
                          dense: true,
                          title: Text('$type $value'),
                          subtitle: Text('from: $from -> to: $to',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQrOverlay(String address) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'address-qr',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, a1, a2) {
        final size = MediaQuery.of(ctx).size;
        final side = (size.shortestSide * 0.82).clamp(240.0, 420.0);
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: side + 32,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('地址二维码',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: side,
                      height: side,
                      child: Center(
                        child: FittedBox(
                          child: QrImageView(data: address, size: side),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(address,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metric(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}