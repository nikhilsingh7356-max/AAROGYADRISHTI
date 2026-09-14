/// Home dashboard - today's status, check-in CTA, baseline progress,
/// next action and weekly snapshot. All numbers come from the backend
/// (`/dashboard/today`, `/coach/next-action`, `/coach/weekly-summary`).
///
/// NULL values are rendered as "Not logged" - never as zero.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/app_enums.dart';
import '../../models/coach.dart';
import '../../models/dashboard.dart';
import '../../models/health_data.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/coach_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/health_connect_service.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/error_message.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/section_header.dart';
import '../../app.dart';
import '../checkin/checkin_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenProfile});

  /// Invoked when the user taps the profile header avatar.
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DashboardData? _dashboard;
  NextAction? _nextAction;
  WeeklySummary? _weekly;
  bool _loading = true;
  bool _weeklyLoading = true;
  bool _refreshingHealth = false;
  String? _error;
  String? _healthNote;

  @override
  void initState() {
    super.initState();
    _load();
    _syncHealth();
    _loadCoachExtras();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _dashboard == null;
      _error = null;
    });
    try {
      final svc = AppServices.instance;
      final data = await HealthRepository(svc.api).dashboardToday();
      if (mounted) setState(() => _dashboard = data);
    } catch (_) {
      if (mounted && _dashboard == null) {
        setState(() => _error = AppStrings.apiUnavailable);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCoachExtras() async {
    setState(() => _weeklyLoading = _weekly == null);
    try {
      final repo = CoachRepository(AppServices.instance.api);
      final results = await Future.wait([
        repo.nextAction(),
        repo.weeklySummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _nextAction = results[0] as NextAction;
        _weekly = results[1] as WeeklySummary;
        _weeklyLoading = false;
      });
    } catch (_) {
      // Coach extras are supplementary; the dashboard still renders.
      if (mounted) setState(() => _weeklyLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadCoachExtras()]);
  }

  /// Best-effort Health Connect sync when a backend connection exists.
  Future<void> _syncHealth() async {
    try {
      setState(() => _refreshingHealth = true);
      final svc = AppServices.instance;
      final healthRepo = HealthRepository(svc.api);
      final conn = await healthRepo.getStatus();
      if (!conn.isConnected) {
        if (mounted) {
          setState(() => _healthNote = 'connect');
        }
        return;
      }

      final health = HealthConnectService.instance;
      final availability = health.availability ?? await health.setup();
      if (availability != HealthConnectAvailability.supported) return;

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final dayData = await health.readDay(midnight);
      if (dayData.steps == null &&
          dayData.activeMinutes == null &&
          dayData.sleepMinutes == null) {
        return;
      }

      await healthRepo.sync(
        steps: dayData.steps,
        activeMinutes: dayData.activeMinutes,
        sleepMinutes: dayData.sleepMinutes,
        date: AppDateUtils.todayIso(),
      );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _healthNote = 'sync');
    } finally {
      if (mounted) setState(() => _refreshingHealth = false);
    }
  }

  Future<void> _openCheckin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckinScreen()),
    );
    if (mounted) _load();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return AppStrings.morningHello;
    if (h < 17) return AppStrings.afternoonHello;
    return AppStrings.eveningHello;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final s = _dashboard?.summary;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                  child: _header(scheme, auth, s)),
            ),
          ),
          if (_healthNote == 'connect')
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HealthNoteCard(
                  icon: Icons.watch_rounded,
                  message:
                      'Health Connect is available but not linked yet. Link it from your profile to auto-fill steps, sleep and activity.',
                  actionLabel: 'Link later',
                ),
              ),
            ),
          if (_healthNote == 'sync')
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HealthNoteCard(
                  icon: Icons.sync_problem_rounded,
                  message:
                      'A Health Connect sync failed. Your manual entries are safe - we will retry next time.',
                  actionLabel: 'Dismiss',
                  onAction: () => setState(() => _healthNote = null),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _TodayCard(
                summary: s,
                hasData: _dashboard?.hasData ?? false,
                loading: _loading,
                onCheckin: _openCheckin,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: AppStrings.todayOverview,
                subtitle: _dashboard?.hasData == true
                    ? 'Data for ${AppDateUtils.fullDay(s!.date)}'
                    : 'Your day at a glance',
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  MetricCard(
                    title: 'Sleep',
                    value: s?.sleepHours?.toStringAsFixed(1) ?? '',
                    unit: 'h',
                    icon: Icons.bedtime_outlined,
                    isEmpty: s?.sleepHours == null,
                    status: SleepQuality.fromWire(s?.sleepQuality)?.label,
                  ),
                  MetricCard(
                    title: 'Steps',
                    value: s?.steps != null ? '${s!.steps}' : '',
                    icon: Icons.directions_walk_rounded,
                    isEmpty: s?.steps == null,
                    status: _stepsStatus(s?.steps),
                  ),
                  MetricCard(
                    title: 'Activity',
                    value: s?.activeMinutes?.toString() ?? '',
                    unit: 'min',
                    icon: Icons.directions_run_rounded,
                    isEmpty: s?.activeMinutes == null,
                  ),
                  MetricCard(
                    title: 'Energy',
                    value: s?.energy?.toString() ?? '',
                    unit: '/10',
                    icon: Icons.bolt_rounded,
                    isEmpty: s?.energy == null,
                  ),
                  MetricCard(
                    title: 'Stress',
                    value: s?.stress?.toString() ?? '',
                    unit: '/5',
                    icon: Icons.spa_outlined,
                    isEmpty: s?.stress == null,
                  ),
                  MetricCard(
                    title: 'Hydration',
                    value: s?.waterLiters != null
                        ? '${(s!.waterLiters! * 4).round()}'
                        : '',
                    unit: 'cups',
                    icon: Icons.water_drop_outlined,
                    isEmpty: s?.waterLiters == null,
                  ),
                ],
              ),
            ),
          if (!_loading && _error == null && _dashboard != null) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: ProgressCard(baseline: _dashboard!.baseline),
              ),
            ),
            if (_nextAction != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _NextActionCard(action: _nextAction!),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _WeeklySnapshotCard(
                  weekly: _weekly,
                  loading: _weeklyLoading,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.history_rounded,
                            size: 20, color: scheme.primary),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Browse past check-ins',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(height: appBottomBarClearance)),
        ],
      ),
    );
  }

  Widget _header(ColorScheme scheme, AuthProvider auth, DashboardSummary? s) {
    final user = auth.user;
    final firstName =
        (user?.name ?? user?.email ?? 'there').split(' ').first;
    final today = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: widget.onOpenProfile,
          borderRadius: BorderRadius.circular(999),
          child: CircleAvatar(
            radius: 21,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 2),
              Text(
                '${AppDateUtils.fullDay(today)} \u00b7 Let\u2019s see how your habits are looking',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (_refreshingHealth)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    );
  }

  String? _stepsStatus(int? steps) {
    if (steps == null) return null;
    return steps >= 8000 ? 'Good' : steps >= 5000 ? 'Moderate' : 'Low';
  }
}

