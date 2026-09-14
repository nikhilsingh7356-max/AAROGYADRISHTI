/// Onboarding goal selection screen (single-select).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../models/app_enums.dart';
import '../../widgets/selection_card.dart';
import 'onboarding_controller.dart';

class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OnboardingController>();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            AppStrings.goalTitle,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.goalSubtitle,
            style: TextStyle(fontSize: 14.5, height: 1.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: controller.goal == null
                ? Text(
                    AppStrings.goalSelectionHint,
                    key: const ValueKey('hint'),
                    style: TextStyle(fontSize: 13, color: scheme.error),
                  )
                : Text(
                    'Focus on ${controller.goal!.label}',
                    key: const ValueKey('count'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.primary),
                  ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: PrimaryGoal.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final goal = PrimaryGoal.values[i];
                return SelectionCard(
                  label: goal.label,
                  icon: goal.icon,
                  selected: controller.goal == goal,
                  onTap: () => controller.toggleGoal(goal),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}