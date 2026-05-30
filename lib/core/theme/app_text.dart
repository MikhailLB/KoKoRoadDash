import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared text styles. We rely on the default platform font (no bundled font
/// files) but give everything a confident, rounded, game-like weight.
class AppText {
  AppText._();

  static const String _family = '.SF Pro Rounded';

  static TextStyle title({
    double size = 34,
    Color color = AppColors.white,
    double letterSpacing = 0.5,
  }) {
    return TextStyle(
      fontFamilyFallback: const <String>[_family, 'Roboto'],
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle button({double size = 20, Color color = AppColors.cocoa}) {
    return TextStyle(
      fontFamilyFallback: const <String>[_family, 'Roboto'],
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0.6,
    );
  }

  static TextStyle body({
    double size = 15,
    Color color = AppColors.cream,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamilyFallback: const <String>[_family, 'Roboto'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle label({double size = 13, Color color = AppColors.steel}) {
    return TextStyle(
      fontFamilyFallback: const <String>[_family, 'Roboto'],
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 1.2,
    );
  }
}
