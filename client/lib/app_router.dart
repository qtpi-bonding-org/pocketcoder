import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/presentation/chat/chat_screen.dart';
import 'package:test_app/presentation/onboarding/onboarding_screen.dart';
import 'package:test_app/presentation/artifact/artifact_screen.dart';
import 'package:test_app/presentation/settings/settings_screen.dart';
import 'package:test_app/presentation/settings/agent_management_screen.dart';
import 'package:test_app/presentation/whitelist/whitelist_screen.dart';
import 'package:test_app/presentation/boot/boot_screen.dart';
import 'package:test_app/presentation/terminal/terminal_screen.dart';
import 'package:test_app/presentation/observability/agent_observability_screen.dart';
import 'package:test_app/presentation/mcp/mcp_management_screen.dart';
import 'package:test_app/presentation/sop/sop_management_screen.dart';
import 'package:test_app/presentation/system/system_checks_screen.dart';

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
      GoRoute(
        path: AppRoutes.terminal,
        name: RouteNames.terminal,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const TerminalScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.agentObservability,
        name: RouteNames.agentObservability,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const AgentObservabilityScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.mcpManagement,
        name: RouteNames.mcpManagement,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const McpManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sopManagement,
        name: RouteNames.sopManagement,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SopManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.systemChecks,
        name: RouteNames.systemChecks,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SystemChecksScreen(),
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
  static const String terminal = '/terminal';
  static const String agentObservability = '/observability';
  static const String mcpManagement = '/mcp';
  static const String sopManagement = '/sop';
  static const String systemChecks = '/system-checks';
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
  static const String terminal = 'terminal';
  static const String agentObservability = 'agentObservability';
  static const String mcpManagement = 'mcpManagement';
  static const String sopManagement = 'sopManagement';
  static const String systemChecks = 'systemChecks';
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
