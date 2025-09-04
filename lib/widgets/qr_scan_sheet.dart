// lib/widgets/qr_scan_sheet.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// showQrScannerSheet: 打开一个底部扫码面板，返回识别到的字符串；
/// 识别到后自动关闭并返回第一个有效值（去重）。
Future<String?> showQrScannerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _QrScanSheet(),
  );
}

class _QrScanSheet extends StatefulWidget {
  const _QrScanSheet();

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _hasResult = false;
  bool _torch = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                const Text('扫一扫',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                IconButton(
                  tooltip: _torch ? '关闭手电' : '打开手电',
                  icon:
                      Icon(_torch ? Icons.flashlight_off : Icons.flashlight_on),
                  onPressed: () async {
                    _torch = !_torch;
                    await _controller.toggleTorch();
                    if (mounted) setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        if (_hasResult) return;
                        for (final b in capture.barcodes) {
                          final raw = b.rawValue ?? '';
                          if (raw.isEmpty) continue;
                          _hasResult = true;
                          Navigator.pop(context, raw);
                          break;
                        }
                      },
                      errorBuilder: (context, e, child) {
                        _error = e.toString();
                        return _buildError(theme, _error!);
                      },
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.7),
                              width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('对齐二维码自动识别', style: TextStyle(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, String message) {
    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '无法使用摄像头：$message',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

/// 从扫码内容中提取 Tron Base58 地址：
/// - 支持原始 Base58（T 开头）
/// - 支持 tron: 前缀，后带 ?amount= 之类
/// - 支持 JSON 里包含 address 字段
String? extractTronBase58(String input) {
  final s = input.trim();

  // 原始 Base58
  if (RegExp(r'^[T][1-9A-HJ-NP-Za-km-z]{25,48}\$').hasMatch(s)) {
    return s.split(RegExp(r'\s|\$')).first;
  }

  // tron:XXXX[?amount=...]
  if (s.toLowerCase().startsWith('tron:')) {
    final body = s.substring(5);
    final addr = body.split('?').first;
    if (addr.startsWith('T')) return addr;
  }

  // 一些钱包会把地址放到 JSON 字段里
  if (s.startsWith('{') && s.endsWith('}')) {
    try {
      final map = Map<String, dynamic>.from(jsonDecode(s) as Map);
      final addr = map['address']?.toString() ?? map['to']?.toString();
      if (addr != null && addr.startsWith('T')) return addr;
    } catch (_) {}
  }

  // 常见 query: address=TVxx...&amount=...
  final idx = s.indexOf('address=');
  if (idx >= 0) {
    final after = s.substring(idx + 8);
    final addr = after.split(RegExp(r'[&\s]')).first;
    if (addr.startsWith('T')) return addr;
  }

  return null;
}
