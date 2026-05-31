import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../widgets/koko_button.dart';
import '../config/lane_config.dart';
import '../infra/lane_stash.dart';
import '../infra/push_pulse.dart';
import '../infra/wire_sensor.dart';
import 'web_shell_page.dart';

/// Optional push consent prompt shown right before opening the shell.
///
/// The artwork is the bundled notifications full-screen image. Buttons are
/// the standard `KokoButton` family so the look matches the white part.
class NotifyConsentPage extends StatefulWidget {
  const NotifyConsentPage({
    super.key,
    required this.stash,
    required this.pulse,
    required this.sensor,
    required this.shellUrl,
    this.onTokenReady,
  });

  final LaneStash stash;
  final PushPulse pulse;
  final WireSensor sensor;
  final String shellUrl;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<NotifyConsentPage> createState() => _NotifyConsentPageState();
}

class _NotifyConsentPageState extends State<NotifyConsentPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _stampCooldown() async {
    final int until =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            LaneConfig.notifyCooldownSeconds;
    await widget.stash.writeConsentCooldown(until);
  }

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bool granted = await widget.pulse.askConsent();
      if (granted) {
        final String? token = await widget.pulse.refreshTokenPostConsent();
        if (token != null && token.isNotEmpty) {
          await widget.onTokenReady?.call(token);
        }
      } else {
        await _stampCooldown();
      }
      _openShell();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _later() async {
    if (_busy) return;
    await _stampCooldown();
    _openShell();
  }

  void _openShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => WebShellPage(
          target: widget.shellUrl,
          stash: widget.stash,
          pulse: widget.pulse,
          sensor: widget.sensor,
        ),
      ),
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
                    SizedBox(
                      width: 320,
                      child: KokoButton(
                        label: _busy ? 'WAITING…' : 'TURN ON ALERTS',
                        icon: Icons.notifications_active_rounded,
                        style: KokoButtonStyle.gold,
                        onPressed: _busy ? null : _allow,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy ? null : _later,
                      child: Text(
                        'Maybe later',
                        style: AppText.body(size: 15, color: AppColors.cream),
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
