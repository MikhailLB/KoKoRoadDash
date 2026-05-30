import 'package:flutter/material.dart';

/// A soft fade-through page transition used app-wide for a calmer feel than
/// the default platform push.
Route<T> fadeRoute<T>(Widget page, {Duration? duration}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration ?? const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (BuildContext context, Animation<double> a,
            Animation<double> b) =>
        page,
    transitionsBuilder: (BuildContext context, Animation<double> anim,
        Animation<double> secondary, Widget child) {
      final CurvedAnimation curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: child,
      );
    },
  );
}
