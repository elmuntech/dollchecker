import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/auth/data/auth_repository.dart';
import 'package:dollchecker/features/auth/presentation/auth_screen.dart';
import 'package:dollchecker/features/auth/presentation/reset_password_screen.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/child_profile/presentation/children_screen.dart';
import 'package:dollchecker/features/child_profile/presentation/onboarding_child_screen.dart';
import 'package:dollchecker/features/collection/presentation/collection_screen.dart';
import 'package:dollchecker/features/collection/presentation/toy_detail_screen.dart';
import 'package:dollchecker/features/development/presentation/dashboard_screen.dart';
import 'package:dollchecker/features/history/presentation/history_screen.dart';
import 'package:dollchecker/features/home/presentation/home_screen.dart';
import 'package:dollchecker/features/missions/presentation/missions_screen.dart';
import 'package:dollchecker/features/parents/presentation/parents_screen.dart';
import 'package:dollchecker/features/play/presentation/play_screen.dart';
import 'package:dollchecker/features/scan/presentation/analyzing_screen.dart';
import 'package:dollchecker/features/scan/presentation/result_screen.dart';
import 'package:dollchecker/features/settings/presentation/settings_screen.dart';
import 'package:dollchecker/features/shell/presentation/home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod changes → GoRouter refresh without recreating the router.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.listen(childrenProvider, (_, __) => refresh.value++);
  ref.listen(passwordRecoveryProvider, (_, __) => refresh.value++);

  // A recovery link signs the user in with a session whose only purpose is
  // changing the password, so the arrival has to be remembered — the session
  // itself looks like any other.
  ref.listen(authStateProvider, (_, next) {
    if (next.valueOrNull?.event == AuthChangeEvent.passwordRecovery) {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    }
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session == null) {
        return loc == '/auth' ? null : '/auth';
      }

      // Arrived through a recovery link: nothing else in the app is reachable
      // until a new password is set (or the flow is abandoned, which signs out).
      if (ref.read(passwordRecoveryProvider)) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (loc == '/reset-password') return '/';
      if (loc == '/auth') return '/';

      // Signed in — require at least one child profile before using the app.
      final kids = ref.read(childrenProvider).valueOrNull;
      if (kids != null && kids.isEmpty) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (loc == '/onboarding' && kids != null && kids.isNotEmpty) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingChildScreen()),

      // Primary destinations. Each branch keeps its own navigation stack.
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/missions', builder: (_, __) => const MissionsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/collection',
                builder: (_, __) => const CollectionScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/development',
                builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/play', builder: (_, __) => const PlayScreen()),
          ]),
        ],
      ),

      // Screens pushed above the shell.
      GoRoute(path: '/analyzing', builder: (_, __) => const AnalyzingScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/parents', builder: (_, __) => const ParentsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/children', builder: (_, __) => const ChildrenScreen()),
      GoRoute(
        path: '/scan/:id',
        builder: (_, state) =>
            ResultScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/toy/:id',
        builder: (_, state) =>
            ToyDetailScreen(toyId: state.pathParameters['id']!),
      ),
    ],
  );
});
