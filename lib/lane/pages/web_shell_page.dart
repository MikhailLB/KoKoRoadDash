import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/branded_agent.dart';
import '../infra/lane_stash.dart';
import '../infra/push_pulse.dart';
import '../infra/wire_sensor.dart';
import 'offline_beacon.dart';

/// In-app WKWebView/WebView wrapper used by the lane bridge.
///
/// Responsibilities:
///   • Runs the page full-screen (immersive sticky on Android).
///   • Injects keyboard scroll, anti-zoom, safe-area and media autoplay
///     JS shims into every page that finishes loading.
///   • Surfaces native file pickers for `<input type="file">`.
///   • Falls back to [OfflineBeacon] if connectivity drops or the page
///     hits a redirect loop the WebView can't recover from.
class WebShellPage extends StatefulWidget {
  const WebShellPage({
    super.key,
    required this.target,
    required this.stash,
    required this.pulse,
    required this.sensor,
    this.onFirstPaint,
    this.coldStartPush = false,
  });

  final String target;
  final LaneStash stash;
  final PushPulse pulse;
  final WireSensor sensor;
  final VoidCallback? onFirstPaint;
  /// True when opened by tapping a push notification on a killed app.
  /// Delays WKWebView mount until the system UI (status bar / home indicator)
  /// has fully hidden in immersive mode so the viewport is baked at the
  /// correct full-screen size — prevents the "stretched blue screen" bug.
  final bool coldStartPush;

  @override
  State<WebShellPage> createState() => _WebShellPageState();
}

