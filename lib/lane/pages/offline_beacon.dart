import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/koko_button.dart';
import '../infra/wire_sensor.dart';

/// "Offline" screen rendered when the lane bridge cannot reach the
/// attribution endpoint at launch. Uses the existing Koko full-screen
/// nowifi artwork; the retry CTA is rendered with our tactile [KokoButton]
/// so the visual language stays consistent with the menu.
class OfflineBeacon extends StatefulWidget {
  const OfflineBeacon({
    super.key,
    required this.sensor,
    required this.retryBuilder,
  });

  final WireSensor sensor;
  final WidgetBuilder retryBuilder;

  @override
  State<OfflineBeacon> createState() => _OfflineBeaconState();
}

class _OfflineBeaconState extends State<OfflineBeacon> {
  bool _busy = false;
  bool _hintVisible = false;
  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final bool online = await widget.sensor.isReachable();
    if (!mounted) return;
    if (!online) {
      _hintTimer?.cancel();
      setState(() {
        _busy = false;
        _hintVisible = true;
      });
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _hintVisible = false);
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.retryBuilder),
    );
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
                    SizedBox(
                      width: 260,
                      child: KokoButton(
                        label: _busy ? 'CHECKING…' : 'TRY AGAIN',
                        icon: Icons.wifi_tethering_rounded,
                        style: KokoButtonStyle.orange,
                        onPressed: _busy ? null : _retry,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _hintVisible ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Still offline — check Wi-Fi and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
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
