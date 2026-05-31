import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/repositories/progress_repository.dart';
import '../features/bootstrap/loading_screen.dart';
import '../lane/infra/attribution_wire.dart';
import '../lane/infra/lane_dispatcher.dart';
import '../lane/infra/lane_stash.dart';
import '../lane/infra/push_pulse.dart';
import '../lane/infra/wire_sensor.dart';
import '../lane/pages/intro_lane_loader.dart';
import 'app_scope.dart';

/// Root widget.
///
/// • When `laneEnabled` is true the lane bridge takes over — it shows its
///   own splash, runs the attribution pipeline and routes to either the
///   web shell or the white-part [LoadingScreen] / [MainMenuScreen].
/// • When `laneEnabled` is false (credentials not yet provisioned) the
///   app boots straight to the existing white-part [LoadingScreen]
///   exactly as before — the puzzle remains playable in isolation.
class KokoRoadDashApp extends StatelessWidget {
  const KokoRoadDashApp({
    super.key,
    required this.progress,
    required this.stash,
    required this.sensor,
    required this.wire,
    required this.dispatcher,
    required this.pulse,
    required this.laneEnabled,
  });

  final ProgressRepository progress;
  final LaneStash stash;
  final WireSensor sensor;
  final AttributionWire wire;
  final LaneDispatcher dispatcher;
  final PushPulse pulse;
  final bool laneEnabled;

  @override
  Widget build(BuildContext context) {
    final Widget root = laneEnabled
        ? IntroLaneLoader(
            stash: stash,
            sensor: sensor,
            wire: wire,
            dispatcher: dispatcher,
            pulse: pulse,
          )
        : const LoadingScreen();

    return AppScope(
      progress: progress,
      child: MaterialApp(
        title: 'Koko Road Dash',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.nightDeep,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.gold,
            brightness: Brightness.dark,
          ),
          splashFactory: InkRipple.splashFactory,
        ),
        home: root,
      ),
    );
  }
}
