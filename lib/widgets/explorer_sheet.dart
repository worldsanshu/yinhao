import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// A bottom-sheet in-app browser using WebView.
/// Use `ExplorerSheet.show(context, url: 'https://tronscan.org/#/address/<T...>')`.
/// Includes back/forward/refresh, progress bar, and an external-open fallback.
class ExplorerSheet extends StatefulWidget {
  final String url; // full URL, e.g. https://tronscan.org/#/transaction/<txId>
  final String? title;

  const ExplorerSheet({super.key, required this.url, this.title});

  @override
  State<ExplorerSheet> createState() => _ExplorerSheetState();

  static Future<void> show(BuildContext context, {required String url, String? title}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.88,
        child: ExplorerSheet(url: url, title: title),
      ),
    );
  }

  /// Helper to build proper Tronscan URLs (handles trailing `#`).
  static String tronscanUrl({required String origin, required String path}) {
    var o = origin;
    if (!o.endsWith('#') && !o.endsWith('/#')) {
      if (!o.endsWith('/')) o += '/';
      o += '#';
    }
    final p = path.startsWith('/') ? path : '/$path';
    return o + p; // example => https://tronscan.org/#/address/T...
  }
}

class _ExplorerSheetState extends State<ExplorerSheet> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) => _refreshNavStates(),
          onUrlChange: (_) => _refreshNavStates(),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _refreshNavStates() async {
    final b = await _controller.canGoBack();
    final f = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = b;
      _canGoForward = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? _inferTitle(widget.url);

    return Column(
      children: [
        const SizedBox(height: 8),
        // drag handle
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        // header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: _canGoBack ? () => _controller.goBack() : null,
              ),
              IconButton(
                tooltip: '前进',
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                onPressed: _canGoForward ? () => _controller.goForward() : null,
              ),
              IconButton(
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
                onPressed: () => _controller.reload(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: '在系统浏览器打开',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
              ),
              IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        if (_progress > 0 && _progress < 100)
          LinearProgressIndicator(value: _progress / 100),
        const Divider(height: 1),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }

  String _inferTitle(String url) {
    if (url.contains('/transaction/')) return '交易详情';
    if (url.contains('/address/')) return '地址详情';
    return '浏览';
  }
}
