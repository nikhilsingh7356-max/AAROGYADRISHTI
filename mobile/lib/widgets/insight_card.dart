/// InsightCard - presents a backend-derived observation with the honest
/// framing required by the product boundary (correlation, not causation).
library;

import 'package:flutter/material.dart';

import 'app_card.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.title,
    required this.observation,
    this.evidenceLabel,
    this.onView,
    this.viewLabel = 'View insights',
  });

  /// e.g. "Sleep & energy"
  final String title;

  /// The observation sentence, written from the backend's data summary.
  final String observation;

  /// Evidence strength label, e.g. "Early observation".
  final String? evidenceLabel;
  final VoidCallback? onView;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      onTap: onView,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.psychology_alt_rounded,
                size: 22, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  observation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                if (evidenceLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    evidenceLabel!,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.primary),
        ],
      ),
    );
  }
}
