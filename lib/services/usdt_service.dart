import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tron_client.dart';

class UsdtService {
  static const defaultUsdtContract = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
  final TronClient client;
  UsdtService(this.client);

  Future<(String trx, String usdt)> balances(String base58) async {
    try {
      print('开始获取余额: $base58');
      final uri = Uri.parse('${client.endpoint}/v1/accounts/$base58');
      print('请求URL: $uri');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (client.apiKey != null) 'TRON-PRO-API-KEY': client.apiKey!,
      };
      final resp = await http.get(uri, headers: headers);
      print('响应状态码: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final j = json.decode(resp.body) as Map<String, dynamic>;
        print('响应数据: $j');
        final data = (j['data'] as List? ?? []);
        print('数据长度: ${data.length}');
        if (data.isNotEmpty) {
          final acc = data.first as Map<String, dynamic>;
          final balanceSun = (acc['balance'] ?? 0) as int;
          print('TRX余额(sun): $balanceSun');
          double usdt = 0.0;
          final trc20 = (acc['trc20'] as List?) ?? [];
          print('TRC20数量: ${trc20.length}');
          for (final m in trc20) {
            final map = Map<String, dynamic>.from(m as Map);
            // 检查map中是否包含默认USDT合约地址作为键
            if (map.containsKey(defaultUsdtContract)) {
              final balanceStr = map[defaultUsdtContract]?.toString() ?? '0';
              usdt = double.tryParse(balanceStr) ?? 0.0;
              // USDT余额需要除以1e6
              usdt = usdt / 1e6;
              print('USDT余额: $usdt');
              break;
            }
            // 同时检查是否有contract_address字段（兼容旧格式）
            else if (map['contract_address'] == defaultUsdtContract) {
              usdt = double.tryParse(map['balance']?.toString() ?? '0') ?? 0.0;
              print('USDT余额: $usdt');
              break;
            }
          }
          // TRX余额（从sun转换为trx）
          final trx = balanceSun / 1e6;
          // USDT余额（已经是正确格式，无需再除以1e6）
          print('返回TRX: ${trx.toStringAsFixed(2)}, USDT: ${usdt.toStringAsFixed(2)}');
          return (trx.toStringAsFixed(2), usdt.toStringAsFixed(2));
        } else {
          print('数据为空');
        }
      } else {
        print('请求失败，状态码: ${resp.statusCode}');
        print('响应体: ${resp.body}');
      }
    } catch (e) {
      print('获取余额异常: $e');
    }
    print('返回默认值: 0.000000, 0.000000');
    return ('0.00', '0.00');
  }

  // 移除了不再使用的_fmtUsdt函数
}