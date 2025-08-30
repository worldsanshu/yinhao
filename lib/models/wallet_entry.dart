import 'dart:convert';
import 'package:hive/hive.dart';


@HiveType(typeId: 1)
class WalletEntry extends HiveObject {
  @HiveField(0) final String id; // uuid
  @HiveField(1) final String addressBase58;
  @HiveField(2) final String addressHex; // 0x41 + 20 bytes
  @HiveField(3) final String encPrivateKeyB64; // AES-GCM ciphertext+mac
  @HiveField(4) final String nonceB64;
  @HiveField(5) final String salt1B64;
  @HiveField(6) final String salt2B64;
  @HiveField(7) final String salt3B64;
  @HiveField(8) final String masterSaltB64;
  @HiveField(9) final int pbkdf2Iterations;
  @HiveField(10) final String hint1;
  @HiveField(11) final String hint2;
  @HiveField(12) final String hint3;
  @HiveField(13) final DateTime createdAt;
  @HiveField(14) final int version;

  WalletEntry({
    required this.id,
    required this.addressBase58,
    required this.addressHex,
    required this.encPrivateKeyB64,
    required this.nonceB64,
    required this.salt1B64,
    required this.salt2B64,
    required this.salt3B64,
    required this.masterSaltB64,
    required this.pbkdf2Iterations,
    required this.hint1,
    required this.hint2,
    required this.hint3,
    required this.createdAt,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'addressBase58': addressBase58,
    'addressHex': addressHex,
    'encPrivateKeyB64': encPrivateKeyB64,
    'nonceB64': nonceB64,
    'salt1B64': salt1B64,
    'salt2B64': salt2B64,
    'salt3B64': salt3B64,
    'masterSaltB64': masterSaltB64,
    'pbkdf2Iterations': pbkdf2Iterations,
    'hint1': hint1,
    'hint2': hint2,
    'hint3': hint3,
    'createdAt': createdAt.toIso8601String(),
    'version': version,
  };

  factory WalletEntry.fromJson(Map<String, dynamic> j) => WalletEntry(
    id: j['id'],
    addressBase58: j['addressBase58'],
    addressHex: j['addressHex'],
    encPrivateKeyB64: j['encPrivateKeyB64'],
    nonceB64: j['nonceB64'],
    salt1B64: j['salt1B64'],
    salt2B64: j['salt2B64'],
    salt3B64: j['salt3B64'],
    masterSaltB64: j['masterSaltB64'] ?? '',
    pbkdf2Iterations: j['pbkdf2Iterations'],
    hint1: j['hint1'],
    hint2: j['hint2'],
    hint3: j['hint3'],
    createdAt: DateTime.parse(j['createdAt']),
    version: j['version'] ?? 1,
  );

  String exportJson() => jsonEncode(toJson());
  static WalletEntry importJson(String s) => WalletEntry.fromJson(jsonDecode(s));
}

// 手写 Adapter（无需 build_runner）
class WalletEntryAdapter extends TypeAdapter<WalletEntry> {
  @override
  final int typeId = 1;
  @override
  WalletEntry read(BinaryReader r) {
    final m = <int, dynamic>{};
    final numOfFields = r.readByte();
    for (var i = 0; i < numOfFields; i++) {
      m[r.readByte()] = r.read();
    }
    return WalletEntry(
      id: m[0] as String,
      addressBase58: m[1] as String,
      addressHex: m[2] as String,
      encPrivateKeyB64: m[3] as String,
      nonceB64: m[4] as String,
      salt1B64: m[5] as String,
      salt2B64: m[6] as String,
      salt3B64: m[7] as String,
      masterSaltB64: m[8] as String,
      pbkdf2Iterations: m[9] as int,
      hint1: m[10] as String,
      hint2: m[11] as String,
      hint3: m[12] as String,
      createdAt: m[13] as DateTime,
      version: m[14] as int,
    );
  }
  @override
  void write(BinaryWriter w, WalletEntry obj) {
    w
      ..writeByte(15)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.addressBase58)
      ..writeByte(2)..write(obj.addressHex)
      ..writeByte(3)..write(obj.encPrivateKeyB64)
      ..writeByte(4)..write(obj.nonceB64)
      ..writeByte(5)..write(obj.salt1B64)
      ..writeByte(6)..write(obj.salt2B64)
      ..writeByte(7)..write(obj.salt3B64)
      ..writeByte(8)..write(obj.masterSaltB64)
      ..writeByte(9)..write(obj.pbkdf2Iterations)
      ..writeByte(10)..write(obj.hint1)
      ..writeByte(11)..write(obj.hint2)
      ..writeByte(12)..write(obj.hint3)
      ..writeByte(13)..write(obj.createdAt)
      ..writeByte(14)..write(obj.version);
  }
}