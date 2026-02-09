import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/presentation/chat/chat_screen.dart';
import 'package:test_app/presentation/onboarding/onboarding_screen.dart';
import 'package:test_app/presentation/artifact/artifact_screen.dart';
import 'package:test_app/presentation/settings/settings_screen.dart';
import 'package:test_app/presentation/settings/agent_management_screen.dart';
import 'package:test_app/presentation/whitelist/whitelist_screen.dart';
import 'package:test_app/presentation/boot/boot_screen.dart';

import 'package:test_app/presentation/core/widgets/terminal_transition.dart';

/// App routing configuration.
class AppRouter {
  AppRouter._();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.boot,
    routes: [
      GoRoute(
        path: AppRoutes.boot,
        name: RouteNames.boot,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const BootScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: RouteNames.onboarding,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: RouteNames.home,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const ChatScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.artifact,
        name: RouteNames.artifact,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const ArtifactScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: RouteNames.settings,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.aiRegistry,
        name: RouteNames.aiRegistry,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const AgentManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.whitelist,
        name: RouteNames.whitelist,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const WhitelistScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
}

class AppRoutes {
  AppRoutes._();
  static const String home = '/';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String boot = '/boot';
  static const String artifact = '/artifacts';
  static const String aiRegistry = '/settings/ai';
  static const String whitelist = '/settings/whitelist';
}

class RouteNames {
  RouteNames._();
  static const String home = 'home';
  static const String settings = 'settings';
  static const String onboarding = 'onboarding';
  static const String boot = 'boot';
  static const String artifact = 'artifact';
  static const String aiRegistry = 'aiRegistry';
  static const String whitelist = 'whitelist';
}

class AppNavigation {
  AppNavigation._();

  static void toHome(BuildContext context) => context.goNamed(RouteNames.home);
  static void toSettings(BuildContext context) =>
      context.pushNamed(RouteNames.settings);
  static void toWhitelist(BuildContext context) =>
      context.pushNamed(RouteNames.whitelist);

  static void back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      toHome(context);
    }
  }
}
