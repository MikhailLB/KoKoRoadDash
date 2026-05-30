import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/repositories/progress_repository.dart';
import '../features/bootstrap/loading_screen.dart';
import 'app_scope.dart';

class KokoRoadDashApp extends StatelessWidget {
  const KokoRoadDashApp({super.key, required this.progress});

  final ProgressRepository progress;

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
        home: const LoadingScreen(),
      ),
    );
  }
}
