import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/repositories/progress_repository.dart';
import '../features/bootstrap/loading_screen.dart';
import '../net/config_fetcher.dart';
import '../net/net_probe.dart';
import '../net/push_handler.dart';
import '../net/tracking_engine.dart';
import '../net/vault_service.dart';
import 'app_scope.dart';

class KokoRoadDashApp extends StatelessWidget {
  const KokoRoadDashApp({
    super.key,
    required this.progress,
    required this.vault,
    required this.netProbe,
    required this.tracker,
    required this.fetcher,
    required this.pusher,
  });

  final ProgressRepository progress;
  final VaultService vault;
  final NetProbe netProbe;
  final TrackingEngine tracker;
  final ConfigFetcher fetcher;
  final PushHandler pusher;

  @override
  Widget build(BuildContext context) {
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
        home: LoadingScreen(
          vault: vault,
          netProbe: netProbe,
          tracker: tracker,
          fetcher: fetcher,
          pusher: pusher,
        ),
      ),
    );
  }
}
