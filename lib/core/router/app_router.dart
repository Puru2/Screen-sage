import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screensage/features/focus_dna/presentation/screens/focus_dna_screen.dart';

import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/earned_time/presentation/screens/earned_time_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/session/presentation/screens/session_home_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../shell/app_shell.dart';

// Navigator keys — one per shell branch for independent stacks
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _sessionNavKey = GlobalKey<NavigatorState>(debugLabel: 'session');
final _analyticsNavKey = GlobalKey<NavigatorState>(debugLabel: 'analytics');
final _focusDNAKey = GlobalKey<NavigatorState>(debugLabel: 'focus');
final _earnedTimeNavKey = GlobalKey<NavigatorState>(debugLabel: 'earned');
final _settingsNavKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/session',
    debugLogDiagnostics: true,

    // ── Auth redirect (FIREBASE LATEST) ───────────────────────────
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isAuth = state.matchedLocation == '/auth';

      // First launch: no user → onboarding
      if (user == null && !isOnboarding && !isAuth) {
        return '/onboarding';
      }
      // Already logged in → skip onboarding/auth
      if (user != null && (isOnboarding || isAuth)) {
        return '/session';
      }
      return null; // no redirect
    },

    routes: [
      // ── Outside shell: Onboarding + Auth ──────────────────────
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuthScreen(),
      ),

      // ── Main shell with bottom nav ─────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: _sessionNavKey,
            routes: [
              GoRoute(
                path: '/session',
                builder: (context, state) => const SessionHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _analyticsNavKey,
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _focusDNAKey,
            routes: [
              GoRoute(
                  path: '/focus',
                  builder: (context, state) => const FocusDNAScreen())
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _earnedTimeNavKey,
            routes: [
              GoRoute(
                path: '/earned',
                builder: (context, state) => const EarnedTimeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsNavKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
