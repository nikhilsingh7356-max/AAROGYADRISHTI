/// Floating pill bottom navigation bar for AarogyaDrishti.
///
/// New IA: Home / Check-in / Insights / Experiments / Coach.
/// Profile is reached from the Home header (per the information architecture).
library;

import 'package:flutter/material.dart';

class AppTab {
  const AppTab({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<AppTab> kAppTabs = [
  AppTab(index: 0, label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
  AppTab(index: 1, label: 'Check-in', icon: Icons.edit_note_outlined, selectedIcon: Icons.edit_note_rounded),
  AppTab(index: 2, label: 'Insights', icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded),
  AppTab(index: 3, label: 'Experiments', icon: Icons.science_outlined, selectedIcon: Icons.science_rounded),
  AppTab(index: 4, label: 'Coach', icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded),
];

class _PillDestination extends StatelessWidget {
  const _PillDestination({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? tab.selectedIcon : tab.icon,
              size: 22,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _height = 56;
  static const double _horizontalMargin = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        bottom == 0 ? 12 : 8,
      ),
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final tab in kAppTabs)
              _PillDestination(
                tab: tab,
                selected: currentIndex == tab.index,
                onTap: () => onTap(tab.index),
              ),
          ],
        ),
      ),
    );
  }
}

/// Body padding helper so screens keep content clear of the floating bar.
EdgeInsets appBottomPadding(BuildContext context) {
  final bottom = MediaQuery.paddingOf(context).bottom;
  return EdgeInsets.only(
    bottom: AppBottomBar._height + AppBottomBar._horizontalMargin + (bottom == 0 ? 12 : 8) + bottom + 16,
  );
}
