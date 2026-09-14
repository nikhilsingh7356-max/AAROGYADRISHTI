/// Canonical value enums shared across the app.
///
/// Values match the backend string constants exactly so JSON serialization is
/// lossless.
library;

import 'package:flutter/material.dart';

enum PrimaryGoal {
  betterSleep('better_sleep', 'Better Sleep', Icons.nightlight_round),
  moreEnergy('more_energy', 'More Energy', Icons.bolt),
  physicalActivity('physical_activity', 'Physical Activity', Icons.directions_run),
  stressManagement('stress_management', 'Stress Management', Icons.self_improvement),
  healthyEating('healthy_eating', 'Healthy Eating', Icons.restaurant),
  hydration('hydration', 'Hydration', Icons.water_drop_outlined),
  overallLifestyle('overall_lifestyle', 'Overall Lifestyle', Icons.spa_outlined);

  const PrimaryGoal(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static PrimaryGoal? fromWire(String? s) =>
      PrimaryGoal.values.where((e) => e.wire == s).firstOrNull;
}

enum ActivityLevel {
  mostlySedentary('mostly_sedentary', 'Mostly sedentary'),
  lightlyActive('lightly_active', 'Lightly active'),
  moderatelyActive('moderately_active', 'Moderately active'),
  veryActive('very_active', 'Very active');

  const ActivityLevel(this.wire, this.label);
  final String wire;
  final String label;

  static ActivityLevel? fromWire(String? s) =>
      ActivityLevel.values.where((e) => e.wire == s).firstOrNull;
}

enum ExerciseLevel {
  none('none', 'None', 0),
  light('light', '15 min', 15),
  moderate('moderate', '30 min', 30),
  intense('intense', '60+ min', 60);

  const ExerciseLevel(this.wire, this.label, this.minutes);
  final String wire;
  final String label;
  final int minutes;

  static ExerciseLevel? fromWire(String? s) =>
      ExerciseLevel.values.where((e) => e.wire == s).firstOrNull;
}

enum MealQuality {
  healthy('healthy', 'Mostly healthy'),
  mixed('mixed', 'Mixed'),
  processed('processed', 'Mostly processed');

  const MealQuality(this.wire, this.label);
  final String wire;
  final String label;

  static MealQuality? fromWire(String? s) =>
      MealQuality.values.where((e) => e.wire == s).firstOrNull;
}

/// Onboarding routine buckets. The backend profile has no water field, so
/// these stay local-only (never sent to the profile API).
enum WaterIntake {
  low('low', '<1L'),
  medium('medium', '1\u20132L'),
  high('high', '2\u20133L'),
  veryHigh('very_high', '3L+');

  const WaterIntake(this.wire, this.label);
  final String wire;
  final String label;

  static WaterIntake? fromWire(String? s) =>
      WaterIntake.values.where((e) => e.wire == s).firstOrNull;
}

enum MoodLevel {
  veryLow('very_low', 'Very low'),
  low('low', 'Low'),
  okay('okay', 'Okay'),
  good('good', 'Good'),
  great('great', 'Great');

  const MoodLevel(this.wire, this.label);
  final String wire;
  final String label;

  static MoodLevel? fromWire(String? s) =>
      MoodLevel.values.where((e) => e.wire == s).firstOrNull;
}

enum CaffeineLevel {
  none('none', 'None'),
  low('low', 'Low'),
  moderate('moderate', 'Moderate'),
  high('high', 'High');

  const CaffeineLevel(this.wire, this.label);
  final String wire;
  final String label;

  static CaffeineLevel? fromWire(String? s) =>
      CaffeineLevel.values.where((e) => e.wire == s).firstOrNull;
}

enum SleepQuality {
  good('good', 'Good'),
  fair('fair', 'Fair'),
  poor('poor', 'Poor');

  const SleepQuality(this.wire, this.label);
  final String wire;
  final String label;

  static SleepQuality? fromWire(String? s) =>
      SleepQuality.values.where((e) => e.wire == s).firstOrNull;
}

enum BaselineStatus { gettingStarted, building, ready }

extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}