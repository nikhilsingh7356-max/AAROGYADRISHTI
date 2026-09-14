/// Profile / Settings screen.
///
/// Sections: avatar + name/email header, My Goals (editable),
/// Connected Health Data, Privacy, Notifications, Preferences,
/// About AarogyaDrishti, Logout, and Delete Account placeholder.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../models/app_enums.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/primary_button.dart';
import '../../app.dart';
import '../auth/welcome_screen.dart';
import 'goals_edit_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  List<PrimaryGoal> _goals = const [];
  bool _loadingGoals = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final profile = await AppServices.instance.profileRepository.get();
      final goal = PrimaryGoal.fromWire(profile.primaryGoalWire);
      if (mounted) {
        setState(() {
          _goals = [if (goal != null) goal];
          _loadingGoals = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGoals = false);
    }
  }

  Future<void> _openGoals() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsEditScreen()),
    );
    _loadGoals();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.name;
    final email = auth.user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Avatar + name + email header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      (name != null && name.isNotEmpty) ? name[0].toUpperCase() : email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name ?? email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (name != null && name.isNotEmpty && email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // My Goals section
          _SectionHeader(title: AppStrings.myGoals),
          const SizedBox(height: 8),
          _GoalsTile(
            goals: _goals,
            loading: _loadingGoals,
            onTap: _openGoals,
          ),
          const SizedBox(height: 20),

          // Connected Health Data
          _SectionHeader(title: AppStrings.connectedHealthData),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Health Connect',
            subtitle: 'Manage data source permissions',
            onTap: () => _showPlaceholder(context, 'Health source settings coming soon.'),
          ),
          const SizedBox(height: 20),

          // Privacy
          _SectionHeader(title: AppStrings.privacy),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.security_outlined,
            title: 'Permissions & consent',
            subtitle: 'Review and revoke health data access',
            onTap: () => _showPlaceholder(context, 'Privacy settings coming soon.'),
          ),
          const SizedBox(height: 20),

          // Notifications
          _SectionHeader(title: AppStrings.notifications),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notification preferences',
            subtitle: 'Manage reminders and alerts',
            onTap: () => _showPlaceholder(context, 'Notification settings coming soon.'),
          ),
          const SizedBox(height: 20),

          // Preferences
          _SectionHeader(title: AppStrings.preferences),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.tune_outlined,
            title: 'App preferences',
            subtitle: 'Language and display settings',
            onTap: () => _showPlaceholder(context, 'Preference settings coming soon.'),
          ),
          const SizedBox(height: 20),

          // About
          _SectionHeader(title: AppStrings.aboutApp),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: AppStrings.appName,
            subtitle: AppStrings.tagline,
            onTap: () => _showAbout(context),
          ),
          const SizedBox(height: 28),

          // Logout
          PrimaryButton(
            label: AppStrings.logout,
            icon: Icons.logout_rounded,
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 12),

          // Delete account (placeholder)
          Center(
            child: TextButton(
              onPressed: () => _confirmDelete(context),
              child: Text(
                AppStrings.deleteAccount,
                style: TextStyle(color: scheme.error, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showAbout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const LogoMark(size: 42),
        title: const Text(AppStrings.appName, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              'AarogyaDrishti helps you track daily lifestyle habits, discover personal '
              'patterns, and build healthier routines \u2014 one small step at a time.\n\n'
              'Your data is yours. We never fabricate trends or make medical claims.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'This action is not yet available in Phase 1. It will be implemented in a future update.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _GoalsTile extends StatelessWidget {
  const _GoalsTile({required this.goals, required this.loading, required this.onTap});

  final List<PrimaryGoal> goals;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.myGoals,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  TextButton(
                    onPressed: onTap,
                    child: Text(AppStrings.edit, style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (loading)
                SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (goals.isEmpty)
                Text(
                  AppStrings.noGoalsSelected,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: goals.map((g) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(g.icon, size: 13, color: scheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          g.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}