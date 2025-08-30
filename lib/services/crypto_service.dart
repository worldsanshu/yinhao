import 'dart:convert';
import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:web3dart/crypto.dart' as ethcrypto;
import 'package:pointycastle/export.dart' as pc;
import 'key_derivation.dart';

class CryptoService {
  static Uint8List generatePrivateKey32() {
    return KeyDerivation.randomBytes(32);
  }

  static (String tronBase58, String tronHex41) deriveTronAddress(Uint8List privateKey32) {
    final priv = pc.ECPrivateKey(
      BigInt.parse(ethcrypto.bytesToHex(privateKey32, include0x: false), radix: 16),
      pc.ECDomainParameters('secp256k1'),
    );
    final pub = _publicKeyFromPrivate(priv);
    final pubBytes = _encodePublicKeyUncompressed(pub);
    final hashed = ethcrypto.keccak256(pubBytes.sublist(1));
    final addr20 = hashed.sublist(12);
    final tronHex41 = '41' + ethcrypto.bytesToHex(addr20, include0x: false);
    final tronBytes = Uint8List.fromList([0x41, ...addr20]);

    // base58check: payload + 4 bytes double-sha256 checksum
    final firstSha = crypto.sha256.convert(tronBytes).bytes;
    final secondSha = crypto.sha256.convert(firstSha).bytes;
    final check4 = Uint8List.fromList(secondSha.sublist(0,4));
    final base58 = bs58check.base58.encode(Uint8List.fromList([...tronBytes, ...check4]));
    return (base58, '0x' + tronHex41);
  }

  static pc.ECPublicKey _publicKeyFromPrivate(pc.ECPrivateKey privKey) {
    final params = pc.ECDomainParameters('secp256k1');
    final Q = params.G * privKey.d;
    return pc.ECPublicKey(Q, params);
  }

  static Uint8List _encodePublicKeyUncompressed(pc.ECPublicKey pubKey) {
    final x = pubKey.Q!.x!.toBigInteger()!;
    final y = pubKey.Q!.y!.toBigInteger()!;
    final xb = ethcrypto.hexToBytes(x.toRadixString(16).padLeft(64, '0'));
    final yb = ethcrypto.hexToBytes(y.toRadixString(16).padLeft(64, '0'));
    return Uint8List.fromList([0x04, ...xb, ...yb]);
  }

  static Future<Map<String, String>> encryptPrivateKeyWithThreePasswords({
    required Uint8List privateKey32,
    required String pass1,
    required String pass2,
    required String pass3,
    required int iterations,
  }) async {
    final salt1 = KeyDerivation.randomBytes(16);
    final salt2 = KeyDerivation.randomBytes(16);
    final salt3 = KeyDerivation.randomBytes(16);
    final (k1, _) = await KeyDerivation.pbkdf2(pass1, salt1, iterations: iterations);
    final (k2, _) = await KeyDerivation.pbkdf2(pass2, salt2, iterations: iterations);
    final (k3, _) = await KeyDerivation.pbkdf2(pass3, salt3, iterations: iterations);
    final masterSalt = KeyDerivation.randomBytes(32);
    final k = await KeyDerivation.combineKDFs(k1, k2, k3, masterSalt);
    final (ct, nonce) = await KeyDerivation.encryptAesGcm(k, privateKey32);
    return {
      'ciphertextB64': base64Encode(ct),
      'nonceB64': base64Encode(nonce),
      'salt1B64': base64Encode(salt1),
      'salt2B64': base64Encode(salt2),
      'salt3B64': base64Encode(salt3),
      'masterSaltB64': base64Encode(masterSalt),
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
    final salt1 = base64Decode(salt1B64);
    final salt2 = base64Decode(salt2B64);
    final salt3 = base64Decode(salt3B64);
    final (k1, _) = await KeyDerivation.pbkdf2(pass1, salt1, iterations: iterations);
    final (k2, _) = await KeyDerivation.pbkdf2(pass2, salt2, iterations: iterations);
    final (k3, _) = await KeyDerivation.pbkdf2(pass3, salt3, iterations: iterations);
    final masterSalt = base64Decode(masterSaltB64);
    final k = await KeyDerivation.combineKDFs(k1, k2, k3, masterSalt);
    final privateKey = await KeyDerivation.decryptAesGcm(k, base64Decode(ciphertextB64), base64Decode(nonceB64));
    return privateKey;
  }
}
