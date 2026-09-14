/// OnboardingController unit tests (pure Dart state machine).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aarogyadrishti/features/onboarding/onboarding_controller.dart';
import 'package:aarogyadrishti/models/app_enums.dart';

void main() {
  group('steps', () {
    test('starts at 0 and advances to max 2', () {
      final c = OnboardingController();
      expect(c.step, 0);
      c.next();
      expect(c.step, 1);
      c.next();
      expect(c.step, 2);
      expect(c.isLast, isTrue);
      c.next();
      expect(c.step, 2);
    });

    test('back clamps at 0', () {
      final c = OnboardingController();
      c.back();
      expect(c.step, 0);
      c.next();
      c.back();
      expect(c.step, 0);
    });
  });

  group('goals (single-select)', () {
    test('toggleGoal selects one goal; tapping again clears it', () {
      final c = OnboardingController();
      expect(c.goalsSelected, isFalse);

      c.toggleGoal(PrimaryGoal.betterSleep);
      expect(c.goal, PrimaryGoal.betterSleep);
      expect(c.goalsSelected, isTrue);

      // Selecting a different goal replaces the previous one.
      c.toggleGoal(PrimaryGoal.hydration);
      expect(c.goal, PrimaryGoal.hydration);
      expect(c.goalsSelected, isTrue);

      // Deselect the goal -> nothing selected, continue disabled.
      c.toggleGoal(PrimaryGoal.hydration);
      expect(c.goal, isNull);
      expect(c.goalsSelected, isFalse);
    });

    test('setGoal replaces the selection and can clear it', () {
      final c = OnboardingController()..setGoal(PrimaryGoal.betterSleep);
      expect(c.goal, PrimaryGoal.betterSleep);
      c.setGoal(null);
      expect(c.goalsSelected, isFalse);
    });
  });

  group('health selection', () {
    test('setHealthSelection replaces selection', () {
      final c = OnboardingController();
      c.setHealthSelection([
        HealthDataTypeWrapper(type: 'steps', title: 'Steps', description: ''),
        HealthDataTypeWrapper(type: 'sleep', title: 'Sleep', description: ''),
      ]);
      expect(c.selectedHealth.length, 2);
      c.setHealthSelection(const []);
      expect(c.selectedHealth, isEmpty);
    });
  });
}