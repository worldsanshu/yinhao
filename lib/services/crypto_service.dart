// lib/services/crypto_service.dart
// 合并 & 兼容修复版（加强口令校验，禁止“错三密也能继续”）
// 兼容旧页面调用：
//  - CryptoService.generatePrivateKey32()
//  - CryptoService.encryptPrivateKeyWithThreePasswords(privateKey32: pk, pass1: p1, pass2: p2, pass3: p3, iterations: n)
//    ^ 同时支持新命名（pk/p1/p2/p3/pbkdf2Iterations）。返回 EncryptedPrivateKey，
//      支持 enc['...'] 下标读取，并兼容 'ciphertextB64' 别名。
//  - CryptoService.deriveTronAddress(pk) // 同步返回 (addrB58, addrHex41)
//  - TransferService.sendTrx / sendUsdt // 真实链上广播
//
// 强化点（本次更新）：
//  1) 解密后地址校验：必须至少提供 addressHex 或 addressBase58 之一且匹配，否则视为口令错误直接抛错。
//  2) 广播前二次校验：由私钥推导出的地址必须与 fromBase58 一致，否则抛错（防止误签名）。
//  3) 提供 CryptoService.verifyPasswords(entry, p1, p2, p3) 便于表单先验校验。
//
// 依赖（pubspec.yaml）：
//   http: ^1.2.2
//   cryptography: ^2.7.0
//   pointycastle: ^3.8.1
//   web3dart: ^2.7.2
//   bs58check: ^1.0.2
//   convert: ^3.1.1

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart' as cg;
import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/keccak.dart';
import 'package:web3dart/crypto.dart' as w3c;
import 'package:hive_flutter/hive_flutter.dart';

class CryptoService {
  static final _rnd = Random.secure();

