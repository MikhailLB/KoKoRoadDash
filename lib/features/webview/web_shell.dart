import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../net/net_probe.dart';
import '../../net/push_handler.dart';
import '../../net/road_net_client.dart';
import '../../net/vault_service.dart';
import '../connectivity/offline_wall.dart';

// ============================================================
// WEB SHELL — Full-screen WebView for gray mode
// ============================================================
// Shows the URL from the config endpoint. All orientations
// supported. Back button navigates within WebView history.
// ============================================================

/// Pre-warms the WebView engine before navigation.
Future<void> prepareWebEngine() async {}

class WebShell extends StatefulWidget {
  final String url;
  final VaultService vault;
  final PushHandler pusher;
  final NetProbe netProbe;

  const WebShell({
    super.key,
    required this.url,
    required this.vault,
    required this.pusher,
    required this.netProbe,
  });

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> with WidgetsBindingObserver {
  late final WebViewController _wvc;
  bool _loading = true;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  bool _showingOffline = false;

  String? _lastRedirectUrl;
  int _redirectRetries = 0;

  void _enforceImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enforceImmersive();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enforceImmersive();

    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(roadNetClient.userAgent)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          _redirectRetries = 0;
          _killSafeArea();
          _fixKeyboardScroll();
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame != true) return;
          final desc = err.description.toLowerCase();
          final isTooMany = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (isTooMany &&
              _lastRedirectUrl != null &&
              _redirectRetries < 3) {
            _redirectRetries++;
            _wvc.loadRequest(Uri.parse(_lastRedirectUrl!));
            return;
          }
          _checkOffline();
        },
        onHttpError: (_) {},
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          final s = uri.scheme;
          if (s == 'http' ||
              s == 'https' ||
              s == 'about' ||
              s == 'data' ||
              s == 'blob') {
            if (req.isMainFrame) _lastRedirectUrl = req.url;
            return NavigationDecision.navigate;
          }
          _openExternal(uri);
          return NavigationDecision.prevent;
        },
      ))
      ..enableZoom(false);

    _setupPlatform();
    _wvc.loadRequest(Uri.parse(widget.url));

    widget.pusher.onNotificationUrl = (url) {
      if (mounted) _wvc.loadRequest(Uri.parse(url));
    };

    _netSub = widget.netProbe.onChange.listen((results) {
      if (results.every((r) => r == ConnectivityResult.none)) {
        _checkOffline();
      }
    });
  }

  Future<void> _checkOffline() async {
    if (_showingOffline) return;
    final ok = await widget.netProbe.hasInternet();
    if (ok || !mounted) return;
    _showingOffline = true;

    final cur = await _wvc.currentUrl() ?? widget.url;
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineWall(
          retryBuilder: (_) => WebShell(
            url: cur,
            vault: widget.vault,
            pusher: widget.pusher,
            netProbe: widget.netProbe,
          ),
        ),
      ),
    );
  }

  void _setupPlatform() {
    if (Platform.isAndroid && _wvc.platform is AndroidWebViewController) {
      final ctrl = _wvc.platform as AndroidWebViewController;
      ctrl.setMediaPlaybackRequiresUserGesture(false);
      ctrl.setOnShowFileSelector(_pickFile);

      final cookieMgr = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cookieMgr.setAcceptThirdPartyCookies(ctrl, true);
    }
  }

  Future<List<String>> _pickFile(FileSelectorParams params) async {
    try {
      final r = await FilePicker.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (r != null && r.files.isNotEmpty) {
        return r.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void _fixKeyboardScroll() {
    _wvc.runJavaScript('''
(function(){
  if(window.__rkbFixed)return;window.__rkbFixed=true;
  function isInput(e){return e&&(e.tagName==='INPUT'||e.tagName==='TEXTAREA'||e.isContentEditable);}
  function doScroll(){
    var el=document.activeElement;if(!isInput(el))return;
    var vp=window.visualViewport;
    if(vp){var r=el.getBoundingClientRect(),vb=vp.offsetTop+vp.height;
      if(r.bottom>vb-20||r.top<vp.offsetTop)el.scrollIntoView({behavior:'auto',block:'nearest'});}
    else el.scrollIntoView({behavior:'auto',block:'nearest'});
  }
  document.addEventListener('focusin',function(e){if(isInput(e.target))setTimeout(doScroll,350);});
  if(window.visualViewport){
    var ph=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height;if(h<ph)setTimeout(doScroll,120);ph=h;
    });
  }
})();
''');
  }

  void _killSafeArea() {
    _wvc.runJavaScript(r'''
(function(){
  if(window.__rksa)return;window.__rksa=true;
  var ID='__rksa_css';
  var CSS=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;}html,body,#__nuxt,#app,#root{padding-top:0!important;margin-top:0!important;}';
  function apply(){
    var h=document.head||document.documentElement;if(!h)return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m&&!/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content',c+(c?', ':')+'viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){s=document.createElement('style');s.id=ID;h.appendChild(s);}
    if(s.textContent!==CSS)s.textContent=CSS;
    if(h.lastElementChild!==s)h.appendChild(s);
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn];history[fn]=function(){var r=o.apply(this,arguments);setTimeout(apply,80);setTimeout(apply,400);return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _netSub?.cancel();
    widget.pusher.onNotificationUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<bool> _onPopInvoked() async {
    if (await _wvc.canGoBack()) {
      await _wvc.goBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onPopInvoked();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).orientation == Orientation.landscape
                    ? 0
                    : MediaQuery.of(context).viewPadding.top,
              ),
              child: WebViewWidget(controller: _wvc),
            ),
            if (_loading)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFF6B23C)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
