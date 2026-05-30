import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A simple WebView wrapper for legal pages (privacy policy, support).
/// Used from the game settings screen.
class InfoViewer extends StatefulWidget {
  final String title;
  final String url;

  const InfoViewer({super.key, required this.title, required this.url});

  @override
  State<InfoViewer> createState() => _InfoViewerState();
}

class _InfoViewerState extends State<InfoViewer> {
  late final WebViewController _wvc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.nightDeep)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      appBar: AppBar(
        backgroundColor: AppColors.nightDeep,
        foregroundColor: AppColors.cream,
        title: Text(widget.title, style: AppText.title(size: 18)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _wvc),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}
