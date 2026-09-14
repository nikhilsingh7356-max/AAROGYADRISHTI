/// Insights - premium analytics over the user's own daily logs.
///
/// Everything shown is aggregated from real backend records only. Ranges
/// with fewer than two distinct days show the honest "not enough data"
/// state instead of a fabricated trend. NULL days appear as gaps.
library;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/daily_log.dart';
import '../../repositories/daily_log_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/habit_chart.dart';
import '../../widgets/state_views.dart';
import '../experiments/experiments_screen.dart';
import '../learning/learning_screen.dart';

/// Period choices for the trend window.
enum _Range {
  week('7 days', 7),
  fortnight('14 days', 14),
  month('30 days', 30);

  const _Range(this.label, this.days);
  final String label;
  final int days;
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<DailyLog> _logs = const [];
  _Range _range = _Range.week;
  bool _loading = true;
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });
    try {
      final repo = DailyLogRepository(AppServices.instance.api);
      final logs = await repo.list(limit: 90);
      if (mounted) setState(() => _logs = List.unmodifiable(logs.reversed));
    } on NetworkException {
      if (mounted) {
        setState(() {
          _error = AppStrings.noInternet;
          _offline = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DailyLog> get _window {
    final cutoff =
        DateTime.now().subtract(Duration(days: _range.days));
    return _logs.where((l) => !l.date.isBefore(cutoff)).toList();
  }

  /// Charts need at least two real points to show a trend honestly.
  bool get _hasEnough => _window.length >= 2;

  double? _avg(double? Function(DailyLog) pick) {
    final values = _window.map(pick).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.insightsTitle,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Patterns built only from the data you log.',
                          style: TextStyle(
                              fontSize: 15, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  for (final r in _Range.values) ...[
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) => setState(() => _range = r),
                    ),
                    if (r != _Range.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(
              child: _quickLinks(context),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorState(
                message: _error!,
                onRetry: _load,
                offline: _offline,
              ),
            )
          else if (!_hasEnough)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.show_chart_rounded,
                title: AppStrings.notEnoughData,
                message:
                    '${_window.length == 1 ? 'Only 1 check-in' : 'No check-ins'} in the last ${_range.label.toLowerCase()}. Keep logging daily and your personal patterns will appear here.',
              ),
            )
          else
            ..._chartState(scheme),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _quickLinks(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearningScreen()),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('What works for me',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExperimentsScreen()),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Experiments',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _chartState(ColorScheme scheme) {
    final window = _window;
    final avgSleep = _avg((l) => l.sleepHours);
    final avgEnergy = _avg((l) => l.energy?.toDouble());

    List<ChartPoint> points(double? Function(DailyLog) pick) {
      return window
          .map((l) => ChartPoint(label: l.displayDate, value: pick(l)))
          .toList();
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.bedtime_outlined,
                  label: 'Avg sleep',
                  value: avgSleep?.toStringAsFixed(1) ?? '\u2014',
                  unit: 'h',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.bolt_outlined,
                  label: 'Avg energy',
                  value: avgEnergy?.toStringAsFixed(1) ?? '\u2014',
                  unit: '/10',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.edit_calendar_rounded,
                  label: 'Check-ins',
                  value: '${window.length}',
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Days with no entry stay blank \u2014 nothing is invented.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        sliver: SliverToBoxAdapter(
          child: HabitChart(
            title: 'Sleep',
            icon: Icons.nightlight_round,
            points: points((l) => l.sleepHours),
            unit: 'h',
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: HabitChart(
            title: 'Steps',
            icon: Icons.directions_walk_rounded,
            points: points((l) => l.steps?.toDouble()),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: HabitChart(
            title: 'Energy',
            icon: Icons.bolt_rounded,
            points: points((l) => l.energy?.toDouble()),
            unit: '/10',
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: HabitChart(
            title: 'Stress',
            icon: Icons.spa_outlined,
            points: points((l) => l.stress?.toDouble()),
            unit: '/5',
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: HabitChart(
            title: 'Water',
            icon: Icons.water_drop_outlined,
            points: points((l) => l.waterLiters),
            unit: 'L',
          ),
        ),
      ),
    ];
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.05),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
