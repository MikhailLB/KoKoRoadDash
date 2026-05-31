import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/constants/asset_paths.dart';
import 'core/storage/local_store.dart';
import 'data/repositories/progress_repository.dart';
import 'game/rendering/sprite_cache.dart';
import 'lane/config/lane_vault.dart';
import 'lane/infra/attribution_wire.dart';
import 'lane/infra/branded_agent.dart';
import 'lane/infra/lane_dispatcher.dart';
import 'lane/infra/lane_stash.dart';
import 'lane/infra/push_pulse.dart';
import 'lane/infra/wire_sensor.dart';

// ──────────────────────────────────────────────────────────────
// main() — boot order is significant.
//
//   1. WidgetsFlutterBinding + status bar config
//   2. Sprite cache + ProgressRepository preload (white-part)
//   3. Firebase + AppCheck init in parallel
//   4. BrandedAgent UA warm-up + LaneStash open in parallel
//   5. PushPulse boot fired but NOT awaited
//   6. runApp(KokoRoadDashApp)
//
// Firebase.initializeApp() is called exactly once, here. Never call
// it again in any service or widget — `[core/duplicate-app]` is fatal.
// ──────────────────────────────────────────────────────────────

Future<void> _bootFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (_) {}
}

Future<void> _preloadGameAssets() async {
  final List<String> paths = <String>[
    ...AssetPaths.cars,
    for (int b = 1; b <= 4; b++) ...<String>[
      AssetPaths.bgLine(b),
      AssetPaths.bgStart(b),
      AssetPaths.bgEnd(b),
      AssetPaths.bgSafezone(b),
    ],
    for (final String s in <String>[
      'default',
      'gold',
      'samurai',
      'pharaon',
      'dragon',
    ])
      ...<String>[
        AssetPaths.chicken(s),
        AssetPaths.chickenSmash(s),
      ],
  ];
  await SpriteCache.instance.loadAll(paths);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // White part assets first — the arcade path must render correctly even
  // when the lane bridge bypasses the existing LoadingScreen.
  final Future<void> spriteFuture = _preloadGameAssets();
  final Future<LocalStore> storeFuture = LocalStore.init();

  // Firebase, UA warm-up, vault open in parallel.
  final Future<void> firebaseFuture = _bootFirebase();
  final Future<void> agentFuture = brandedAgent.primeUa();
  final LaneStash stash = LaneStash();
  final Future<void> stashFuture = stash.open().catchError((Object _) {});

  await firebaseFuture;
  await Future.wait<void>(<Future<void>>[
    agentFuture,
    stashFuture,
    spriteFuture,
  ]);

  final LocalStore store = await storeFuture;
  final ProgressRepository progress = ProgressRepository(store);

  final WireSensor sensor = WireSensor();
  final AttributionWire wire = AttributionWire();
  final LaneDispatcher dispatcher = LaneDispatcher(stash);
  final PushPulse pulse = PushPulse(stash);

  // Push bootstrap runs in parallel with the first frame — we never block
  // the UI on it. Result lands in `pulse.coldGate` if anyone needs it.
  unawaited(pulse.kick().catchError((Object _) {}));

  // The lane bridge only takes over when at least one credential is
  // provisioned. Until the masked byte arrays are filled the app boots
  // straight to the existing white-part LoadingScreen — letting the puzzle
  // be tested in isolation while the bridge is still under credentials.
  final bool laneEnabled =
      laneEndpointUrl().isNotEmpty || appsflyerDevKey().isNotEmpty;

  runApp(KokoRoadDashApp(
    progress: progress,
    stash: stash,
    sensor: sensor,
    wire: wire,
    dispatcher: dispatcher,
    pulse: pulse,
    laneEnabled: laneEnabled,
  ));
}
