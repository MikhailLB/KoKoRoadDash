import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/koko_button.dart';
import '../menu/main_menu_screen.dart';

/// One-time onboarding inviting the player to enable notifications. The
/// full-screen art is bundled; we overlay the call-to-action. Shown once.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    final ProgressRepository progress = AppScope.progressOf(context);
    await progress.markOnboardingSeen();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(const MainMenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          OrientationBuilder(
            builder: (BuildContext context, Orientation orientation) {
              final String asset = orientation == Orientation.landscape
                  ? AssetPaths.notificationsHorizontal
                  : AssetPaths.notificationsVertical;
              return Image.asset(asset, fit: BoxFit.cover);
            },
          ),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, 0.9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    KokoButton(
                      label: 'ALLOW',
                      icon: Icons.notifications_active_rounded,
                      style: KokoButtonStyle.gold,
                      onPressed: () => _finish(context),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _finish(context),
                      child: Text('Maybe later',
                          style: AppText.body(
                              size: 15, color: AppColors.cream)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
