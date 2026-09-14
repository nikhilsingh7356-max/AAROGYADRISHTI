/// App appearance preferences: system / light / dark theme toggle.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_strings.dart';

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final scheme = Theme.of(context).colorScheme;
    final current = themeCtrl.preference;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appearance)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            AppStrings.appearanceSubtitle,
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ...AppThemePreference.values.map((pref) {
            final selected = current == pref;
            final label = switch (pref) {
              AppThemePreference.system => AppStrings.themeFollowSystem,
              AppThemePreference.light => AppStrings.themeLight,
              AppThemePreference.dark => AppStrings.themeDark,
            };
            return _ThemeOption(
              label: label,
              selected: selected,
              onTap: () => themeCtrl.setPreference(pref),
            );
          }),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
