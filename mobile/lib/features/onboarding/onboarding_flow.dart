/// Root onboarding flow (3 pages, never shows the navigation bar).
///
/// Steps: goal (single-select) -> daily routine (optional) -> health connect.
/// On finish the profile is posted with `onboarding_completed = true`.
/// Completion is signalled to the host via `onComplete`; no navigation is
/// performed here (the root gate swaps the tree once the flag flips).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../widgets/primary_button.dart';
import '../../app.dart';
import 'goal_screen.dart';
import 'health_permission_screen.dart';
import 'onboarding_controller.dart';
import 'routine_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  /// Called after the server confirms onboarding_completed.
  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingController _ctrl;

@override
  void initState() {
    super.initState();
    _ctrl = OnboardingController();
    _ctrl.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_ctrl.goalsSelected) return;
    try {
      final profileRepo = AppServices.instance.profileRepository;
      await profileRepo.update(
        primaryGoalWire: _ctrl.goal!.wire,
        activityLevelWire: _ctrl.activityLevel?.wire,
        onboardingCompleted: true,
      );
      widget.onComplete();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.somethingWentWrong),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChangeNotifierProvider<OnboardingController>.value(
      value: _ctrl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _ctrl.step > 0 ? _ctrl.back : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    Text(
                      'Step ${_ctrl.step + 1} of 3',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: IndexedStack(
                    key: ValueKey(_ctrl.step),
                    index: _ctrl.step,
                    children: const [
                      GoalScreen(),
                      RoutineScreen(),
                      HealthPermissionScreen(),
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;
    final showFinish = _ctrl.step == 2;
    final canContinue = _ctrl.step == 0 ? _ctrl.goalsSelected : true;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _ctrl.step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          if (!showFinish)
            PrimaryButton(
              label: 'Continue',
              icon: canContinue ? Icons.arrow_forward_rounded : null,
              onPressed: canContinue ? _ctrl.next : null,
            )
          else
            PrimaryButton(
              label: 'Start my journey',
              icon: Icons.arrow_forward_rounded,
              onPressed: _finish,
            ),
        ],
      ),
    );
  }
}