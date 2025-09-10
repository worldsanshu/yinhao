// lib/widgets/explorer_sheet.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Tronscan 等外部链接的半屏浏览器（底部弹层）
/// - 解决 WebView 在 bottomSheet 中**无法滚动**的问题（通过 gestureRecognizers 抢占手势）
/// - 支持 back/forward/refresh、进度条、外部打开
class ExplorerSheet extends StatefulWidget {
  final String url;
  final String? title;

  const ExplorerSheet({super.key, required this.url, this.title});
  /// Helper to build proper Tronscan URLs (handles trailing `#`).

  /// 便捷方法：展示弹层
  static Future<void> show(BuildContext context,
      {required String url, String? title}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ExplorerSheet(url: url, title: title),
        ),
      ),
    );
  }

  @override
  State<ExplorerSheet> createState() => _ExplorerSheetState();
}

class _ExplorerSheetState extends State<ExplorerSheet> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _title = '';

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? _inferTitle(widget.url);

    final params = const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) => NavigationDecision.navigate,
        onPageStarted: (_) => setState(() => _progress = 0),
        onProgress: (p) => setState(() => _progress = p.toDouble()),
        onPageFinished: (_) async {
          final canBack = await _controller.canGoBack();
          final canForward = await _controller.canGoForward();
          setState(() {
            _canGoBack = canBack;
            _canGoForward = canForward;
            _progress = 100;
          });
        },
      ))
      ..loadRequest(Uri.parse(widget.url));

    // iOS 手势返回（从页面边缘左滑返回上一页）
 _controller.setNavigationDelegate(
  NavigationDelegate(
    onNavigationRequest: (req) => NavigationDecision.navigate,
  ),
);

  }

  @override
  Widget build(BuildContext context) {
    // 关键：通过 EagerGestureRecognizer 抢占垂直手势，避免被 BottomSheet/DraggableScrollableSheet 截获
    final gestures = <Factory<OneSequenceGestureRecognizer>>{
      Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer()..onUpdate = (_) {}),
    };

    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          _buildTopBar(context),
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(value: _progress / 100),
          const Divider(height: 1),
          Expanded(
            child: WebViewWidget(
              controller: _controller,
              gestureRecognizers: gestures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final title = _title.isNotEmpty ? _title : _inferTitle(widget.url);

    return SafeArea(
      bottom: false,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            IconButton(
              tooltip: '关闭',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            IconButton(
              tooltip: '后退',
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
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '外部打开',
              icon: const Icon(Icons.open_in_new),
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _inferTitle(String url) {
    if (url.contains('/transaction/')) return '交易详情';
    if (url.contains('/address/')) return '地址详情';
    return '浏览';
  }
}
