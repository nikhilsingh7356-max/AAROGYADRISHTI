/// Custom bottom navigation bar for AarogyaDrishti.
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

/// A single destination inside [AppBottomBar].
class AppBottomBarDestination extends StatelessWidget {
  const AppBottomBarDestination({
    super.key,
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
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? scheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: 23,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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

  static const double _height = 62;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                for (final tab in kAppTabs)
                  AppBottomBarDestination(
                    tab: tab,
                    selected: currentIndex == tab.index,
                    onTap: () => onTap(tab.index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Body padding helper so screens keep content clear of the bar.
EdgeInsets appBottomPadding(BuildContext context) {
  return EdgeInsets.only(
    bottom: AppBottomBar._height + MediaQuery.paddingOf(context).bottom + 24,
  );
}