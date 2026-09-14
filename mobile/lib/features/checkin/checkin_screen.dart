/// Daily check-in - guided, low-friction lifestyle logging.
///
/// Covers every backend daily-log field (sleep, movement, hydration, food,
/// digital habits, caffeine, wellbeing). Values the user leaves blank are
/// sent as JSON `null` - never as zero - matching the backend's
/// "missing stays missing" data rule.
///
/// Entry points: the Check-in bottom tab (via [CheckinTab]) and a pushed
/// route (via [CheckinScreen]) from Home.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/app_enums.dart';
import '../../models/daily_log.dart';
import '../../repositories/daily_log_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/error_message.dart';
import '../../widgets/primary_button.dart';
import '../../app.dart';

class CheckinTab extends StatelessWidget {
  const CheckinTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: CheckinBody(scrollable: true)),
    );
  }
}

class CheckinScreen extends StatelessWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.checkInTitle)),
      body: const SafeArea(child: CheckinBody()),
    );
  }
}

class CheckinBody extends StatefulWidget {
  const CheckinBody({super.key, this.scrollable = false});

  /// Extra bottom padding when hosted inside a tab (no app bar).
  final bool scrollable;

  @override
  State<CheckinBody> createState() => _CheckinBodyState();
}

class _CheckinBodyState extends State<CheckinBody> {
  // Wellbeing
  MoodLevel? _mood;
  int? _energy; // 1..10
  int? _stress; // 1..5

  // Sleep
  double? _sleepHours;
  SleepQuality? _sleepQuality;

  // Movement
  int? _steps;
  int? _activeMinutes;
  ExerciseLevel? _exercise;

  // Hydration (null = not logged)
  double? _waterLiters;

  // Food
  MealQuality? _meal;

  // Digital habits
  int? _screenTimeMinutes;
  bool? _lateNightScreen;

  // Caffeine
  CaffeineLevel? _caffeine;

  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  final _stepsCtrl = TextEditingController();
  final _activeCtrl = TextEditingController();
  final _screenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    _stepsCtrl.dispose();
    _activeCtrl.dispose();
    _screenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    try {
      final repo = DailyLogRepository(AppServices.instance.api);
      final existing = await repo.getByDate(AppDateUtils.todayIso());
      if (existing != null && mounted) _apply(existing);
    } catch (_) {
      // Fresh check-in otherwise.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(DailyLog log) {
    _mood = log.mood;
    _energy = log.energy;
    _stress = log.stress;
    _sleepHours = log.sleepHours;
    _sleepQuality = log.sleepQuality;
    _steps = log.steps;
    _activeMinutes = log.activeMinutes;
    _exercise = log.exerciseLevel;
    _waterLiters = log.waterLiters;
    _meal = log.mealQuality;
    _screenTimeMinutes = log.screenTimeMinutes;
    _lateNightScreen = log.lateNightScreen;
    _caffeine = log.caffeine;
    _stepsCtrl.text = _steps?.toString() ?? '';
    _activeCtrl.text = _activeMinutes?.toString() ?? '';
    _screenCtrl.text = _screenTimeMinutes?.toString() ?? '';
  }

