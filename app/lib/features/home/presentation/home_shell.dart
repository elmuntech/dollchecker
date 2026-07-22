import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/dashboard/presentation/dashboard_page.dart';
import 'package:dollchecker/features/history/presentation/history_screen.dart';
import 'package:dollchecker/features/home/presentation/home_screen.dart';
import 'package:dollchecker/features/home/presentation/home_tab.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Bottom-navigation shell: Scan / Dashboard / History, with a Settings action.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final index = ref.watch(homeTabProvider);
    final child = ref.watch(selectedChildProvider);

    final titles = [
      child == null ? l.appTitle : l.homeGreeting(child.name),
      l.dashboard,
      l.history,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: const [
            HomeBody(),
            DashboardPage(),
            HistoryBody(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(homeTabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.camera_alt_outlined),
              selectedIcon: const Icon(Icons.camera_alt),
              label: l.scan),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: l.dashboard),
          NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: l.history),
        ],
      ),
    );
  }
}
