import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../widgets/koko_button.dart';

void showHowToPlay(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) => const _HowToPlaySheet(),
  );
}

class _HowToPlaySheet extends StatelessWidget {
  const _HowToPlaySheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.panelLight, AppColors.panel],
        ),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),
          Text('HOW TO PLAY', style: AppText.title(size: 26)),
          const SizedBox(height: 18),
          const _Rule(
            icon: Icons.touch_app_rounded,
            color: AppColors.neon,
            title: 'Move one step',
            body: 'Swipe or tap the arrows to move Koko one tile. The '
                'hourglass lets you wait — useful for timing, but it spends a '
                'move too.',
          ),
          const _Rule(
            icon: Icons.directions_car_rounded,
            color: AppColors.gold,
            title: 'Cars move after you',
            body: 'Every car follows a fixed, repeating route. They only '
                'advance once you take your turn — so read the pattern.',
          ),
          const _Rule(
            icon: Icons.timer_rounded,
            color: AppColors.violet,
            title: 'Mind the move limit',
            body: 'Each level gives a move budget (shown up top). Run out '
                'before the flag and you fail — so don\'t just stall.',
          ),
          const _Rule(
            icon: Icons.lightbulb_rounded,
            color: AppColors.gold,
            title: 'Stuck? Use a hint',
            body: 'The first levels light up a safe corridor for free. Later '
                'on, tap the bulb to buy one with coins.',
          ),
          const _Rule(
            icon: Icons.flag_rounded,
            color: AppColors.neonGreen,
            title: 'Reach the flag',
            body: 'Time your moves to cross safely to the glowing finish pad.',
          ),
          const SizedBox(height: 8),
          KokoButton(
            label: 'GOT IT',
            style: KokoButtonStyle.gold,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: AppText.button(size: 16, color: AppColors.white)),
                const SizedBox(height: 3),
                Text(body, style: AppText.body(size: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
