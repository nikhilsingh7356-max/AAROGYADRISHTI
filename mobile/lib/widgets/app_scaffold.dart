/// Root scaffold with the 5-tab bottom navigation
/// (Home / Check-in / Insights / Experiments / Coach).
///
/// Profile lives outside the bar and is pushed from the Home header.
library;

import 'package:flutter/material.dart';

import '../features/checkin/checkin_screen.dart';
import '../features/coach/coach_screen.dart';
import '../features/dashboard/home_screen.dart';
import '../features/experiments/experiments_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/profile/profile_settings_screen.dart';
import 'app_bottom_bar.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _index = 0;

  void _openTab(int i) => setState(() => _index = i);

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
    );
  }

  late final List<Widget> _screens = [
    HomeScreen(onOpenProfile: _openProfile),
    const CheckinTab(),
    const InsightsScreen(),
    const ExperimentsScreen(),
    const CoachScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onTap: _openTab,
      ),
    );
  }
}
