/// ProgressRing - a calm circular progress indicator with a center label.
library;

import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    this.strokeWidth = 10,
    this.center,
    this.backgroundColor,
    this.color,
  });

  /// 0..1 progress. Values outside the range are clamped.
  final double value;

  final double size;
  final double strokeWidth;

  /// Widget rendered in the center (e.g. "3/7").
  final Widget? center;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
            backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color ?? scheme.primary),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}
