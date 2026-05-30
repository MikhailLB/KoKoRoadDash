import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/storage/local_store.dart';
import 'data/repositories/progress_repository.dart';
import 'net/vault_service.dart';
import 'net/net_probe.dart';
import 'net/tracking_engine.dart';
import 'net/config_fetcher.dart';
import 'net/push_handler.dart';
import 'net/road_net_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check (fail-silent if not yet configured)
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // HTTP client — must init before any network calls
  await roadNetClient.init();

  // White part persistence
  final LocalStore store = await LocalStore.init();
  final ProgressRepository progress = ProgressRepository(store);

  // Gray part services
  final vault = VaultService();
  await vault.init();

  final netProbe = NetProbe();
  final tracker = TrackingEngine();
  final fetcher = ConfigFetcher(vault);
  final pusher = PushHandler(vault);

  runApp(KokoRoadDashApp(
    progress: progress,
    vault: vault,
    netProbe: netProbe,
    tracker: tracker,
    fetcher: fetcher,
    pusher: pusher,
  ));
}
