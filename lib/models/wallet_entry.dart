class WalletEntry {
  final String id;
  final String addressBase58;
  final String addressHex;
  final String encPrivateKeyB64;
  final String nonceB64;
  final String salt1B64;
  final String salt2B64;
  final String salt3B64;
  final String masterSaltB64;
  final int pbkdf2Iterations;
  final String? hint1;
  final String? hint2;
  final String? hint3;
  final DateTime createdAt;
  final int version;
  final bool isDefault;

  const WalletEntry({
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
    this.hint1,
    this.hint2,
    this.hint3,
    required this.createdAt,
    required this.version,
    this.isDefault = false,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> j) {
    return WalletEntry(
      id: j['id'] as String,
      addressBase58: j['addressBase58'] as String,
      addressHex: j['addressHex'] as String,
      encPrivateKeyB64: j['encPrivateKeyB64'] as String,
      nonceB64: j['nonceB64'] as String,
      salt1B64: j['salt1B64'] as String,
      salt2B64: j['salt2B64'] as String,
      salt3B64: j['salt3B64'] as String,
      masterSaltB64: j['masterSaltB64'] as String,
      pbkdf2Iterations: (j['pbkdf2Iterations'] as num).toInt(),
      hint1: j['hint1'] as String?,
      hint2: j['hint2'] as String?,
      hint3: j['hint3'] as String?,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch((j['createdAtMs'] ?? 0) as int, isUtc: false),
      version: (j['version'] as num?)?.toInt() ?? 1,
      isDefault: (j['isDefault'] as bool?) ?? false,
    );
  }

  static WalletEntry? tryFrom(dynamic v) {
    if (v == null) return null;
    if (v is WalletEntry) return v;
    if (v is Map) return WalletEntry.fromJson(Map<String, dynamic>.from(v));
    return null;
  }

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
    'createdAtMs': createdAt.millisecondsSinceEpoch,
    'version': version,
    'isDefault': isDefault,
  };

  String exportJson() {
    final m = toJson();
    return m.toString();
  }
}
