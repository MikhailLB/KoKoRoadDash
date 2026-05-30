import 'package:flutter/material.dart';

/// The Koko Road Dash palette.
///
/// Pulls from the two strongest art directions in the asset set: the warm
/// caramel/gold of the "Koko Road Dash" wordmark and the cool neon-cyan of the
/// sci-fi road tiles. The menu leans warm, the gameplay leans cool.
class AppColors {
  AppColors._();

  // Warm brand (wordmark) ---------------------------------------------------
  static const Color gold = Color(0xFFF6B23C);
  static const Color goldLight = Color(0xFFFFD877);
  static const Color orange = Color(0xFFF26B2A);
  static const Color cream = Color(0xFFF3E4C7);
  static const Color cocoa = Color(0xFF6B4A2B);

  // Cool sci-fi (road) ------------------------------------------------------
  static const Color neon = Color(0xFF35E0F2);
  static const Color neonGreen = Color(0xFF7CF06A);
  static const Color violet = Color(0xFFB983FF);
  static const Color steel = Color(0xFF8A95A6);

  // Surfaces ----------------------------------------------------------------
  static const Color night = Color(0xFF141A38);
  static const Color nightDeep = Color(0xFF0C1027);
  static const Color panel = Color(0xFF1F274C);
  static const Color panelLight = Color(0xFF2C386A);
  static const Color road = Color(0xFF353B47);

  static const Color white = Color(0xFFFDFBF4);
  static const Color ink = Color(0xFF20243A);

  // Gradients ---------------------------------------------------------------
  static const LinearGradient menuSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF1B2350), Color(0xFF0C1027)],
  );

  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[goldLight, gold],
  );

  static const LinearGradient orangeButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFF9A4D), orange],
  );

  static const LinearGradient neonButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF5CEBFB), Color(0xFF1FB6CE)],
  );
}