  Map<String, dynamic> _body() {
    // Every absent value stays null - the backend preserves missing fields.
    return {
      'date': AppDateUtils.todayIso(),
      'mood': _mood?.wire,
      'sleep_hours': _sleepHours,
      'sleep_quality': _sleepQuality?.wire,
      'steps': _steps,
      'active_minutes': _activeMinutes,
      'exercise_level': _exercise?.wire,
      'exercise_minutes': _exercise?.minutes,
      'water_liters': _waterLiters,
      'meal_quality': _meal?.wire,
      'screen_time_minutes': _screenTimeMinutes,
      'late_night_screen': _lateNightScreen,
      'caffeine': _caffeine?.wire,
      'energy': _energy,
      'stress': _stress,
      'source': 'manual',
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = _body();
    final today = AppDateUtils.todayIso();

    try {
      final repo = DailyLogRepository(AppServices.instance.api);
      final existing = await repo.getByDate(today);
      if (existing != null) {
        body.remove('date');
        await repo.update(today, body);
      } else {
        await repo.create(body);
      }
      if (mounted) setState(() => _saved = true);
    } on RequestFailedException catch (e) {
      if (mounted) {
        setState(() => _error =
            e.code == 'conflict' ? AppStrings.duplicateCheckIn : e.message);
      }
    } on NetworkException {
      if (mounted) setState(() => _error = AppStrings.noInternet);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_saved) {
      return _Confirmation(onDone: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _saved = false);
        }
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 12, 20, widget.scrollable ? 140 : 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _wellbeingSection(scheme),
                _sleepSection(scheme),
                _movementSection(scheme),
                _hydrationSection(scheme),
                _foodSection(scheme),
                _digitalSection(scheme),
                _caffeineSection(scheme),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  ErrorMessage(_error!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, 10, 20, 14 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.96),
              border:
                  Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: AppStrings.saveCheckIn,
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Section builders ----------------------------------------------------

  Widget _wellbeingSection(ColorScheme scheme) {
    return _Section(
      title: 'How was your day?',
      icon: Icons.mood_rounded,
      children: [
        Text(AppStrings.moodQuestion,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        _moodPicker(scheme),
        const SizedBox(height: 16),
        _sliderField(
          label: 'Energy',
          hint: 'How energetic did you feel? (1\u201310)',
          value: _energy?.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          unit: '/10',
          onChanged: (v) => setState(() => _energy = v.round()),
          onClear: () => setState(() => _energy = null),
        ),
        const SizedBox(height: 14),
        _sliderField(
          label: 'Stress',
          hint: 'How stressed did you feel? (1\u20135)',
          value: _stress?.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          unit: '/5',
          onChanged: (v) => setState(() => _stress = v.round()),
          onClear: () => setState(() => _stress = null),
        ),
      ],
    );
  }

  Widget _sleepSection(ColorScheme scheme) {
    return _Section(
      title: 'Sleep',
      icon: Icons.bedtime_rounded,
      children: [
        _sliderField(
          label: 'Hours of sleep',
          hint: 'Optional \u2014 clear to leave this out for today',
          value: _sleepHours,
          min: 0,
          max: 12,
          divisions: 24,
          unit: 'h',
          fractionDigits: 1,
          onChanged: (v) =>
              setState(() => _sleepHours = (v * 2).roundToDouble() / 2),
          onClear: () => setState(() => _sleepHours = null),
        ),
        if (_sleepHours != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: SleepQuality.values
                .map((q) => ChoiceChip(
                      label: Text(q.label),
                      selected: _sleepQuality == q,
                      onSelected: (_) => setState(
                          () => _sleepQuality = _sleepQuality == q ? null : q),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _movementSection(ColorScheme scheme) {
    return _Section(
      title: 'Movement',
      icon: Icons.directions_run_rounded,
      subtitle: 'Optional \u2014 Health Connect can fill this in automatically',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _stepsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_DigitsOnlyFormatter(max: 6)],
                decoration: const InputDecoration(
                  labelText: 'Steps',
                  hintText: 'e.g. 8000',
                  prefixIcon: Icon(Icons.directions_walk_rounded),
                ),
                onChanged: (v) =>
                    setState(() => _steps = int.tryParse(v.trim())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _activeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_DigitsOnlyFormatter(max: 4)],
                decoration: const InputDecoration(
                  labelText: 'Active minutes',
                  hintText: 'e.g. 30',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                onChanged: (v) =>
                    setState(() => _activeMinutes = int.tryParse(v.trim())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Exercise level',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExerciseLevel.values
              .map((e) => ChoiceChip(
                    label: Text(e.label),
                    selected: _exercise == e,
                    onSelected: (_) =>
                        setState(() => _exercise = _exercise == e ? null : e),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _hydrationSection(ColorScheme scheme) {
    final cups =
        _waterLiters == null ? null : (_waterLiters! / 0.25).round();
    return _Section(
      title: 'Hydration',
      icon: Icons.water_drop_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cups == null
                    ? 'Not logged yet'
                    : '$cups cup${cups == 1 ? '' : 's'} \u00b7 ${_waterLiters!.toStringAsFixed(2)} L',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Remove a cup',
              onPressed: cups == null || cups <= 0
                  ? null
                  : () =>
                      setState(() => _waterLiters = ((cups! - 1) * 0.25)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: 'Add a cup (250 ml)',
              onPressed: () => setState(() {
                final current = cups ?? 0;
                _waterLiters = current >= 16 ? 4.0 : (current + 1) * 0.25;
              }),
              icon: const Icon(Icons.add_circle, color: AppColors.deepTeal),
            ),
            if (cups != null)
              TextButton(
                onPressed: () => setState(() => _waterLiters = null),
                child: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _foodSection(ColorScheme scheme) {
    return _Section(
      title: 'Food',
      icon: Icons.restaurant_rounded,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealQuality.values
              .map((m) => ChoiceChip(
                    label: Text(m.label),
                    selected: _meal == m,
                    onSelected: (_) =>
                        setState(() => _meal = _meal == m ? null : m),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _digitalSection(ColorScheme scheme) {
    return _Section(
      title: 'Digital habits',
      icon: Icons.phone_android_rounded,
      children: [
        TextField(
          controller: _screenCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [_DigitsOnlyFormatter(max: 4)],
          decoration: const InputDecoration(
            labelText: 'Screen time (minutes)',
            hintText: 'e.g. 240',
            prefixIcon: Icon(Icons.smartphone_rounded),
          ),
          onChanged: (v) =>
              setState(() => _screenTimeMinutes = int.tryParse(v.trim())),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Used screens late at night'),
          subtitle: const Text('Only switch on if this actually happened'),
          value: _lateNightScreen ?? false,
          onChanged: (v) => setState(() => _lateNightScreen = v),
        ),
      ],
    );
  }

  Widget _caffeineSection(ColorScheme scheme) {
    return _Section(
      title: 'Caffeine',
      icon: Icons.coffee_rounded,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CaffeineLevel.values
              .map((c) => ChoiceChip(
                    label: Text(c.label),
                    selected: _caffeine == c,
                    onSelected: (_) =>
                        setState(() => _caffeine = _caffeine == c ? null : c),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // --- Controls ------------------------------------------------------------

  Widget _sliderField({
    required String label,
    required String hint,
    required double? value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required VoidCallback onClear,
    int fractionDigits = 0,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final display =
        value == null ? 'Not logged' : value.toStringAsFixed(fractionDigits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Text(
              value == null ? display : '$display $unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: value == null ? scheme.outline : scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            if (value != null) _ClearButton(onClear: onClear),
          ],
        ),
        Slider(
          value: (value ?? min).clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: value == null ? null : '$display $unit',
          onChanged: onChanged,
        ),
        Text(hint, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _moodPicker(ColorScheme scheme) {
    const moods = <(MoodLevel, IconData)>[
      (MoodLevel.veryLow, Icons.sentiment_very_dissatisfied),
      (MoodLevel.low, Icons.sentiment_dissatisfied),
      (MoodLevel.okay, Icons.sentiment_neutral),
      (MoodLevel.good, Icons.sentiment_satisfied),
      (MoodLevel.great, Icons.sentiment_very_satisfied),
    ];
    return Row(
      children: [
        for (final (mood, icon) in moods) ...[
          Expanded(
            child: _MoodButton(
              icon: icon,
              label: mood.label,
              selected: _mood == mood,
              onTap: () => setState(() => _mood = _mood == mood ? null : mood),
            ),
          ),
          if (mood != moods.last.$1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Section wrapper with consistent header.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Clear value (leave unset for today)',
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.cancel_outlined,
              size: 18, color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  size: 56, color: scheme.primary),
            ),
            const SizedBox(height: 22),
            Text(
              AppStrings.checkInSaved,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.checkinConfirmBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, height: 1.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Done',
                icon: Icons.arrow_back_rounded,
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitsOnlyFormatter extends TextInputFormatter {
  const _DigitsOnlyFormatter({required this.max});

  final int max;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > max) return oldValue;
    return newValue.copyWith(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
