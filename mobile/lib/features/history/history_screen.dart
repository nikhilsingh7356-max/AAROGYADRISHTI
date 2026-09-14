/// History - chronological timeline of past daily check-ins.
///
/// Missing metrics render as an em-dash, never zero. Demo rows stay clearly
/// labelled.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/daily_log.dart';
import '../../repositories/daily_log_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/state_views.dart';
import '../../app.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DailyLog> _logs = [];
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
      if (mounted) setState(() => _logs = logs);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.historyTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load, offline: _offline)
              : _logs.isEmpty
                  ? const EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: AppStrings.historyEmpty,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) =>
                            _LogTile(log: _logs[index]),
                      ),
                    ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final DailyLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppDateUtils.fullDay(log.date),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
                if (log.isDemo)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Demo',
                        style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSecondaryContainer)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge('Sleep', log.sleepHours == null
                    ? '\u2014'
                    : '${log.sleepHours!.toStringAsFixed(1)} h', scheme),
                _badge('Steps', log.steps?.toString() ?? '\u2014', scheme),
                _badge('Energy', log.energy?.toString() ?? '\u2014', scheme),
                _badge('Stress', log.stress?.toString() ?? '\u2014', scheme),
                _badge('Mood', log.mood?.label ?? '\u2014', scheme),
                _badge('Food', log.mealQuality?.label ?? '\u2014', scheme),
                _badge('Water', log.waterLiters == null
                    ? '\u2014'
                    : '${log.waterLiters!.toStringAsFixed(2)} L', scheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, String value, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}