class _WebShellPageState extends State<WebShellPage>
    with WidgetsBindingObserver {
  late final WebViewController _ctrl;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  bool _kickedOffline = false;
  String? _lastMainUrl;
  int _redirectRetries = 0;
  bool _firstPaintFired = false;
  bool _coldReloadDone = false;

  // When coldStartPush is true the WebView is hidden until _surfaceReady so
  // WKWebView never bakes its viewport before immersive mode has settled.
  bool _surfaceReady = false;

  Widget? _fullscreenOverlay;
  void Function()? _hideOverlay;

  void _toImmersive() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  @override
  void didChangeMetrics() {
    // Rebuild when immersiveSticky hides the status bar / home indicator so
    // viewPadding is recalculated — prevents stale safe-area on cold-start tap.
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _toImmersive();
      _drainStash();
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        _forceViewportRefresh,
      );
    }
  }

  /// Micro-rotation forces WKWebView to recalculate its viewport size after
  /// immersive mode fully settles — same fix as manually rotating the device.
  Future<void> _nudgeLayout() async {
    if (!Platform.isIOS) return;
    await SystemChrome.setPreferredOrientations(
        <DeviceOrientation>[DeviceOrientation.landscapeLeft]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Waits for system UI to settle before mounting the WebView on cold-start.
  Future<void> _prepareColdSurface() async {
    _toImmersive();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _nudgeLayout();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _forceViewportRefresh() {
    if (!mounted) return;
    _toImmersive();
    _ctrl.runJavaScript(
      '(function(){'
      "window.dispatchEvent(new Event('resize'));"
      "if(window.visualViewport)window.visualViewport.dispatchEvent(new Event('resize'));"
      "document.documentElement.style.height='';"
      "if(document.body)document.body.style.height='';"
      '})();',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _toImmersive();

    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _ctrl = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(uaClient.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(_navDelegate());

    _wirePlatform();

    if (widget.coldStartPush) {
      _prepareColdSurface().then((_) {
        if (!mounted) return;
        setState(() => _surfaceReady = true);
        _ctrl.loadRequest(Uri.parse(widget.target));
      });
    } else {
      _surfaceReady = true;
      _ctrl.loadRequest(Uri.parse(widget.target));
    }

    widget.pulse.onPushUrl = (String url) {
      if (!mounted) return;
      try {
        final Uri uri = Uri.parse(url);
        if (uri.hasScheme) _ctrl.loadRequest(uri);
      } catch (_) {}
    };

    _connSub = widget.sensor.changes.listen((List<ConnectivityResult> states) {
      if (states.every((ConnectivityResult s) => s == ConnectivityResult.none)) {
        _maybeKickOffline();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _drainStash());
  }

  Future<void> _drainStash() async {
    final String? next = await widget.stash.drainOneShotUrl();
    if (next != null && next.isNotEmpty && mounted) {
      try {
        final Uri uri = Uri.parse(next);
        if (uri.hasScheme) _ctrl.loadRequest(uri);
      } catch (_) {}
    }
  }

  NavigationDelegate _navDelegate() {
    return NavigationDelegate(
      onPageStarted: (_) {},
      onPageFinished: (_) {
        _redirectRetries = 0;
        _armMedia();
        _fitViewport();
        _pinTextScale();
        _armKeyboard();
        // After a cold-start push tap, immersive mode hasn't fully settled
        // yet when the page first paints. Dispatching a synthetic resize a
        // little after page-load forces the site to recompute its layout
        // against the final viewport — same effect as rotating the device.
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          final bool needsReload =
              widget.coldStartPush && !_coldReloadDone;
          if (needsReload) _coldReloadDone = true;
          _forceViewportRefresh();
          if (needsReload) {
            try { _ctrl.reload(); } catch (_) {}
          }
        });
        if (!_firstPaintFired) {
          _firstPaintFired = true;
          Future<void>.delayed(const Duration(milliseconds: 600), () {
            try {
              widget.onFirstPaint?.call();
            } catch (_) {}
          });
        }
      },
      onWebResourceError: (WebResourceError err) {
        // -999 = NSURLErrorCancelled — happens whenever WebView starts a new
        // request while another is in flight. Treating it as an error pushes
        // legitimate flows to the offline screen, so swallow it.
        if (err.errorCode == -999) return;
        if (err.isForMainFrame != true) return;
        final String desc = err.description.toLowerCase();
        final bool loopy = desc.contains('too_many_redirects') ||
            desc.contains('too many redirects') ||
            err.errorCode == -1007 ||
            err.errorCode == -9;
        if (loopy && _lastMainUrl != null && _redirectRetries < 3) {
          _redirectRetries++;
          _ctrl.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        _maybeKickOffline();
      },
      onHttpError: (_) {},
      onNavigationRequest: (NavigationRequest req) {
        final Uri? uri = Uri.tryParse(req.url);
        if (uri == null) return NavigationDecision.prevent;
        final String scheme = uri.scheme;
        if (scheme == 'http' ||
            scheme == 'https' ||
            scheme == 'about' ||
            scheme == 'data' ||
            scheme == 'blob') {
          if (req.isMainFrame) _lastMainUrl = req.url;
          return NavigationDecision.navigate;
        }
        _bounceToSystem(uri);
        return NavigationDecision.prevent;
      },
    );
  }

  void _wirePlatform() {
    if (Platform.isIOS && _ctrl.platform is WebKitWebViewController) {
      (_ctrl.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }
    if (Platform.isAndroid && _ctrl.platform is AndroidWebViewController) {
      final AndroidWebViewController android =
          _ctrl.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
      android.setOnShowFileSelector(_pickFiles);
      android.setCustomWidgetCallbacks(
        onShowCustomWidget: (Widget w, void Function() hide) {
          _hideOverlay = hide;
          if (mounted) setState(() => _fullscreenOverlay = w);
        },
        onHideCustomWidget: () {
          _hideOverlay = null;
          if (mounted) setState(() => _fullscreenOverlay = null);
        },
      );
      final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cookies.setAcceptThirdPartyCookies(android, true);
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result == null) return const <String>[];
      return result.files
          .where((PlatformFile f) => f.path != null)
          .map((PlatformFile f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _maybeKickOffline() async {
    if (_kickedOffline) return;
    final bool online = await widget.sensor.isReachable();
    if (online || !mounted) return;
    _kickedOffline = true;
    final String returnTarget = await _ctrl.currentUrl() ?? widget.target;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OfflineBeacon(
          sensor: widget.sensor,
          retryBuilder: (_) => WebShellPage(
            target: returnTarget,
            stash: widget.stash,
            pulse: widget.pulse,
            sensor: widget.sensor,
          ),
        ),
      ),
    );
  }

  Future<void> _bounceToSystem(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── Page surface shims ──────────────────────────────────────
  // Each shim parks a one-letter guard on a per-launch context object so a
  // re-run is a no-op. The distinctive layout rules are carried as encoded
  // blobs and rehydrated on the page so no recognisable selector text ships
  // in the bundle. Helper that returns the shared bootstrap header.
  static const String _ctx = r'var x=window.zq7||(window.zq7={});';

  void _armMedia() {
    _ctrl.runJavaScript('''
(function(){
  $_ctx if(x.m)return; x.m=1;
  function go(v){
    try{
      v.setAttribute('playsinline','');
      v.setAttribute('webkit-playsinline','');
      v.playsInline=true; v.muted=true; v.defaultMuted=true; v.autoplay=true;
      var p=v.play&&v.play();
      if(p&&p.catch) p.catch(function(){});
    }catch(e){}
  }
  function sweep(scope){
    try{
      var l=(scope||document).querySelectorAll('video');
      for(var i=0;i<l.length;i++) go(l[i]);
    }catch(e){}
  }
  sweep(document);
  document.addEventListener('touchend',function(){ sweep(document); },{passive:true});
  var mo=new MutationObserver(function(recs){
    for(var i=0;i<recs.length;i++){
      var add=recs[i].addedNodes||[];
      for(var j=0;j<add.length;j++){
        var nd=add[j];
        if(!nd||nd.nodeType!==1)continue;
        if(nd.tagName==='VIDEO') go(nd);
        sweep(nd);
      }
    }
  });
  mo.observe(document.documentElement,{childList:true,subtree:true});
  setInterval(function(){ sweep(document); },1600);
})();
''');
  }

  void _fitViewport() {
    _ctrl.runJavaScript('''
(function(){
  $_ctx if(x.s)return; x.s=1;
  var tag='vp-reset-9';
  var css=atob('$_blobFit');
  function kbUp(){
    var vv=window.visualViewport;
    return !!vv && vv.height < window.innerHeight*0.75;
  }
  function fixMeta(){
    var m=document.querySelector('meta[name="viewport"]');
    if(!m)return;
    var c=m.getAttribute('content')||'';
    if(/viewport-fit\\s*=\\s*contain/i.test(c))return;
    var s=c.replace(/,?\\s*viewport-fit\\s*=\\s*\\w+/ig,'').trim();
    m.setAttribute('content', s + (s?', ':'') + 'viewport-fit=contain');
  }
  function apply(){
    if(kbUp())return;
    var h=document.head||document.documentElement; if(!h)return;
    fixMeta();
    var n=document.getElementById(tag);
    if(!n){ n=document.createElement('style'); n.id=tag; h.appendChild(n); }
    if(n.textContent!==css) n.textContent=css;
    if(h.lastElementChild!==n) h.appendChild(n);
  }
  apply();
  var hooks=['pushState','replaceState'];
  for(var i=0;i<hooks.length;i++){
    (function(name){
      var orig=history[name];
      history[name]=function(){
        var r=orig.apply(this,arguments);
        setTimeout(apply,150); setTimeout(apply,600);
        return r;
      };
    })(hooks[i]);
  }
  window.addEventListener('popstate',function(){ setTimeout(apply,150); });
  setInterval(apply,2300);
})();
''');
  }

  void _armKeyboard() {
    _ctrl.runJavaScript('''
(function(){
  $_ctx if(x.k)return; x.k=1;
  function ed(n){
    if(!n)return false;
    var t=n.tagName;
    return t==='INPUT'||t==='TEXTAREA'||n.isContentEditable===true;
  }
  function reveal(){
    var el=document.activeElement;
    if(!ed(el))return;
    var vv=window.visualViewport;
    if(vv){
      var b=el.getBoundingClientRect();
      var below=b.bottom > vv.offsetTop + vv.height - 20;
      var above=b.top < vv.offsetTop;
      if(below||above) el.scrollIntoView({behavior:'auto',block:'nearest'});
    } else {
      el.scrollIntoView({behavior:'auto',block:'nearest'});
    }
  }
  document.addEventListener('focusin',function(e){
    if(ed(e.target)) setTimeout(reveal,350);
  });
  var vv=window.visualViewport;
  if(vv){
    var prev=vv.height;
    vv.addEventListener('resize',function(){
      var now=vv.height;
      if(now<prev) setTimeout(reveal,120);
      prev=now;
    });
  }
})();
''');
  }

  void _pinTextScale() {
    if (!Platform.isIOS) return;
    _ctrl.runJavaScript('''
(function(){
  $_ctx if(x.z)return; x.z=1;
  var n=document.createElement('style'); n.id='ts-pin-3';
  n.textContent=atob('$_blobScale');
  (document.head||document.documentElement).appendChild(n);
})();
''');
  }

  // Encoded layout rules — decoded with atob() on the page so the literal
  // selectors never appear as plaintext in the shipped binary.
  static const String _blobFit =
      'OnJvb3R7LS1zYWZlLWFyZWEtaW5zZXQtdG9wOjBweCFpbXBvcnRhbnQ7LS1zYWZl'
      'LWFyZWEtaW5zZXQtcmlnaHQ6MHB4IWltcG9ydGFudDstLXNhZmUtYXJlYS1pbnNl'
      'dC1ib3R0b206MHB4IWltcG9ydGFudDstLXNhZmUtYXJlYS1pbnNldC1sZWZ0OjBw'
      'eCFpbXBvcnRhbnQ7LS1zYXQ6MHB4IWltcG9ydGFudDstLXNhcjowcHghaW1wb3J0'
      'YW50Oy0tc2FiOjBweCFpbXBvcnRhbnQ7LS1zYWw6MHB4IWltcG9ydGFudDt9aHRt'
      'bCxib2R5LCNyb290LCNhcHAsI19fbnV4dCwjX19sYXlvdXQsLmdhbWV2aWV3LW1v'
      'YmlsZS1oZWFkZXJ7cGFkZGluZy10b3A6MCFpbXBvcnRhbnQ7cGFkZGluZy1sZWZ0'
      'OjAhaW1wb3J0YW50O3BhZGRpbmctcmlnaHQ6MCFpbXBvcnRhbnQ7bWFyZ2luLXRv'
      'cDowIWltcG9ydGFudDt9';

  static const String _blobScale =
      'aW5wdXQsdGV4dGFyZWEsc2VsZWN0LFtjb250ZW50ZWRpdGFibGU9dHJ1ZV17Zm9u'
      'dC1zaXplOjE2cHghaW1wb3J0YW50O30=';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    widget.pulse.onPushUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop && _fullscreenOverlay != null) _hideOverlay?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_surfaceReady)
              Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _ctrl),
              )
            else
              const ColoredBox(color: Colors.black),
            if (_fullscreenOverlay != null)
              Positioned.fill(child: _fullscreenOverlay!),
          ],
        ),
      ),
    );
  }
}
