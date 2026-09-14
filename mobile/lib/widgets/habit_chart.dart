/// HabitChart - a minimal trend bar chart for daily lifestyle data.
///
/// Data-quality rule: a NULL day renders as a visible GAP (dash + empty
/// slot), never as a zero-height bar, so missing data stays missing.
library;

import 'package:flutter/material.dart';

class ChartPoint {
  const ChartPoint({required this.label, this.value});

  final String label;

  /// null = not recorded that day (rendered as a gap).
  final double? value;
}

class HabitChart extends StatelessWidget {
  const HabitChart({
    super.key,
    required this.title,
    required this.icon,
    required this.points,
    this.unit,
    this.maxBars = 14,
    this.barHeight = 88,
  });

  final String title;
  final IconData icon;
  final List<ChartPoint> points;
  final String? unit;
  final int maxBars;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown =
        points.length > maxBars ? points.sublist(points.length - maxBars) : points;
    final maxValue = shown
        .map((p) => p.value)
        .whereType<double>()
        .fold(0.0, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (points.every((p) => p.value == null))
                Text(
                  'No data in this period',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in shown)
                  Expanded(
                    child: _Bar(
                        value: p.value,
                        max: maxValue,
                        height: barHeight,
                        unit: unit),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in shown)
                Expanded(
                  child: Text(
                    p.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.height,
    this.unit,
  });

  final double? value;
  final double max;
  final double height;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // NULL day: explicit gap, never a zero bar.
    if (value == null) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '\u2014',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.outline,
            ),
          ),
        ),
      );
    }

    final fraction = max <= 0 ? 0.03 : (value! / max).clamp(0.03, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (unit != null)
          Text(
            value!.toStringAsFixed(1),
            style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: height * fraction,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
      ],
    );
  }
}
