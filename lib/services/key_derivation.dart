import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class KeyDerivation {
  static final _rand = Random.secure();
  static const int defaultIterations = 310000;

  static Uint8List randomBytes(int n) {
    final b = List<int>.generate(n, (_) => _rand.nextInt(256));
    return Uint8List.fromList(b);
  }

  static Future<(Uint8List, Uint8List)> pbkdf2(String pass, Uint8List salt,
      {int? iterations}) async {
    final algo = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations ?? defaultIterations,
      bits: 256,
    );
    final key = await algo.deriveKey(
      secretKey: SecretKey(utf8.encode(pass)),
      nonce: salt,
    );
    final k = await key.extractBytes();
    return (Uint8List.fromList(k), salt);
  }

  static Future<Uint8List> combineKDFs(
      Uint8List k1, Uint8List k2, Uint8List k3, Uint8List masterSalt) async {
    final mac = await Hmac.sha256().calculateMac(
      Uint8List.fromList([...k1, ...k2, ...k3]),
      secretKey: SecretKey(masterSalt),
    );
    return Uint8List.fromList(mac.bytes);
  }

  static Future<(Uint8List, Uint8List)> encryptAesGcm(
      Uint8List key32, Uint8List plaintext) async {
    final cipher = AesGcm.with256bits();
    final nonce = randomBytes(12);
    final box = await cipher.encrypt(plaintext,
        secretKey: SecretKey(key32), nonce: nonce);
    return (Uint8List.fromList(box.cipherText + box.mac.bytes), nonce);
  }

  static Future<Uint8List> decryptAesGcm(
      Uint8List key32, Uint8List ciphertextPlusMac, Uint8List nonce) async {
    final cipher = AesGcm.with256bits();
    final ct = ciphertextPlusMac.sublist(0, ciphertextPlusMac.length - 16);
    final mac = Mac(ciphertextPlusMac.sublist(ciphertextPlusMac.length - 16));
    final plain = await cipher.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: SecretKey(key32),
    );
    return Uint8List.fromList(plain);
  }
}
