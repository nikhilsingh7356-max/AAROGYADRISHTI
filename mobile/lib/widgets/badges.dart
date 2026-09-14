/// Small, reusable status and evidence badges.
///
/// - [StatusBadge] labels a record's state (active / completed / dismissed…).
/// - [EvidenceBadge] communicates evidence strength WITHOUT ever claiming
///   causation: language is deliberately observational ("Early observation").
library;

import 'package:flutter/material.dart';

import '../features/learning/learning_labels.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class EvidenceBadge extends StatelessWidget {
  const EvidenceBadge({super.key, required this.level, this.compact = false});

  /// Backend evidence level, e.g. "INSUFFICIENT", "WEAK", "MODERATE", "STRONG".
  final String level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = level.toUpperCase();
    final (color, label) = switch (normalized) {
      'STRONG' || 'HIGH' => (scheme.primary, 'Stronger observation'),
      'MODERATE' || 'MEDIUM' => (scheme.secondary, 'Observation building'),
      'WEAK' || 'LOW' => (scheme.tertiary, 'Early observation'),
      _ => (scheme.onSurfaceVariant, 'Not enough data yet'),
    };
    return StatusBadge(
      label: compact ? evidenceShortLabel(normalized) : label,
      color: color,
      icon: Icons.insights_rounded,
    );
  }
}
