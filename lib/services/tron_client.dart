import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:convert/convert.dart' as conv;

class TronClient {
  final String endpoint;
  TronClient({this.endpoint = 'https://api.trongrid.io'});

  String normalizeToBase58(String input) {
    final s = input.trim();
    if (s.startsWith('T')) return s;
    if (s.startsWith('41') || s.startsWith('0x41')) {
      // 占位：返回 'T-' + hex 以便编译运行；需要真正 Base58 时可替换为 bs58check.encode
      final hex = s.startsWith('0x') ? s.substring(2) : s;
      return 'T-' + hex.toLowerCase();
    }
    throw ArgumentError('无法识别的地址格式: $input');
  }

  Future<List<Map<String, dynamic>>> recentUsdtTransfers(String base58, {int limit = 10}) async {
    try {
      final uri = Uri.parse('$endpoint/v1/accounts/$base58/transactions/trc20?only_confirmed=true&limit=$limit');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final j = json.decode(resp.body) as Map<String, dynamic>;
        final data = (j['data'] as List? ?? []);
        return data.cast<Map<String, dynamic>>().map((e) {
          return {
            'from': e['from'] ?? '',
            'to': e['to'] ?? '',
            'value': e['value'] ?? '',
            'type': (e['type'] ?? 'transfer').toString(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> buildTrxTransfer({
    required String fromBase58,
    required String toBase58,
    required BigInt amountSun,
  }) async {
    // 占位：返回可签名的结构
    final raw = {
      'type': 'TransferContract',
      'owner_address': fromBase58,
      'to_address': toBase58,
      'amount': amountSun.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final txid = _sha256Hex(utf8.encode(json.encode(raw)));
    return {'raw_data': raw, 'txID': txid};
  }

  Future<Map<String, dynamic>> buildTrc20Transfer({
    required String fromBase58,
    required String toBase58,
    required BigInt amount,
    required String contractBase58,
  }) async {
    // 占位：返回可签名的结构
    final raw = {
      'type': 'TriggerSmartContract',
      'owner_address': fromBase58,
      'contract_address': contractBase58,
      'to': toBase58,
      'function': 'transfer(address,uint256)',
      'amount': amount.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final txid = _sha256Hex(utf8.encode(json.encode(raw)));
    return {'raw_data': raw, 'txID': txid};
  }

  Future<Map<String, dynamic>> signTransaction(Map<String, dynamic> tx, Uint8List privateKey) async {
    // 占位：不做真实签名，仅附加一个模拟签名字段以便流程打通
    final txid = (tx['txID'] as String?) ?? _sha256Hex(utf8.encode(json.encode(tx['raw_data'] ?? {})));
    final fakeSig = List.filled(65, 1).map((e) => '01').join();
    final signed = Map<String, dynamic>.from(tx);
    signed['signature'] = [fakeSig];
    signed['txID'] = txid;
    return signed;
  }

  Future<String> broadcastTransaction(Map<String, dynamic> signed) async {
    // 占位：直接返回 txID，模拟已广播
    return (signed['txID'] as String?) ?? _sha256Hex(utf8.encode(json.encode(signed)));
  }

  String _sha256Hex(List<int> bytes) {
    // 轻量实现：使用 dart:convert + crypto? 这里避免新依赖，直接调用 sha256 伪实现
    // 真正哈希建议使用 package:crypto；但本方法仅用于“占位”生成 txID。
    int sum = 0;
    for (final b in bytes) { sum = (sum + b) & 0xffffffff; }
    final r = Uint8List(32);
    for (int i=0;i<32;i++) { r[i] = (sum + i * 13) & 0xff; }
    return conv.hex.encode(r);
  }
}
