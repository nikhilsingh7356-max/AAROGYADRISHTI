/// Goal editing screen - single-select picker shared with onboarding.
///
/// The backend stores exactly one primary goal (`user_profiles.primary_goal`),
/// so the screen loads the server profile and saves the selection there
/// (no local preferences involved).
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../models/app_enums.dart';
import '../../repositories/profile_repository.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/selection_card.dart';
import '../../app.dart';

class GoalsEditScreen extends StatefulWidget {
  const GoalsEditScreen({super.key});

  @override
  State<GoalsEditScreen> createState() => _GoalsEditScreenState();
}

class _GoalsEditScreenState extends State<GoalsEditScreen> {
  PrimaryGoal? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final profile = await ProfileRepository(AppServices.instance.api).get();
      if (mounted) setState(() => _selected = PrimaryGoal.fromWire(profile.primaryGoalWire));
    } catch (_) {
      // Fresh selection otherwise.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(PrimaryGoal goal) {
    setState(() {
      _selected = identical(_selected, goal) ? null : goal;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final goal = _selected;
    if (goal == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ProfileRepository(AppServices.instance.api);
      await repo.update(primaryGoalWire: goal.wire);

      if (mounted) Navigator.of(context).pop(true);
    } on NetworkException {
      if (mounted) setState(() => _error = AppStrings.noInternet);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.myGoals),
        automaticallyImplyLeading: !_saving,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.goalTitle,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.goalSubtitle,
                          style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        for (final goal in PrimaryGoal.values) ...[
                          SelectionCard(
                            icon: goal.icon,
                            label: goal.label,
                            selected: identical(_selected, goal),
                            onTap: () => _toggle(goal),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: PrimaryButton(
                      label: 'Save goal',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _selected != null ? _save : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}