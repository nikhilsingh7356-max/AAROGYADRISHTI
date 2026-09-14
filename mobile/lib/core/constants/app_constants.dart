/// Global application constants.
///
/// Secrets and environment-specific values are read from `--dart-define`
/// overrides at build time so nothing sensitive is ever hardcoded. Example:
///
/// ```sh
/// flutter run \
///   --dart-define=API_BASE_URL=https://aarogyadrishti.vercel.app \
///   --dart-define=ENVIRONMENT=production
/// ```
library;

import 'dart:ui' show Color;
class AppConstants {
  AppConstants._();

  static const String appName = 'AarogyaDrishti';
  static const String tagline = 'Track. Understand. Prevent.';
  static const String phase = 'Phase 6';

  /// Origin of the FastAPI backend. Override this for local development.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://aarogyadrishti.vercel.app',
  );

  static const String apiV1Prefix = String.fromEnvironment(
    'API_V1_PREFIX',
    defaultValue: '/api/v1',
  );

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';

  /// Baseline window target (Phase 1 has no pattern detection).
  static const int baselineTargetDays = 7;
  static const int baselineWindowDays = 14;

  /// Local cache version - bump to force a client cache reset.
  static const int cacheVersion = 1;

  // Local preference keys (plain prefs; never sensitive data).
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyRoutineSleep = 'routine_sleep_hours';
  static const String keyRoutineActivity = 'routine_activity_level';
  static const String keyRoutineWater = 'routine_water_intake';
  static const String keyRoutineStress = 'routine_stress_level';
}

/// 8px baseline spacing system.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Standard horizontal page gutter.
  static const double gutter = 20;
}

/// Brand palette. Colors are defined once here so screens never hardcode
/// ad-hoc colors.
class AppColors {
  AppColors._();

  static const Color deepTeal = Color(0xFF0B6E63);
  static const Color emerald = Color(0xFF12B886);
  static const Color mint = Color(0xFFE3F4EF);
  static const Color softMint = Color(0xFFF0F7F4);
  static const Color offWhite = Color(0xFFFAFCFB);
  static const Color charcoal = Color(0xFF17211E);
  static const Color mutedGray = Color(0xFF6B7A74);
}