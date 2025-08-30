import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' as ethcrypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:bs58check/bs58check.dart' as bs58check;

class TronClient {
  final String endpoint; // e.g. https://api.trongrid.io
  TronClient({required this.endpoint});

  Future<BigInt> getTrxBalance(String base58Address) async {
    final res = await http.post(
      Uri.parse('$endpoint/wallet/getaccount'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': base58Address, 'visible': true}),
    );
    if (res.statusCode != 200) throw Exception('getaccount failed: ${res.body}');
    final j = jsonDecode(res.body);
    final balance = BigInt.from((j['balance'] ?? 0) as int);
    return balance;
  }

  Future<BigInt> getTokenBalance(String base58Address, String tokenContractBase58) async {
    final data = '70a08231' + ('0' * 24) + _hexAddrFromBase58(base58Address);
    final res = await http.post(
      Uri.parse('$endpoint/wallet/triggerconstantcontract'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': base58Address,
        'contract_address': tokenContractBase58,
        'function_selector': 'balanceOf(address)',
        'parameter': data,
        'visible': true
      }),
    );
    if (res.statusCode != 200) throw Exception('triggerconstant failed: ${res.body}');
    final j = jsonDecode(res.body);
    final hexStr = j['constant_result']?[0] ?? '0x0';
    final bi = BigInt.parse(hexStr.replaceFirst('0x', ''), radix: 16);
    return bi;
  }

Future<Map<String, dynamic>> buildTrxTransfer({
  required String fromBase58,
  required String toBase58,
  required BigInt amountSun,
}) async {
  final res = await http.post(
    Uri.parse('\$endpoint/wallet/createtransaction'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'owner_address': fromBase58,
      'to_address': toBase58,
      'amount': amountSun.toInt(), // API expects int
      'visible': true,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('createtransaction failed: \${res.body}');
  }
  final j = jsonDecode(res.body);
  if (j['raw_data'] == null) {
    throw Exception('No transaction returned: \${res.body}');
  }
  return j;
}

Future<Map<String, dynamic>> buildTrc20Transfer({

    required String fromBase58,
    required String toBase58,
    required BigInt amount, // usdt: 6 decimals
    required String contractBase58,
  }) async {
    final selector = 'a9059cbb';
    final param = selector + ('0' * 24) + _hexAddrFromBase58(toBase58) + amount.toRadixString(16).padLeft(64, '0');
    final res = await http.post(
      Uri.parse('$endpoint/wallet/triggersmartcontract'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': fromBase58,
        'contract_address': contractBase58,
        'function_selector': 'transfer(address,uint256)',
        'parameter': param,
        'visible': true,
        'fee_limit': 10000000
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('triggersmartcontract failed: ${res.body}');
    }
    final j = jsonDecode(res.body);
    if (j['transaction'] == null) {
      throw Exception('No transaction returned: ${res.body}');
    }
    return j['transaction'];
  }

  Future<Map<String, dynamic>> signTransaction(Map<String, dynamic> tx, Uint8List privateKey) async {
    final rawData = utf8.encode(jsonEncode(tx['raw_data']));
    final txId = crypto.sha256.convert(Uint8List.fromList(rawData)).bytes;
    final sig = _signSecp256k1(Uint8List.fromList(txId), privateKey);
    final signed = Map<String, dynamic>.from(tx);
    signed['signature'] = [ethcrypto.bytesToHex(sig, include0x: false)];
    return signed;
  }

  Future<String> broadcastTransaction(Map<String, dynamic> signedTx) async {
    final res = await http.post(
      Uri.parse('$endpoint/wallet/broadcasttransaction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(signedTx),
    );
    if (res.statusCode != 200) throw Exception('broadcast failed: ${res.body}');
    final j = jsonDecode(res.body);
    if (j['result'] == true && j['txid'] != null) {
      return j['txid'];
    }
    throw Exception('Broadcast error: ${res.body}');
  }

  // Recent TRC20 transfers (best-effort, TronGrid v1 style)
  Future<List<Map<String, dynamic>>> recentUsdtTransfers(String addressBase58, {int limit = 10, String? contract}) async {
    final c = contract ?? 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj';
    final url = Uri.parse('$endpoint/v1/accounts/$addressBase58/transactions/trc20?limit=$limit&contract_address=$c');
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final j = jsonDecode(res.body);
    final data = (j['data'] as List?) ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  // Helpers
String normalizeToBase58(String input) {
  final s = input.trim();
  if (s.isEmpty) throw Exception('空地址');
  // Case 1: Base58 (T开头)
  if (s.startsWith('T')) {
    // try decode to verify
    final _ = bs58check.base58.decode(s);
    return s;
  }
  // Case 2: 0x41... or 41...
  var hex = s.toLowerCase();
  if (hex.startsWith('0x')) hex = hex.substring(2);
  if (hex.startsWith('41') && hex.length == 42) {
    return base58FromHex41(hex);
  }
  throw Exception('请输入 TRON 地址：T开头(Base58) 或 0x41... 十六进制');
}

String base58FromHex41(String hex41) {
  final clean = hex41.toLowerCase().startsWith('0x') ? hex41.substring(2) : hex41;
  if (!clean.startsWith('41') || clean.length != 42) {
    throw Exception('hex41 格式不正确');
  }
  final bytes = List<int>.generate(21, (i) => 0);
  bytes[0] = 0x41;
  for (int i = 0; i < 20; i++) {
    final byteHex = clean.substring(2 + i*2, 2 + i*2 + 2);
    bytes[1+i] = int.parse(byteHex, radix: 16);
  }
  final firstSha = crypto.sha256.convert(Uint8List.fromList(bytes)).bytes;
  final secondSha = crypto.sha256.convert(firstSha).bytes;
  final check4 = secondSha.sublist(0,4);
  final full = Uint8List.fromList([...bytes, ...check4]);
  return bs58check.base58.encode(full);
}

  String _hexAddrFromBase58(String base58) {
    final decoded = bs58check.base58.decode(base58);
    if (decoded.length < 25 || decoded[0] != 0x41) {
      throw Exception('Invalid TRON base58 address');
    }
    final addr20 = decoded.sublist(1, 21); // skip 0x41 prefix
    return addr20.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List _signSecp256k1(Uint8List hash32, Uint8List privateKey) {
    final params = pc.ECDomainParameters('secp256k1');
    final privNum = BigInt.parse(ethcrypto.bytesToHex(privateKey, include0x: false), radix: 16);
    final priv = pc.ECPrivateKey(privNum, params);
    final signer = pc.Signer('SHA-256/DET-ECDSA');
    signer.init(true, pc.ParametersWithRandom(pc.PrivateKeyParameter<pc.ECPrivateKey>(priv), pc.SecureRandom()));
    final sig = signer.generateSignature(hash32) as pc.ECSignature;
    var s = sig.s;
    final nOver2 = (params.n! >> 1);
    if (s > nOver2) s = params.n! - s;
    final rBytes = _bigIntToBytes(sig.r, 32);
    final sBytes = _bigIntToBytes(s, 32);
    return Uint8List.fromList([...rBytes, ...sBytes]);
  }

  Uint8List _bigIntToBytes(BigInt bi, int length) {
    final hex = bi.toRadixString(16).padLeft(length * 2, '0');
    return ethcrypto.hexToBytes(hex);
  }
}