  // --- 你原有的 API：生成 32 字节私钥 ---
  static Uint8List generatePrivateKey32() {
    final sk = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      sk[i] = _rnd.nextInt(256);
    }
    if (sk.every((b) => b == 0)) sk[0] = 1; // 避免全零
    return sk;
  }

  // --- 三口令加密（兼容旧参数名） ---
  static Future<EncryptedPrivateKey> encryptPrivateKeyWithThreePasswords({
    Uint8List? pk,
    Uint8List? privateKey32, // 旧参数名
    String? p1,
    String? pass1, // 旧参数名
    String? p2,
    String? pass2, // 旧参数名
    String? p3,
    String? pass3, // 旧参数名
    int? pbkdf2Iterations,
    int? iterations, // 旧参数名
    _AeadSpec aead = _AeadSpec.aesGcm,
  }) async {
    final Uint8List realPk = pk ?? privateKey32!;
    final String realP1 = p1 ?? pass1!;
    final String realP2 = p2 ?? pass2!;
    final String realP3 = p3 ?? pass3!;
    final int realIters = pbkdf2Iterations ?? iterations ?? 150000;

    // 生成随机盐/随机 nonce
    final salt1 = _randBytes(16);
    final salt2 = _randBytes(16);
    final salt3 = _randBytes(16);
    final masterSalt = _randBytes(32);
    final nonce = _randBytes(12); // AES-GCM 12 字节

    final k1 = await _derive(realP1, salt1, realIters);
    final k2 = await _derive(realP2, salt2, realIters);
    final k3 = await _derive(realP3, salt3, realIters);

    // 组合方案：与解密候选其中一种一致（HMAC(masterSalt, xor3(k1,k2,k3))）
    final mk = await _hmac(masterSalt, _xor3(k1, k2, k3));

    final enc = await _aeadEncrypt(realPk, mk, nonce, aead);

    return EncryptedPrivateKey(
      encPrivateKeyB64: base64.encode(enc),
      nonceB64: base64.encode(nonce),
      salt1B64: base64.encode(salt1),
      salt2B64: base64.encode(salt2),
      salt3B64: base64.encode(salt3),
      masterSaltB64: base64.encode(masterSalt),
      pbkdf2Iterations: realIters,
    );
  }

  // --- 三口令解密（兼容旧数据：多组合 + 多 AEAD 侦测） ---
  static Future<Uint8List> decryptPrivateKeyWithThreePasswords(
    dynamic entry,
    String p1,
    String p2,
    String p3,
  ) async {
    final enc = base64.decode(entry.encPrivateKeyB64);
    final nonce = base64.decode(entry.nonceB64); // 12 或 16 字节
    final salt1 = base64.decode(entry.salt1B64);
    final salt2 = base64.decode(entry.salt2B64);
    final salt3 = base64.decode(entry.salt3B64);
    final masterSalt = base64.decode(entry.masterSaltB64);
    final iters = (entry.pbkdf2Iterations is int && entry.pbkdf2Iterations > 0)
        ? entry.pbkdf2Iterations
        : 150000;

    final k1 = await _derive(p1, salt1, iters);
    final k2 = await _derive(p2, salt2, iters);
    final k3 = await _derive(p3, salt3, iters);

    // 预生成可能的主密钥
    final mk1 = await _hmac(masterSalt, _xor3(k1, k2, k3));
    final mk2 = await _hmac(masterSalt, _xor3(k1, k3, k2));
    final mk3 = await _hmac(masterSalt, _concat([k1, k2, k3]));
    final mk4 = await _hmac(masterSalt, _concat([k1, k3, k2]));

    final mkCandidates = <Uint8List>[mk1, mk2, mk3, mk4];
    final aeadCandidates = <_AeadSpec>[
      _AeadSpec.aesGcm,
      _AeadSpec.chacha20poly1305
    ];

    for (final mk in mkCandidates) {
      for (final algo in aeadCandidates) {
        try {
          final pt = await _aeadDecrypt(enc, mk, nonce, algo);
          if (pt.length == 32) {
            // —— 强校验：必须至少提供一个地址并匹配 ——
            final ok = TronAddressUtils.privateKeyMatchesAddresses(
              pt,
              addressHex: entry.addressHex,
              addressBase58: entry.addressBase58,
              requireAtLeastOne: true,
            );
            if (!ok) continue; // 不匹配继续尝试其它组合
            return pt;
          }
        } catch (_) {/*继续尝试*/}
      }
    }
    throw Exception('口令错误或数据不匹配');
  }

  /// 供表单预检：仅做口令正确性验证（不会返回私钥内容）
  static Future<bool> verifyPasswords(
    dynamic entry,
    String p1,
    String p2,
    String p3,
  ) async {
    try {
      await decryptPrivateKeyWithThreePasswords(entry, p1, p2, p3);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- 同步：地址推导（与你页面的 (addrB58, addrHex) 解构匹配） ---
  static (String, String) deriveTronAddress(Uint8List priv) {
    final (hex41, b58) = TronAddressUtils.deriveAddresses(priv);
    return (b58, hex41);
  }

  // --- 工具：PBKDF2(HMAC-SHA256) / HMAC / 拼接 / XOR ---
  static Future<Uint8List> _derive(
      String pass, List<int> salt, int iters) async {
    final key = await cg.Pbkdf2(
      macAlgorithm: cg.Hmac.sha256(),
      iterations: iters,
      bits: 256,
    ).deriveKey(
      secretKey: cg.SecretKey(utf8.encode(pass)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  static Future<Uint8List> _hmac(List<int> salt, Uint8List key) async {
    final mac = await cg.Hmac.sha256().calculateMac(
      salt,
      secretKey: cg.SecretKey(key),
    );
    return Uint8List.fromList(mac.bytes);
  }

  static Uint8List _xor3(Uint8List a, Uint8List b, Uint8List c) {
    final out = Uint8List(a.length);
    for (var i = 0; i < a.length; i++) {
      out[i] = a[i] ^ b[i] ^ c[i];
    }
    return out;
  }

  static Uint8List _concat(List<Uint8List> parts) {
    final total = parts.fold<int>(0, (p, e) => p + e.length);
    final out = Uint8List(total);
    var o = 0;
    for (final p in parts) {
      out.setAll(o, p);
      o += p.length;
    }
    return out;
  }

  static Uint8List _randBytes(int n) {
    final b = Uint8List(n);
    for (int i = 0; i < n; i++) b[i] = _rnd.nextInt(256);
    return b;
  }
}

// =============== TRON 地址/签名/广播（同步地址工具） ===============

class TronAddressUtils {
  /// 通过私钥推导 addressHex(41...) 与 Base58（同步）
  static (String hex41, String base58) deriveAddresses(Uint8List priv) {
    final pub = w3c.privateKeyBytesToPublic(priv); // 64 bytes (x||y)

    final keccak = KeccakDigest(256);
    final hash = Uint8List(32);
    keccak.update(pub, 0, pub.length);
    keccak.doFinal(hash, 0);

    final addr20 = hash.sublist(12); // 取后 20 字节
    final addr21 = Uint8List(addr20.length + 1)
      ..[0] = 0x41
      ..setAll(1, addr20);

    final hex41 = '41' + convert.hex.encode(addr20).toUpperCase();
    final base58 = bs58check.encode(addr21);
    return (hex41, base58);
  }

  /// 校验私钥是否匹配给定地址（同步）
  static bool privateKeyMatchesAddresses(
    Uint8List priv, {
    String? addressHex,
    String? addressBase58,
    bool requireAtLeastOne = true,
  }) {
    final (hex41, b58) = deriveAddresses(priv);
    bool had = false;
    bool ok = true;
    if (addressHex != null && addressHex.isNotEmpty) {
      had = true;
      ok &= _eqIgnoreCase(hex41, addressHex);
    }
    if (addressBase58 != null && addressBase58.isNotEmpty) {
      had = true;
      ok &= (b58 == addressBase58);
    }
    return requireAtLeastOne ? (had && ok) : ok;
  }

  static String base58ToHex41(String base58) {
    final payload = bs58check.decode(base58); // 21 字节，首字节应为 0x41
    if (payload.isEmpty || payload[0] != 0x41) {
      throw ArgumentError('非法 Tron Base58 地址');
    }
    return '41' + convert.hex.encode(payload.sublist(1)).toUpperCase();
  }

  static bool _eqIgnoreCase(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();
}

class TransferService {
  final String nodeUrl; // 例：https://api.trongrid.io 或自建 8090
  final String? tronProApiKey; // TronGrid 可选

  final http.Client _client;

  TransferService({
    required this.nodeUrl,
    this.tronProApiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (tronProApiKey != null && tronProApiKey!.isNotEmpty)
          'TRON-PRO-API-KEY': tronProApiKey!,
      };

  /// 发送 TRX（1 TRX = 1e6 sun）
  Future<String> sendTrx({
    required String fromBase58,
    required String toBase58,
    required BigInt sunAmount,
    required Uint8List privateKey,
  }) async {
    // —— 二次校验：私钥→地址 必须与 fromBase58 一致 ——
    final (_, b58FromPriv) = TronAddressUtils.deriveAddresses(privateKey);
    if (b58FromPriv != fromBase58) {
      throw Exception('口令错误或非该地址私钥');
    }

    final fromHex41 = TronAddressUtils.base58ToHex41(fromBase58);
    final toHex41 = TronAddressUtils.base58ToHex41(toBase58);

    final tx = await _postJson('/wallet/createtransaction', {
      'owner_address': fromHex41,
      'to_address': toHex41,
      'amount': sunAmount.toInt(),
      'visible': false,
    });

    final signed = await _signTransaction(tx, privateKey);
    final b = await _postJson('/wallet/broadcasttransaction', signed);
    final txId = _extractTxId(b);
    if (txId == null) {
      throw Exception('广播失败: ${jsonEncode(b)}');
    }
    return txId;
  }

  /// 发送 USDT（TRC20）
  Future<String> sendUsdt({
    required String fromBase58,
    required String toBase58,
    required BigInt usdt6, // amount * 1e6
    required Uint8List privateKey,
    required String contractBase58,
    int feeLimit = 100000000, // 100 TRX 上限
  }) async {
    // —— 二次校验：私钥→地址 必须与 fromBase58 一致 ——
    final (_, b58FromPriv) = TronAddressUtils.deriveAddresses(privateKey);
    if (b58FromPriv != fromBase58) {
      throw Exception('口令错误或非该地址私钥');
    }

    final fromHex41 = TronAddressUtils.base58ToHex41(fromBase58);
    final toHex41 = TronAddressUtils.base58ToHex41(toBase58);
    final contractHex41 = TronAddressUtils.base58ToHex41(contractBase58);

    final paramsHex = _encodeTransferParams(toHex41, usdt6);

    final r = await _postJson('/wallet/triggersmartcontract', {
      'owner_address': fromHex41,
      'contract_address': contractHex41,
      'function_selector': 'transfer(address,uint256)',
      'parameter': paramsHex,
      'fee_limit': feeLimit,
      'call_value': 0,
      'visible': false,
    });

    final tx = (r is Map && r['transaction'] != null) ? r['transaction'] : r;

    final signed = await _signTransaction(tx, privateKey);
    final b = await _postJson('/wallet/broadcasttransaction', signed);
    final txId = _extractTxId(b);
    if (txId == null) {
      throw Exception('广播失败: ${jsonEncode(b)}');
    }
    return txId;
  }

  // ---- 内部工具 ----

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_join(nodeUrl, path));
    final res =
        await _client.post(uri, headers: _headers, body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final obj = jsonDecode(res.body);
    if (obj is Map<String, dynamic>) return obj;
    return {'_': obj};
  }

  static String _join(String base, String path) {
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (!path.startsWith('/')) path = '/$path';
    return '$base$path';
  }

  Future<Map<String, dynamic>> _signTransaction(
    Map<String, dynamic> tx,
    Uint8List privateKey,
  ) async {
    final rawHex =
        (tx['raw_data_hex'] ?? tx['raw_data']?.toString()) as String?;
    if (rawHex == null) throw Exception('交易原文缺失 (raw_data_hex)');

    final rawBytes = _hexToBytes(rawHex);

    // Tron 对 raw_data 做 sha256 后再 secp256k1 签名
    final digest = await _sha256(rawBytes);

    // 使用 web3dart 的 sign 获取 r/s/v
    final sig = await w3c.sign(digest, privateKey);
    final r = _bigIntToFixed(sig.r, 32);
    final s = _bigIntToFixed(sig.s, 32);
    final v = Uint8List(1)..[0] = (sig.v >= 27 ? sig.v - 27 : sig.v);
    final sig65 = Uint8List.fromList([...r, ...s, ...v]);

    final signed = Map<String, dynamic>.from(tx);
    final prev = <dynamic>[];
    if (signed['signature'] is List) prev.addAll(signed['signature']);
    prev.add(_bytesToHex(sig65));
    signed['signature'] = prev;
    return signed;
  }

  static Future<Uint8List> _sha256(Uint8List data) async {
    final h = await cg.Sha256().hash(data);
    return Uint8List.fromList(h.bytes);
  }

  static String _encodeTransferParams(String toHex41, BigInt amount) {
    // ABI：address=去掉41前缀后的20字节，左填充到32字节；uint256 也左填充
    final addr20 = toHex41.substring(2);
    final addrPad = addr20.padLeft(64, '0');
    final amtPad = amount.toRadixString(16).padLeft(64, '0');
    return addrPad + amtPad;
  }

  static String? _extractTxId(Map<String, dynamic> resp) {
    if (resp['txid'] is String) return (resp['txid'] as String).toUpperCase();
    if (resp['txID'] is String) return (resp['txID'] as String).toUpperCase();
    return null; // 若节点未返回 txid/txID，让上层感知并处理
  }

  static Uint8List _hexToBytes(String hex) {
    final cleaned = hex.startsWith('0x') ? hex.substring(2) : hex;
    return Uint8List.fromList(convert.hex.decode(cleaned));
  }

  static String _bytesToHex(List<int> b) => convert.hex.encode(b);

  static Uint8List _bigIntToFixed(BigInt i, int len) {
    // 将 BigInt 转为固定长度字节（左侧补零）
    final hexStr = i.toRadixString(16).padLeft(len * 2, '0');
    return Uint8List.fromList(convert.hex.decode(hexStr));
  }

  /// Dry-run USDT transfer to estimate energy and validate before broadcasting.
  /// Returns the raw response from triggerconstantcontract.
  Future<Map<String, dynamic>> dryRunUsdtTransfer({
    required String fromBase58,
    required String toBase58,
    required BigInt usdt6,
    required String contractBase58,
  }) async {
    final fromHex41 = TronAddressUtils.base58ToHex41(fromBase58);
    final toHex41 = TronAddressUtils.base58ToHex41(toBase58);
    final contractHex41 = TronAddressUtils.base58ToHex41(contractBase58);

    final paramsHex = _encodeTrc20TransferParams(toHex41, usdt6);

    final resp = await _postJson('/wallet/triggerconstantcontract', {
      'owner_address': fromHex41,
      'contract_address': contractHex41,
      'function_selector': 'transfer(address,uint256)',
      'parameter': paramsHex,
      'visible': false,
    });
    if (resp is Map<String, dynamic>) return resp;
    return {'raw': resp};
  }

  /// Encode TRC20 transfer(address,uint256) parameters.
  /// `toHex41` should be a 0x41-prefixed hex address string.
  String _encodeTrc20TransferParams(String toHex41, BigInt amount) {
    String clean = toHex41.toLowerCase();
    if (clean.startsWith('0x')) clean = clean.substring(2);
    // Tron hex address starts with '41' then 20-byte address.
    if (clean.startsWith('41')) clean = clean.substring(2);
    // Left-pad address to 32 bytes (64 hex chars).
    final addrPadded = clean.padLeft(64, '0');
    // Amount to hex, left-pad to 32 bytes.
    final amtHex = amount.toRadixString(16);
    final amtPadded = amtHex.padLeft(64, '0');
    return addrPadded + amtPadded;
  }
}

// =============== AEAD 加/解密封装 ===============

enum _AeadSpec { aesGcm, chacha20poly1305 }

Future<Uint8List> _aeadDecrypt(
  Uint8List enc,
  Uint8List key,
  Uint8List nonce,
  _AeadSpec spec,
) async {
  if (enc.length < 17) throw Exception('密文长度异常');
  final ct = enc.sublist(0, enc.length - 16);
  final tag = enc.sublist(enc.length - 16);

  final aead = switch (spec) {
    _AeadSpec.aesGcm => cg.AesGcm.with256bits(),
    _AeadSpec.chacha20poly1305 => cg.Chacha20.poly1305Aead(),
  };

  final clear = await aead.decrypt(
    cg.SecretBox(ct, nonce: nonce, mac: cg.Mac(tag)),
    secretKey: cg.SecretKey(key),
  );
  return Uint8List.fromList(clear);
}

Future<Uint8List> _aeadEncrypt(
  Uint8List plain,
  Uint8List key,
  Uint8List nonce,
  _AeadSpec spec,
) async {
  final aead = switch (spec) {
    _AeadSpec.aesGcm => cg.AesGcm.with256bits(),
    _AeadSpec.chacha20poly1305 => cg.Chacha20.poly1305Aead(),
  };

  final box = await aead.encrypt(
    plain,
    secretKey: cg.SecretKey(key),
    nonce: nonce,
  );
  // 返回 ct||tag 格式，便于与解密函数配对
  return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
}

// =============== 数据载体（支持 enc['key'] 访问 & 别名） ===============

class EncryptedPrivateKey {
  final String encPrivateKeyB64;
  final String nonceB64;
  final String salt1B64;
  final String salt2B64;
  final String salt3B64;
  final String masterSaltB64;
  final int pbkdf2Iterations;

  EncryptedPrivateKey({
    required this.encPrivateKeyB64,
    required this.nonceB64,
    required this.salt1B64,
    required this.salt2B64,
    required this.salt3B64,
    required this.masterSaltB64,
    required this.pbkdf2Iterations,
  });

  /// enc['ciphertextB64'] 兼容下标访问
  dynamic operator [](String key) {
    switch (key) {
      case 'ciphertextB64': // 别名
      case 'encPrivateKeyB64':
        return encPrivateKeyB64;
      case 'nonceB64':
        return nonceB64;
      case 'salt1B64':
        return salt1B64;
      case 'salt2B64':
        return salt2B64;
      case 'salt3B64':
        return salt3B64;
      case 'masterSaltB64':
        return masterSaltB64;
      case 'pbkdf2Iterations':
        return pbkdf2Iterations;
      default:
        return null;
    }
  }

  Map<String, dynamic> asMap() => {
        'encPrivateKeyB64': encPrivateKeyB64,
        'ciphertextB64': encPrivateKeyB64, // 别名，兼容旧代码
        'nonceB64': nonceB64,
        'salt1B64': salt1B64,
        'salt2B64': salt2B64,
        'salt3B64': salt3B64,
        'masterSaltB64': masterSaltB64,
        'pbkdf2Iterations': pbkdf2Iterations,
      };

  @override
  String toString() => jsonEncode(asMap());
}



/// Dry-run USDT transfer to estimate energy and validate before broadcasting.
/// Returns the raw response from triggerconstantcontract.


