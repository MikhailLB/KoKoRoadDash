/// Central registry of every bundled asset path.
///
/// Keeping these in one place avoids stringly-typed paths scattered across the
/// codebase and makes it trivial to preload the right images.
class AssetPaths {
  AssetPaths._();

  // Branding ----------------------------------------------------------------
  static const String gameName = 'assets/Game_Name.webp';
  static const String logoWhite = 'assets/logo_white.webp';
  static const String logoGray = 'assets/gray_logo.webp';

  // Loading -----------------------------------------------------------------
  static const String loadingVideoVertical =
      'assets/Loading/vertical_loading_screen.mp4';
  static const String loadingVideoHorizontal =
      'assets/Loading/horizontal_loading_screen.mp4';

  /// Ordered from empty -> full. Used for the progress bar cross-fade.
  static const List<String> loadingBars = <String>[
    'assets/Loading/Loading_Bar_Empty.webp',
    'assets/Loading/Loading_Bar_Half.webp',
    'assets/Loading/Loading_Bar_Almost.webp',
    'assets/Loading/Loading_Bar_Full.webp',
  ];

  // Full-screen overlays ----------------------------------------------------
  static const String notificationsVertical =
      'assets/notifications/Vertical_Notifications_Screen.webp';
  static const String notificationsHorizontal =
      'assets/notifications/Horizontal_Notifications_Screen.webp';
  static const String nowifiVertical =
      'assets/nowifi/Vertical_Nowifi_Screen.webp';
  static const String nowifiHorizontal =
      'assets/nowifi/Horizontal_Nowifi_Screen.webp';

  // Backgrounds -------------------------------------------------------------
  static const String _bgDir = 'assets/Gameplay_assets/backrounds';

  static String bgStart(int biome) => '$_bgDir/bg_${biome}_start_asset.webp';
  static String bgEnd(int biome) => '$_bgDir/bg_${biome}_end_asset.webp';
  static String bgLine(int biome) => '$_bgDir/bg_${biome}_line_asset.webp';
  static String bgSafezone(int biome) =>
      '$_bgDir/bg_${biome}_safezone_asset.webp';
  static String bgSafezoneLine(int biome) =>
      '$_bgDir/bg_${biome}_safezone_line_asset.webp';

  // Cars --------------------------------------------------------------------
  static const String _carDir = 'assets/Gameplay_assets/cars';
  static const List<String> cars = <String>[
    '$_carDir/car_taxi_asset.webp',
    '$_carDir/car_police_asset.webp',
    '$_carDir/car_van_asset.webp',
    '$_carDir/car_firetrack_asset.webp',
  ];

  // Chicken skins -----------------------------------------------------------
  static const String _skinDir = 'assets/Gameplay_assets/skins';
  static String chicken(String id) => '$_skinDir/chicken_${id}_asset.webp';
  static String chickenSmash(String id) =>
      '$_skinDir/chicken_${id}_smash_asset.webp';
}
