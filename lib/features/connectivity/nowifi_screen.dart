import 'package:flutter/material.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/connectivity_service.dart';
import '../../widgets/koko_button.dart';

/// Shown when the device is offline at launch. The full-screen art ships with
/// the asset pack; we overlay a retry control. Because the puzzle itself runs
/// fully offline, a quiet "continue" path is always available.
class NoWifiScreen extends StatefulWidget {
  const NoWifiScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<NoWifiScreen> createState() => _NoWifiScreenState();
}

class _NoWifiScreenState extends State<NoWifiScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final bool online = await const ConnectivityService().isOnline();
    if (!mounted) return;
    setState(() => _checking = false);
    if (online) {
      widget.onContinue();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          content: Text('Still offline. Check your connection.'),
        ),
      );
    }
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
                  ? AssetPaths.nowifiHorizontal
                  : AssetPaths.nowifiVertical;
              return Image.asset(asset, fit: BoxFit.cover);
            },
          ),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, 0.82),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    KokoButton(
                      label: _checking ? 'CHECKING…' : 'TRY AGAIN',
                      icon: Icons.refresh_rounded,
                      style: KokoButtonStyle.gold,
                      onPressed: _checking ? null : _retry,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: widget.onContinue,
                      child: Text('Play offline',
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
