/// Profile / Settings screen.
///
/// Shows only capabilities the backend actually supports:
/// account (name/email/verification), personal profile (goal, age group,
/// gender, height, weight, activity level), Health Connect management,
/// consent status, about and logout. No placeholder settings.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../models/app_enums.dart';
import '../../models/health_data.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/health_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/badges.dart';
import '../../widgets/primary_button.dart';
import '../auth/welcome_screen.dart';
import '../health_connect/health_connect_screen.dart';
import 'goals_edit_screen.dart';
import 'settings/app_preferences_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/privacy_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  UserProfile? _profile;
  HealthConnectionState? _health;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = AppServices.instance.api;
    try {
      final profile = await ProfileRepository(api).get();
      HealthConnectionState? health;
      try {
        health = await HealthRepository(api).getStatus();
      } on ApiException catch (_) {
        health = null; // Health status is secondary; never blocks the page.
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _health = health;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppStrings.somethingWentWrong;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final name = _profile?.name ?? user?.name;
    final email = user?.email ?? '';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _header(scheme, name, email, user?.emailVerified ?? false),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Personal profile'),
            const SizedBox(height: 8),
            _profileCard(),
            const SizedBox(height: 20),
            _SectionHeader(title: AppStrings.connectedHealthData),
            const SizedBox(height: 8),
            _healthTile(scheme),
            const SizedBox(height: 20),
            _SectionHeader(title: AppStrings.privacySettings),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.shield_outlined,
              title: 'Data consent',
              subtitle: 'Track, review and change what your data is used for',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: 'App settings'),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.palette_outlined,
              title: AppStrings.appearance,
              subtitle: AppStrings.appearanceSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppPreferencesScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.notifications_outlined,
              title: AppStrings.notifications,
              subtitle: AppStrings.notificationsSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: AppStrings.aboutApp),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.info_outline_rounded,
              title: AppStrings.appName,
              subtitle: '${AppConstants.tagline} \u00b7 v${AppConstants.appVersion}',
              onTap: _showAbout,
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _confirmDeleteAccount,
              icon: Icon(Icons.delete_forever_outlined,
                  color: scheme.error, size: 20),
              label: Text(
                'Delete account',
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme, String? name, String email, bool verified) {
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : '?';
    return Column(
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
            child: Text(initial,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800, color: scheme.primary)),
          ),
        ),
        const SizedBox(height: 12),
        Text(name ?? email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (name != null && name.isNotEmpty && email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(email,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 10),
        StatusBadge(
          label: verified ? 'Email verified' : 'Email not verified',
          color: verified ? scheme.primary : scheme.tertiary,
          icon: verified ? Icons.verified_outlined : Icons.mark_email_unread_outlined,
        ),
      ],
    );
  }

  Widget _profileCard() {
    final p = _profile;
    final goal = p?.primaryGoal;
    final activity = p?.activityLevel;
    String heightWeight() {
      final h = p?.heightCm;
      final w = p?.weightKg;
      if (h == null && w == null) return 'Not set';
      final parts = [
        if (h != null) '${_fmt(h)} cm',
        if (w != null) '${_fmt(w)} kg',
      ];
      return parts.join(' \u00b7 ');
    }

    String ageGender() {
      final labels = <String>[];
      final age = p?.ageGroup;
      if (age != null) labels.add(_ageLabel(age));
      final g = p?.gender;
      if (g != null) labels.add(_genderLabel(g));
      return labels.isEmpty ? 'Not set' : labels.join(' \u00b7 ');
    }

    return AppCard(
      child: Column(
        children: [
          _Row(
            icon: Icons.flag_outlined,
            label: 'Primary goal',
            value: goal?.label ?? 'Not set',
            onTap: _openGoals,
          ),
          const Divider(height: 24),
          _Row(
            icon: Icons.cake_outlined,
            label: 'Age group \u00b7 Gender',
            value: ageGender(),
            onTap: _editProfile,
          ),
          const Divider(height: 24),
          _Row(
            icon: Icons.monitor_weight_outlined,
            label: 'Height \u00b7 Weight',
            value: heightWeight(),
            onTap: _editProfile,
          ),
          const Divider(height: 24),
          _Row(
            icon: Icons.directions_run_rounded,
            label: 'Activity level',
            value: activity?.label ?? 'Not set',
            onTap: _editProfile,
          ),
        ],
      ),
    );
  }

  Widget _healthTile(ColorScheme scheme) {
    final c = _health;
    final connected = c?.isConnected ?? false;
    final subtitle = connected
        ? 'Connected \u00b7 steps, sleep and activity'
        : 'Not connected';
    return _Tile(
      icon: Icons.health_and_safety_outlined,
      title: 'Health Connect',
      subtitle: subtitle,
      badge: StatusBadge(
        label: connected ? 'Connected' : 'Off',
        color: connected ? scheme.primary : scheme.onSurfaceVariant,
        icon: connected ? Icons.verified_rounded : Icons.link_off_rounded,
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HealthConnectScreen()),
        );
        _load();
      },
    );
  }

  Future<void> _openGoals() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsEditScreen()),
    );
    _load();
  }

  Future<void> _editProfile() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileEditorSheet(initial: _profile),
    );
    if (changed == true) _load();
  }

  void _showAbout() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const LogoMark(size: 42),
        title: const Text(AppStrings.appName, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppConstants.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(
              'AarogyaDrishti helps you track daily lifestyle habits, discover personal '
              'patterns, and build healthier routines \u2014 one small step at a time.\n\n'
              'Your data is yours. Observations describe your own history and never '
              'diagnose, predict or prescribe anything medical.',
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

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 40),
        title: const Text(AppStrings.deleteAccountConfirmTitle,
            textAlign: TextAlign.center),
        content: Text(
          AppStrings.deleteAccountConfirmBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    try {
      await auth.deleteAccount();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not delete your account. Check your connection and try again.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.deleteAccountDone)),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _ageLabel(String wire) => switch (wire) {
        'under_18' => 'Under 18',
        '18_24' => '18\u201324',
        '25_34' => '25\u201334',
        '35_44' => '35\u201344',
        '45_54' => '45\u201354',
        '55_64' => '55\u201364',
        '65_plus' => '65+',
        _ => wire,
      };

  static String _genderLabel(String wire) => switch (wire) {
        'female' => 'Female',
        'male' => 'Male',
        'non_binary' => 'Non-binary',
        'prefer_not_to_say' => 'Prefer not to say',
        _ => wire,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.8,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
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
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editable personal-profile sheet. Only fields the user actually changed
/// are sent to PUT /profile (the backend ignores explicit nulls, so every
/// untouched field stays exactly as it is on the server).
class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet({this.initial});

  final UserProfile? initial;

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  static const _ageGroups = [
    ('under_18', 'Under 18'),
    ('18_24', '18\u201324'),
    ('25_34', '25\u201334'),
    ('35_44', '35\u201344'),
    ('45_54', '45\u201354'),
    ('55_64', '55\u201364'),
    ('65_plus', '65+'),
  ];
  static const _genders = [
    ('female', 'Female'),
    ('male', 'Male'),
    ('non_binary', 'Non-binary'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  late final TextEditingController _height;
  late final TextEditingController _weight;
  String? _age;
  String? _gender;
  ActivityLevel? _activity;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _height = TextEditingController(text: p?.heightCm?.toString() ?? '');
    _weight = TextEditingController(text: p?.weightKg?.toString() ?? '');
    _age = p?.ageGroup;
    _gender = p?.gender;
    _activity = p?.activityLevel;
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c, {required double min, required double max}) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    if (v == null || v < min || v > max) return null;
    return v;
  }

  Future<void> _save() async {
    final height = _parse(_height, min: 50, max: 300);
    final weight = _parse(_weight, min: 20, max: 500);
    if (_height.text.trim().isNotEmpty && height == null) {
      setState(() => _error = 'Height must be between 50 and 300 cm.');
      return;
    }
    if (_weight.text.trim().isNotEmpty && weight == null) {
      setState(() => _error = 'Weight must be between 20 and 500 kg.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileRepository(AppServices.instance.api).update(
        ageGroup: _age,
        gender: _gender,
        activityLevelWire: _activity?.wire,
        heightCm: height,
        weightKg: weight,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Leave anything unchanged you\'d rather keep as is.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 18),
              _pickerRow(
                label: 'Age group',
                items: _ageGroups,
                value: _age,
                onChanged: (v) => setState(() => _age = v),
              ),
              const SizedBox(height: 14),
              _pickerRow(
                label: 'Gender',
                items: _genders,
                value: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 14),
              _pickerRow(
                label: 'Activity level',
                items: [for (final a in ActivityLevel.values) (a.wire, a.label)],
                value: _activity?.wire,
                onChanged: (v) => setState(() => _activity = ActivityLevel.fromWire(v)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _height,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Height (cm)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save changes',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerRow({
    required String label,
    required List<(String, String)> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (w, l) in items)
              ChoiceChip(
                label: Text(l),
                selected: value == w,
                onSelected: (sel) => onChanged(sel ? w : null),
              ),
          ],
        ),
        if (value != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onChanged(null),
              child: Text('Clear $label',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }
}
