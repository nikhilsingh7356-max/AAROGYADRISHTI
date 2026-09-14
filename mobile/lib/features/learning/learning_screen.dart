/// "What works for me" - the personal learning profile (Phase 5).
///
/// Every entry is an observed correlation from the user's own experiments.
/// The copy consistently separates "what your data suggests" from "what this
/// does NOT prove".
library;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/network/api_exception.dart';
import '../../models/learning.dart';
import '../../repositories/learning_repository.dart';
import '../../widgets/app_card.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';
import 'learning_labels.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final LearningRepository _repo = LearningRepository(AppServices.instance.api);

  PersonalLearningSummary? _summary;
  List<PersonalLearning> _learnings = const [];
  bool _loading = true;
  bool _busy = false;
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
      final results = await Future.wait([_repo.summary(), _repo.list()]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as PersonalLearningSummary;
        _learnings = (results[1] as PersonalLearningList).learnings;
      });
    } on NetworkException {
      if (mounted) {
        setState(() {
          _error = 'No internet connection. Please try again.';
          _offline = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recalculate() async {
    setState(() => _busy = true);
    try {
      await _repo.recalculate();
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

  Future<void> _toggleDismiss(PersonalLearning learning) async {
    final updated = learning.state == 'dismissed'
        ? await _repo.reopen(learning.id)
        : await _repo.dismiss(learning.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(updated.message)));
      await _load();
    }
  }

  Future<void> _openDetail(PersonalLearning learning) async {
    try {
      final detail = await _repo.detail(learning.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _LearningDetailSheet(
            detail: detail, onToggle: () => _toggleDismiss(learning)),
      );
    } catch (_) {
      // Non-fatal: the list already shows the essentials.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What works for me'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recompute from latest evidence',
            onPressed: _busy ? null : _recalculate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(
                  message: _error!, onRetry: _load, offline: _offline)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_summary != null) _SummaryCard(summary: _summary!),
                      const SizedBox(height: 18),
                      Text('Your observations',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        'Patterns learned from the experiments you completed. Observations only \u2014 never medical advice.',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      if (_learnings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Complete an experiment and keep a candidate to start building your profile.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._learnings.map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LearningTile(
                              learning: l,
                              onTap: () => _openDetail(l),
                              onToggle: () => _toggleDismiss(l),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final PersonalLearningSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning profile',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _count(scheme, 'Proposed', summary.proposed),
              _count(scheme, 'Confirmed', summary.confirmed),
              _count(scheme, 'Dismissed', summary.dismissed),
            ],
          ),
          if (summary.topLearning != null) ...[
            const SizedBox(height: 12),
            Text(
              'Top observation: ${summary.topLearning!.patternType} with "${summary.topLearning!.intervention}" (consistency ${(summary.topLearning!.consistencyScore ?? 0).toStringAsFixed(0)}/100).',
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  Widget _count(ColorScheme scheme, String label, int value) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75))),
      ],
    );
  }
}

class _LearningTile extends StatelessWidget {
  const _LearningTile({
    required this.learning,
    required this.onTap,
    required this.onToggle,
  });

  final PersonalLearning learning;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_cap(learning.patternType)} \u00b7 "${learning.intervention}"',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (learning.state == 'dismissed')
                StatusBadge(
                  label: 'dismissed',
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              StatusBadge(
                label: evidenceStateLabel(learning.evidenceState),
                color: switch (learning.evidenceState) {
                  'positive' => Colors.green,
                  'negative' => scheme.error,
                  'mixed' || 'neutral' => scheme.secondary,
                  _ => scheme.onSurfaceVariant,
                },
              ),
              if (learning.consistencyScore != null) ...[
                const SizedBox(width: 8),
                Text(
                  'consistency ${learning.consistencyScore!.toStringAsFixed(0)}/100',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (learning.summary != null)
            Text(
              learning.summary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${learning.sampleSize} experiments',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                    learning.state == 'dismissed'
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 16),
                label: Text(learning.state == 'dismissed'
                    ? 'Restore'
                    : 'Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _LearningDetailSheet extends StatelessWidget {
  const _LearningDetailSheet({required this.detail, required this.onToggle});

  final PersonalLearningDetail detail;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = detail.learning;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text('${_cap(l.patternType)} \u00b7 "${l.intervention}"',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (l.hypothesis != null)
            Text(l.hypothesis!,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (l.summary != null)
            Text(l.summary!, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            learningDisclaimer,
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text('Supporting runs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (detail.evidence.isEmpty)
            Text('No supporting runs recorded.',
                style: TextStyle(color: scheme.onSurfaceVariant))
          else
            ...detail.evidence.map(
              (e) => AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      switch (e.direction) {
                        'positive' => Icons.trending_up,
                        'negative' => Icons.trending_down,
                        _ => Icons.remove,
                      },
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${e.evidenceLevel.replaceAll('_', ' ')}'
                        '${e.effectMagnitude != null ? ' \u00b7 effect ${e.effectMagnitude!.toStringAsFixed(2)}' : ''}'
                        '${e.observedChange?['summary'] != null ? ' \u00b7 ${e.observedChange!['summary']}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
                l.state == 'dismissed'
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 16),
            label: Text(l.state == 'dismissed'
                ? 'Restore to profile'
                : 'Dismiss from profile'),
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
