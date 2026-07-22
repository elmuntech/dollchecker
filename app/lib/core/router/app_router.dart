import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/auth/presentation/auth_screen.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/child_profile/presentation/onboarding_child_screen.dart';
import 'package:dollchecker/features/home/presentation/home_shell.dart';
import 'package:dollchecker/features/scan/presentation/analyzing_screen.dart';
import 'package:dollchecker/features/scan/presentation/result_screen.dart';
import 'package:dollchecker/features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod changes → GoRouter refresh without recreating the router.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.listen(childrenProvider, (_, __) => refresh.value++);
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
          path: '/onboarding',
          builder: (_, __) => const OnboardingChildScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(
          path: '/analyzing', builder: (_, __) => const AnalyzingScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/scan/:id',
        builder: (_, state) =>
            ResultScreen(scanId: state.pathParameters['id']!),
      ),
    ],
  );
});
