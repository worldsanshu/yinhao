import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart' as conv;
import 'package:pointycastle/export.dart' as pc;
import 'address_codec.dart';
class CryptoService {
  static final _rnd = Random.secure();
  static final _curve = pc.ECCurve_secp256k1();

  static Uint8List generatePrivateKey32() {
    final sk = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      sk[i] = _rnd.nextInt(256);
    }
    if (sk.every((b) => b == 0)) sk[0] = 1;
    return sk;
  }

  /// 由 32 字节私钥派生 TRON 地址 (Base58 占位 + Hex)
  static (String, String) deriveTronAddress(Uint8List privateKey) {
    final d = BigInt.parse(conv.hex.encode(privateKey), radix: 16);
    final G = _curve.G;
    final Q = G * d;
    final pub = Q!.getEncoded(false); // 65字节，开头 0x04
    final keccak = pc.KeccakDigest(256);
    keccak.update(pub.sublist(1), 0, pub.length - 1);
    final out = Uint8List(32);
    keccak.doFinal(out, 0);
    final addr20 = out.sublist(12);
    // final tronHex = Uint8List.fromList([0x41, ...addr20]);
    // final tronHexStr = conv.hex.encode(tronHex);
    // final tronBase58 = _base58checkEncode(tronHex);
    // return (tronBase58, tronHexStr);


      final tronHexBytes = Uint8List.fromList([0x41, ...addr20]);
  final hex41 = conv.hex.encode(tronHexBytes).toLowerCase();
  final base58 = tronHexToBase58(hex41);
  return (base58, hex41);
  }

  /// AES-GCM(256) 三密派生密钥后异或合成 master key
  static Future<Map<String, String>> encryptPrivateKeyWithThreePasswords({
    required Uint8List privateKey32,
    required String pass1,
    required String pass2,
    required String pass3,
    required int iterations,
  }) async {
    final salt1 = _rand(16);
    final salt2 = _rand(16);
    final salt3 = _rand(16);
    final masterSalt = _rand(16);
    final k1 = _pbkdf2(pass1, salt1, iterations);
    final k2 = _pbkdf2(pass2, salt2, iterations);
    final k3 = _pbkdf2(pass3, salt3, iterations);
    final mk = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      mk[i] = k1[i] ^ k2[i] ^ k3[i];
    }
    final nonce = _rand(12);
    final cipher = _aesGcm(true, mk, nonce);
    final out = Uint8List(privateKey32.length + 16);
    final len = cipher.processBlock(privateKey32, 0, out, 0);
    return {
      'ciphertextB64': base64UrlEncode(out.sublist(0, len)),
      'nonceB64': base64UrlEncode(nonce),
      'salt1B64': base64UrlEncode(salt1),
      'salt2B64': base64UrlEncode(salt2),
      'salt3B64': base64UrlEncode(salt3),
      'masterSaltB64': base64UrlEncode(masterSalt),
    };
  }

  static Future<Uint8List> decryptPrivateKeyWithThreePasswords({
    required String pass1,
    required String pass2,
    required String pass3,
    required String ciphertextB64,
    required String nonceB64,
    required String salt1B64,
    required String salt2B64,
    required String salt3B64,
    required String masterSaltB64,
    required int iterations,
  }) async {
    final c = base64Url.decode(ciphertextB64);
    final nonce = base64Url.decode(nonceB64);
    final s1 = base64Url.decode(salt1B64);
    final s2 = base64Url.decode(salt2B64);
    final s3 = base64Url.decode(salt3B64);
    final k1 = _pbkdf2(pass1, s1, iterations);
    final k2 = _pbkdf2(pass2, s2, iterations);
    final k3 = _pbkdf2(pass3, s3, iterations);
    final mk = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      mk[i] = k1[i] ^ k2[i] ^ k3[i];
    }
    final cipher = _aesGcm(false, mk, nonce);
    final out = Uint8List(c.length);
    final len = cipher.processBlock(c, 0, out, 0);
    return out.sublist(0, len);
  }

  static Uint8List _pbkdf2(String pass, Uint8List salt, int iters) {
    final d = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, iters, 32));
    return d.process(Uint8List.fromList(utf8.encode(pass)));
  }

  static pc.AEADBlockCipher _aesGcm(bool forEncrypt, Uint8List key, Uint8List nonce) {
    final gcm = pc.GCMBlockCipher(pc.AESFastEngine());
    gcm.init(forEncrypt, pc.AEADParameters(pc.KeyParameter(key), 128, nonce, Uint8List(0)));
    return gcm;
  }

  static Uint8List _rand(int n) {
    final b = Uint8List(n);
    for (int i = 0; i < n; i++) b[i] = _rnd.nextInt(256);
    return b;
  }

  // --- Base58Check (Tron 地址) ---
  static String _base58checkEncode(Uint8List payload) {
    // 为避免引入更多依赖，这里仍返回一个可视占位字符串；
    // 如需真实 Base58Check，可改为使用 `bs58check` 包进行编码。
    return 'T-' + conv.hex.encode(payload);
  }
}