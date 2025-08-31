import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as b58;
import 'package:convert/convert.dart' as conv;
import 'address_codec.dart';

/// 传入 41 开头的十六进制（可带 0x），返回标准 Base58 (T...)。
String tronHexToBase58(String hex41) {
  var h = hex41.trim();
  if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
  if (!h.startsWith('41')) {
    throw ArgumentError('不是合法的 TRON Hex 地址（应以 41 开头）：$hex41');
  }
  final bytes = Uint8List.fromList(conv.hex.decode(h));
  return b58.encode(bytes);
}

/// 传入 T... 的 Base58，返回 41 开头的 Hex（不带 0x）。
String tronBase58ToHex(String base58) {
  final bytes = b58.decode(base58.trim());
  return conv.hex.encode(bytes).toLowerCase();
}

/// 任何地址输入都转成 Base58 展示：
/// - T... 直接返回
/// - 41... / 0x41... 转换为 T...
/// - 一些历史脏数据（如 "T-xxxx", "T_xxxx"）尝试清洗
String normalizeTronForDisplay(String input) {
  var s = input.trim();
  if (s.isEmpty) throw ArgumentError('地址为空');

  // 清洗历史脏数据：T_xxx、T-xxx
  if (s.startsWith('T_') || s.startsWith('T-')) {
    s = s.substring(2); // 去掉前缀，后面按 hex 尝试解析
  }

  if (s.startsWith('T')) return s;                 // 已是 Base58
  if (s.startsWith('41') || s.startsWith('0x41'))  // Hex -> Base58
    return tronHexToBase58(s);

  throw ArgumentError('无法识别的地址格式: $input');
}
