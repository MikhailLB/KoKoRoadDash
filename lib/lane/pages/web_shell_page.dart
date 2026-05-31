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
  });

  final String target;
  final LaneStash stash;
  final PushPulse pulse;
  final WireSensor sensor;
  final VoidCallback? onFirstPaint;

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

  Widget? _fullscreenOverlay;
  void Function()? _hideOverlay;

  void _toImmersive() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _toImmersive();
      _drainStash();
    }
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
      ..setUserAgent(brandedAgent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(_navDelegate());

    _wirePlatform();
    _ctrl.loadRequest(Uri.parse(widget.target));

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
        _injectSafeArea();
        _injectKeyboardFix();
        _injectAntiZoom();
        _injectMediaAutoplay();
        // After a cold-start push tap, immersive mode hasn't fully settled
        // yet when the page first paints. Dispatching a synthetic resize a
        // little after page-load forces the site to recompute its layout
        // against the final viewport — same effect as rotating the device.
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          _ctrl.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'if(window.visualViewport)'
            '  window.visualViewport.dispatchEvent(new Event("resize"));',
          );
          _injectSafeArea();
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
  // A single `window.kzShell` namespace object holds the "already-ran"
  // guards (created lazily by whichever shim runs first), so the page's
  // global scope stays clean with no recognisable per-shim flag set.
  void _injectSafeArea() {
    _ctrl.runJavaScript(r'''
(function(){
  var ns=window.kzShell||(window.kzShell={}); if(ns.fit)return; ns.fit=1;
  var styleId='kz-fit';
  var rules=[
    ':root{',
    '--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;}',
    'html,body,#root,#app,#__nuxt,#__layout,.gameview-mobile-header{',
    'padding-top:0!important;padding-left:0!important;padding-right:0!important;margin-top:0!important;}'
  ].join('');
  function keyboardUp(){
    var vv=window.visualViewport;
    return !!vv && vv.height < window.innerHeight*0.75;
  }
  function patchViewport(){
    var meta=document.querySelector('meta[name="viewport"]');
    if(!meta)return;
    var content=meta.getAttribute('content')||'';
    if(/viewport-fit\s*=\s*contain/i.test(content))return;
    var stripped=content.replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
    meta.setAttribute('content', stripped + (stripped?', ':'') + 'viewport-fit=contain');
  }
  function run(){
    if(keyboardUp())return;
    var head=document.head||document.documentElement; if(!head)return;
    patchViewport();
    var node=document.getElementById(styleId);
    if(!node){ node=document.createElement('style'); node.id=styleId; head.appendChild(node); }
    if(node.textContent!==rules) node.textContent=rules;
    if(head.lastElementChild!==node) head.appendChild(node);
  }
  run();
  var spa=['pushState','replaceState'];
  for(var i=0;i<spa.length;i++){
    (function(name){
      var orig=history[name];
      history[name]=function(){
        var out=orig.apply(this,arguments);
        setTimeout(run,150); setTimeout(run,600);
        return out;
      };
    })(spa[i]);
  }
  window.addEventListener('popstate',function(){ setTimeout(run,150); });
  setInterval(run,2500);
})();
''');
  }

  void _injectKeyboardFix() {
    _ctrl.runJavaScript(r'''
(function(){
  var ns=window.kzShell||(window.kzShell={}); if(ns.kb)return; ns.kb=1;
  function editable(node){
    if(!node)return false;
    var t=node.tagName;
    return t==='INPUT'||t==='TEXTAREA'||node.isContentEditable===true;
  }
  function bringIntoView(){
    var el=document.activeElement;
    if(!editable(el))return;
    var vv=window.visualViewport;
    if(vv){
      var box=el.getBoundingClientRect();
      var below=box.bottom > vv.offsetTop + vv.height - 20;
      var above=box.top < vv.offsetTop;
      if(below||above) el.scrollIntoView({behavior:'auto',block:'nearest'});
    } else {
      el.scrollIntoView({behavior:'auto',block:'nearest'});
    }
  }
  document.addEventListener('focusin',function(ev){
    if(editable(ev.target)) setTimeout(bringIntoView,350);
  });
  var vv=window.visualViewport;
  if(vv){
    var last=vv.height;
    vv.addEventListener('resize',function(){
      var now=vv.height;
      if(now<last) setTimeout(bringIntoView,120);
      last=now;
    });
  }
})();
''');
  }

  void _injectAntiZoom() {
    if (!Platform.isIOS) return;
    _ctrl.runJavaScript(r'''
(function(){
  var ns=window.kzShell||(window.kzShell={}); if(ns.zoom)return; ns.zoom=1;
  var node=document.createElement('style'); node.id='kz-zoom';
  node.textContent='input,textarea,select,[contenteditable=true]{font-size:16px!important;}';
  (document.head||document.documentElement).appendChild(node);
})();
''');
  }

  void _injectMediaAutoplay() {
    _ctrl.runJavaScript(r'''
(function(){
  var ns=window.kzShell||(window.kzShell={}); if(ns.vid)return; ns.vid=1;
  function arm(media){
    try{
      media.setAttribute('playsinline','');
      media.setAttribute('webkit-playsinline','');
      media.playsInline=true; media.muted=true; media.defaultMuted=true; media.autoplay=true;
      var pr=media.play&&media.play();
      if(pr&&pr.catch) pr.catch(function(){});
    }catch(e){}
  }
  function scan(scope){
    try{
      var list=(scope||document).querySelectorAll('video');
      for(var i=0;i<list.length;i++) arm(list[i]);
    }catch(e){}
  }
  scan(document);
  document.addEventListener('touchend',function(){ scan(document); },{passive:true});
  var watcher=new MutationObserver(function(records){
    for(var i=0;i<records.length;i++){
      var added=records[i].addedNodes||[];
      for(var j=0;j<added.length;j++){
        var node=added[j];
        if(!node||node.nodeType!==1)continue;
        if(node.tagName==='VIDEO') arm(node);
        scan(node);
      }
    }
  });
  watcher.observe(document.documentElement,{childList:true,subtree:true});
  setInterval(function(){ scan(document); },1500);
})();
''');
  }

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
            Padding(
              padding: EdgeInsets.only(
                top: safe.top,
                bottom: safe.bottom,
                left: safe.left,
                right: safe.right,
              ),
              child: WebViewWidget(controller: _ctrl),
            ),
            if (_fullscreenOverlay != null)
              Positioned.fill(child: _fullscreenOverlay!),
          ],
        ),
      ),
    );
  }
}