class _HealthNoteCard extends StatelessWidget {
  const _HealthNoteCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: onAction ?? () {},
            child: Text(actionLabel, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.summary,
    required this.hasData,
    required this.loading,
    required this.onCheckin,
  });

  final DashboardSummary? summary;
  final bool hasData;
  final bool loading;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkedIn = hasData;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  checkedIn ? 'You checked in today' : 'How was your day?',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            checkedIn
                ? 'Nice work. You can still update your entries anytime.'
                : 'A one-minute check-in keeps your patterns accurate.',
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: checkedIn ? 'Update check-in' : 'Complete check-in',
              icon: Icons.edit_note_rounded,
              onPressed: onCheckin,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.action});

  final NextAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () {
        // The coach tab owns this flow; surfaced from home for convenience.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action.reason.isEmpty
              ? action.heading
              : action.reason)),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.explore_rounded, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.heading,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                if (action.reason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    action.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySnapshotCard extends StatelessWidget {
  const _WeeklySnapshotCard({required this.weekly, required this.loading});

  final WeeklySummary? weekly;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Last 7 days',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (weekly == null)
            Text(
              'Weekly summary is not available right now.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            )
          else ...[
            Row(
              children: [
                _stat(scheme, '${weekly!.daysTracked}',
                    'day${weekly!.daysTracked == 1 ? '' : 's'} tracked'),
                _stat(scheme,
                    '${(weekly!.completionRate * 100).round()}%', 'completion'),
                _stat(scheme, '${weekly!.experimentsCompletedTotal}',
                    'experiments done'),
              ],
            ),
            if (weekly!.narrative.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                weekly!.narrative,
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stat(ColorScheme scheme, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
