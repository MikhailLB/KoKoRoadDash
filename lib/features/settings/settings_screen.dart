import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_links.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositories/progress_repository.dart';
import '../menu/widgets/menu_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProgressRepository progress = AppScope.progressOf(context);
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: progress,
            builder: (BuildContext context, _) {
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 16, 8),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.cream),
                        ),
                        Expanded(
                          child: Text('SETTINGS',
                              textAlign: TextAlign.center,
                              style: AppText.title(size: 24)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: <Widget>[
                        _Section(
                          title: 'GAME',
                          children: <Widget>[
                            _SwitchTile(
                              icon: Icons.vibration_rounded,
                              label: 'Haptics',
                              value: progress.hapticsEnabled,
                              onChanged: progress.setHaptics,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _Section(
                          title: 'ABOUT',
                          children: <Widget>[
                            _LinkTile(
                              icon: Icons.public_rounded,
                              label: 'Website',
                              onTap: () => _open(context, AppLinks.site),
                            ),
                            _LinkTile(
                              icon: Icons.privacy_tip_rounded,
                              label: 'Privacy Policy',
                              onTap: () =>
                                  _open(context, AppLinks.privacyPolicy),
                            ),
                            _LinkTile(
                              icon: Icons.support_agent_rounded,
                              label: 'Support',
                              onTap: () => _open(context, AppLinks.support),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _Section(
                          title: 'DATA',
                          children: <Widget>[
                            _LinkTile(
                              icon: Icons.delete_forever_rounded,
                              label: 'Reset progress',
                              danger: true,
                              onTap: () => _confirmReset(context, progress),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            '${AppLinks.appName}  •  v1.0.0',
                            style: AppText.label(
                                size: 11, color: AppColors.steel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          content: Text('Could not open $url'),
        ),
      );
    }
  }

  Future<void> _confirmReset(
      BuildContext context, ProgressRepository progress) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Reset progress?', style: AppText.title(size: 20)),
        content: Text(
          'This clears all levels, stars and coins. This cannot be undone.',
          style: AppText.body(size: 14),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: AppText.body(size: 15, color: AppColors.cream)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset',
                style: AppText.button(size: 15, color: AppColors.orange)),
          ),
        ],
      ),
    );
    if (yes == true) {
      await progress.resetAll();
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(title, style: AppText.label(color: AppColors.goldLight)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neon),
      title: Text(label, style: AppText.body(size: 16, color: AppColors.white)),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppColors.goldLight,
        onChanged: onChanged,
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? AppColors.orange : AppColors.cream;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? AppColors.orange : AppColors.neon),
      title: Text(label, style: AppText.body(size: 16, color: color)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppColors.steel.withValues(alpha: 0.6)),
    );
  }
}
