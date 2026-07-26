import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/l10n/app_localizations.dart';

/// Bottom-navigation shell holding the four primary destinations. Each branch
/// keeps its own navigation stack, so switching tabs preserves scroll position
/// and any pushed detail screens.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab again pops back to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_fire_department_outlined),
            selectedIcon: const Icon(Icons.local_fire_department),
            label: l.navMissions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: l.navCollection,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: l.navDevelopment,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_objects_outlined),
            selectedIcon: const Icon(Icons.emoji_objects),
            label: l.navPlay,
          ),
        ],
      ),
    );
  }
}
