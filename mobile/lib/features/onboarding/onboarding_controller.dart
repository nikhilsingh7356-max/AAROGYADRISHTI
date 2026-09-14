/// Onboarding state machine (goals -> routine -> health permission).
library;

import 'package:flutter/foundation.dart';

import '../../models/app_enums.dart';

class OnboardingController extends ChangeNotifier {
  int _step = 0;
  int get step => _step;
  bool get isLast => _step == 2;

  // Goal (single-select, mirrors backend `primary_goal`). One is required.
  PrimaryGoal? _goal;
  PrimaryGoal? get goal => _goal;

  // Daily routine (all optional).
  double? _sleepHours;
  ActivityLevel? _activityLevel;
  WaterIntake? _waterIntake;
  MoodLevel? _stressLevel;

  double? get sleepHours => _sleepHours;
  ActivityLevel? get activityLevel => _activityLevel;
  WaterIntake? get waterIntake => _waterIntake;
  MoodLevel? get stressLevel => _stressLevel;

  // Health permissions (empty = manual only).
  final List<HealthDataTypeWrapper> _selectedHealth = [];
  List<HealthDataTypeWrapper> get selectedHealth => List.unmodifiable(_selectedHealth);

  bool get goalsSelected => _goal != null;

  bool get routineValid {
    return _activityLevel != null || _sleepHours != null || _waterIntake != null || _stressLevel != null;
  }

  bool get readyToFinish => goalsSelected;

  /// Toggle a goal; only one can be selected (tapping again clears it).
  void toggleGoal(PrimaryGoal goal) {
    _goal = _goal == goal ? null : goal;
    notifyListeners();
  }

  void setGoal(PrimaryGoal? goal) {
    _goal = goal;
    notifyListeners();
  }

  void setRoutine({
    double? sleepHours,
    ActivityLevel? activityLevel,
    WaterIntake? waterIntake,
    MoodLevel? stressLevel,
  }) {
    _sleepHours = sleepHours ?? _sleepHours;
    _activityLevel = activityLevel ?? _activityLevel;
    _waterIntake = waterIntake ?? _waterIntake;
    _stressLevel = stressLevel ?? _stressLevel;
    notifyListeners();
  }

  void setHealthSelection(List<HealthDataTypeWrapper> types) {
    _selectedHealth
      ..clear()
      ..addAll(types);
    notifyListeners();
  }

  void next() {
    if (_step < 2) {
      _step += 1;
      notifyListeners();
    }
  }

  void back() {
    if (_step > 0) {
      _step -= 1;
      notifyListeners();
    }
  }
}

/// Value-object wrapper (data type + permission granted flag) so the UI can
/// show what the user actually approved with Health Connect.
class HealthDataTypeWrapper {
  final dynamic type;
  final String title;
  final String description;
  final bool granted;

  const HealthDataTypeWrapper({required this.type, required this.title, required this.description, this.granted = false});
}