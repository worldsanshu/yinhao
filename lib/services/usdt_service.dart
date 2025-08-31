import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tron_client.dart';

class UsdtService {
  static const defaultUsdtContract = 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8';
  final TronClient client;
  UsdtService(this.client);

  Future<(String trx, String usdt)> balances(String base58) async {
    try {
      final uri = Uri.parse('${client.endpoint}/v1/accounts/$base58');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final j = json.decode(resp.body) as Map<String, dynamic>;
        final data = (j['data'] as List? ?? []);
        if (data.isNotEmpty) {
          final acc = data.first as Map<String, dynamic>;
          final balanceSun = (acc['balance'] ?? 0) as int;
          String usdt = '0';
          final trc20 = (acc['trc20'] as List?) ?? [];
          for (final m in trc20) {
            final map = Map<String, dynamic>.from(m as Map);
            final v = map[defaultUsdtContract] ?? map['USDT'] ?? '0';
            usdt = v.toString();
          }
          return ((balanceSun / 1e6).toStringAsFixed(6), _fmtUsdt(usdt));
        }
      }
    } catch (_) {}
    return ('0.000000', '0.000000');
  }

  String _fmtUsdt(String raw) {
    try {
      final n = double.parse(raw);
      return (n / 1e6).toStringAsFixed(6);
    } catch (_) {
      return '0.000000';
    }
  }
}
