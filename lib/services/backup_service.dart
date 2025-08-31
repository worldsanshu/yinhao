import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/wallet_entry.dart';

class BackupService {
  static String exportAll(Box box) {
    final list = <Map<String, dynamic>>[];
    for (final k in box.keys) {
      final e = WalletEntry.tryFrom(box.get(k));
      if (e != null) list.add(e.toJson());
    }
    return const JsonEncoder.withIndent('  ').convert({'version': 1, 'entries': list});
  }

  static int importFromJson(Box box, String jsonStr) {
    final j = json.decode(jsonStr);
    int count = 0;
    if (j is Map && j['entries'] is List) {
      for (final m in (j['entries'] as List)) {
        final e = WalletEntry.tryFrom(m);
        if (e != null) {
          box.put(e.id, e.toJson());
          count++;
        }
      }
    } else if (j is Map) {
      final e = WalletEntry.tryFrom(j);
      if (e != null) {
        box.put(e.id, e.toJson());
        count++;
      }
    } else if (j is List) {
      for (final m in j) {
        final e = WalletEntry.tryFrom(m);
        if (e != null) {
          box.put(e.id, e.toJson());
          count++;
        }
      }
    }
    return count;
  }
}
