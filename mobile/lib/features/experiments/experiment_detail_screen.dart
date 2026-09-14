/// Experiment detail - running experiments log daily progress; completed
/// experiments show backend-computed results, evidence and the learning
/// candidate decision card.
///
/// Status handling is backend-authoritative ("active", "completed",
/// "cancelled").
library;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/experiment.dart';
import '../../repositories/experiment_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/badges.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/state_views.dart';

class ExperimentDetailScreen extends StatefulWidget {
  const ExperimentDetailScreen({super.key, required this.experimentId});

  final int experimentId;

  @override
  State<ExperimentDetailScreen> createState() => _ExperimentDetailScreenState();
}

class _ExperimentDetailScreenState extends State<ExperimentDetailScreen> {
  final ExperimentRepository _repo = ExperimentRepository(AppServices.instance.api);

  ExperimentDetail? _detail;
  ExperimentResult? _result;
  LearningCandidate? _candidate;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool _targetMet = true;
  final TextEditingController _notes = TextEditingController();
  int _energy = 7;
  int _stress = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repo.detail(widget.experimentId);
      ExperimentResult? result;
      LearningCandidate? candidate;
      if (detail.experiment.status != 'active') {
        final results = await Future.wait([
          _repo.result(widget.experimentId),
          _repo.learningCandidateFor(widget.experimentId),
        ]);
        result = results[0] as ExperimentResult;
        candidate = results[1] as LearningCandidate?;
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _result = result;
        _candidate = candidate;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLog() async {
    setState(() => _busy = true);
    try {
      await _repo.recordDailyLog(
        widget.experimentId,
        targetMet: _targetMet,
        notes: _notes.text,
        metrics: {
          'energy': _energy,
          'stress': _stress,
        },
      );
      if (mounted) {
        _notes.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Logged for today.')));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _complete() async {
    final ok = await _confirm(
      'Complete this experiment?',
      'The results will be evaluated against your baseline. This is final.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.complete(widget.experimentId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await _confirm(
        'Cancel this experiment?', 'The current run is cancelled and will not be evaluated.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.cancel(widget.experimentId);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decideCandidate(int candidateId, bool accept) async {
    setState(() => _busy = true);
    try {
      final res = accept
          ? await _repo.acceptCandidate(candidateId)
          : await _repo.rejectCandidate(candidateId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.message)));
      }
      final candidate = await _repo.learningCandidateFor(widget.experimentId);
      if (mounted) setState(() => _candidate = candidate);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Experiment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _detail == null
                  ? const SizedBox.shrink()
                  : _detail!.experiment.status == 'active'
                      ? _buildActive(context)
                      : _buildResult(context),
    );
  }

  // --- Running experiment ---------------------------------------------------

  Widget _buildActive(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = _detail!;
    final exp = detail.experiment;
    final daysLeft =
        exp.endDate.difference(detail.today).inDays.clamp(0, exp.durationDays);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(exp.title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(exp.hypothesis,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          Center(
            child: ProgressRing(
              value: detail.progressPercent / 100,
              size: 120,
              strokeWidth: 11,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Day ${detail.daysInto}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('of ${exp.durationDays}',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              daysLeft == 0
                  ? 'Final day \u2014 complete when ready'
                  : '$daysLeft day${daysLeft == 1 ? '' : 's'} remaining',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Log today',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Target: ${detail.target ?? exp.intervention}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Met the target today'),
                  value: _targetMet,
                  onChanged: (v) => setState(() => _targetMet = v),
                ),
                Text('Energy (optional)',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                Slider(
                  value: _energy.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_energy',
                  onChanged: (v) => setState(() => _energy = v.round()),
                ),
                Text('Stress (optional)',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                Slider(
                  value: _stress.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_stress',
                  onChanged: (v) => setState(() => _stress = v.round()),
                ),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submitLog,
                    child: Text(_busy ? 'Saving...' : 'Save today\u2019s log'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (detail.dailyLogs.isNotEmpty) ...[
            Text('Logged days',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...detail.dailyLogs.reversed.map(
              (log) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  log.completed && (log.targetMet ?? false)
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  color: (log.targetMet ?? false)
                      ? Colors.green
                      : scheme.onSurfaceVariant,
                ),
                title: Text(AppDateUtils.fullDay(log.date)),
                subtitle: log.notes == null || log.notes!.isEmpty
                    ? null
                    : Text(log.notes!),
                trailing: log.dayNumber != null
                    ? Text('Day ${log.dayNumber}')
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _complete,
                  child: const Text('Complete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- Completed experiment --------------------------------------------------

  Widget _buildResult(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exp = _detail!.experiment;
    final result = _result;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(exp.title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${exp.status} on ${exp.completedAt == null ? AppDateUtils.shortDay(exp.endDate) : AppDateUtils.shortDay(exp.completedAt!.toLocal())}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (result != null) ...[
            _ResultHeader(result: result),
            const SizedBox(height: 16),
            Text('Results',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (result.metrics.isEmpty)
              Text(
                'Not enough valid observations to compare metrics. Completion was ${result.dataCompleteness.toStringAsFixed(0)}%.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ...result.metrics.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.metric.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            _directionIcon(scheme, m.direction),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _statRow('Baseline', _fmt(m.baselineMean),
                            _fmt(m.baselineMedian)),
                        _statRow('Experiment', _fmt(m.experimentMean),
                            _fmt(m.experimentMedian)),
                        if (m.percentageChange != null)
                          _statRow('Change',
                              '${m.percentageChange!.toStringAsFixed(0)}%',
                              '(n=${m.validObservations})'),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (result.summary.isNotEmpty) ...[
              _sectionTitle('Summary', scheme),
              Text(result.summary,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 14)),
            ],
            if (result.limitations.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionTitle('Limitations', scheme),
              Text(result.limitations,
                  style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            Text(
              'These are observations from your own data \u2014 correlation only, not a diagnosis or proof of cause and effect.',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            if (_candidate != null)
              _CandidateCard(
                candidate: _candidate!,
                busy: _busy,
                onAccept: () => _decideCandidate(_candidate!.id, true),
                onReject: () => _decideCandidate(_candidate!.id, false),
              ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme scheme) => Text(
        text,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant),
      );

  Widget _statRow(String label, String mean, String median) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(mean, style: const TextStyle(fontSize: 13))),
          Expanded(
              child: Text('median $median',
                  style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _fmt(double? v) => v == null ? '\u2014' : v.toStringAsFixed(1);

  Widget _directionIcon(ColorScheme scheme, String direction) {
    final data = switch (direction) {
      'improved' => (Icons.arrow_upward, Colors.green),
      'worsened' => (Icons.arrow_downward, scheme.error),
      _ => (Icons.remove, scheme.onSurfaceVariant),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(data.$1, size: 16, color: data.$2),
        const SizedBox(width: 4),
        Text(direction.replaceAll('_', ''),
            style: TextStyle(fontSize: 11, color: data.$2)),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.result});

  final ExperimentResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final adherence = result.targetAdherenceText ??
        (result.targetAdherence == null
            ? null
            : '${(result.targetAdherence! * 100).round()}%');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EvidenceBadge(level: result.evidenceLevel),
              if (result.consistencyScore != null)
                StatusBadge(
                  label:
                      'Consistency ${result.consistencyScore!.toStringAsFixed(0)}/100',
                  color: scheme.secondary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Target adherence: ${adherence ?? '\u2014'}',
              style: const TextStyle(fontSize: 13)),
          Text('Sample: ${result.sampleSize} valid days',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            'Observation only \u2014 causality is never claimed.',
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final LearningCandidate candidate;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = candidate.observedChange;
    final note = change['direction'] ?? change['summary'] ?? '';
    return AppCard(
      color: scheme.tertiaryContainer.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pattern worth remembering?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onTertiaryContainer)),
          const SizedBox(height: 6),
          Text(
            '${candidate.patternType} appeared to relate to "${candidate.intervention}".'
            '${note is String && note.isNotEmpty ? ' $note' : ''}',
            style: TextStyle(
                color: scheme.onTertiaryContainer, fontSize: 13.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Evidence level: ${candidate.evidenceLevel.replaceAll('_', ' ')}',
            style: TextStyle(
                fontSize: 12,
                color: scheme.onTertiaryContainer.withValues(alpha: 0.7)),
          ),
          if (candidate.status == 'candidate') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: busy ? null : onReject,
                      child: const Text('Not for me')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                      onPressed: busy ? null : onAccept,
                      child: const Text('Keep it')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Keeping it feeds your "What works for me" profile. Nothing here is medical advice.',
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onTertiaryContainer.withValues(alpha: 0.7)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Status: ${candidate.status}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onTertiaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}
