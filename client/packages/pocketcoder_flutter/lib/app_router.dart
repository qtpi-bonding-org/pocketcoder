import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/presentation/chat/chat_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';
import 'package:pocketcoder_flutter/presentation/artifact/artifact_screen.dart';
import 'package:pocketcoder_flutter/presentation/settings/settings_screen.dart';
import 'package:pocketcoder_flutter/presentation/settings/agent_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/whitelist/whitelist_screen.dart';
import 'package:pocketcoder_flutter/presentation/boot/boot_screen.dart';
import 'package:pocketcoder_flutter/presentation/terminal/terminal_screen.dart';
import 'package:pocketcoder_flutter/presentation/observability/agent_observability_screen.dart';
import 'package:pocketcoder_flutter/presentation/mcp/mcp_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/sop/sop_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/system/system_checks_screen.dart';
import 'package:pocketcoder_flutter/presentation/billing/permission_relay_screen.dart';
import 'package:pocketcoder_flutter/presentation/auth/auth_screen.dart';
import 'package:pocketcoder_flutter/presentation/deployment/config_screen.dart';
import 'package:pocketcoder_flutter/presentation/deployment/progress_screen.dart';
import 'package:pocketcoder_flutter/presentation/deployment/details_screen.dart';

import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_transition.dart';

/// App routing configuration.
class AppRouter {
  AppRouter._();

  static GoRouter get router => _router;
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

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
        pageBuilder: (context, state) {
          final path = state.uri.queryParameters['path'];
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: ArtifactScreen(initialPath: path),
          );
        },
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
      GoRoute(
        path: AppRoutes.paywall,
        name: RouteNames.paywall,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const PermissionRelayScreen(),
        ),
      ),
      // Deployment routes
      GoRoute(
        path: AppRoutes.auth,
        name: RouteNames.auth,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const AuthScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.config,
        name: RouteNames.config,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const ConfigScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.deploymentProgress,
        name: RouteNames.deploymentProgress,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const ProgressScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.deploymentDetails}?instanceId',
        name: RouteNames.deploymentDetails,
        pageBuilder: (context, state) {
          final instanceId = state.uri.queryParameters['instanceId'] ?? '';
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: DetailsScreen(instanceId: instanceId),
          );
        },
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
  static const String paywall = '/paywall';
  // Deployment routes
  static const String auth = '/auth';
  static const String config = '/config';
  static const String deploymentProgress = '/deployment/progress';
  static const String deploymentDetails = '/deployment/details';
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
  static const String paywall = 'paywall';
  // Deployment route names
  static const String auth = 'auth';
  static const String config = 'config';
  static const String deploymentProgress = 'deploymentProgress';
  static const String deploymentDetails = 'deploymentDetails';
}

class AppNavigation {
  AppNavigation._();

  static void toHome(BuildContext context) => context.goNamed(RouteNames.home);
  static void toSettings(BuildContext context) =>
      context.pushNamed(RouteNames.settings);
  static void toWhitelist(BuildContext context) =>
      context.pushNamed(RouteNames.whitelist);
  static void toPaywall(BuildContext context) =>
      context.pushNamed(RouteNames.paywall);

  // Deployment navigation
  static void toAuth(BuildContext context) =>
      context.pushNamed(RouteNames.auth);
  static void toConfig(BuildContext context) =>
      context.pushNamed(RouteNames.config);
  static void toDeploymentProgress(BuildContext context) =>
      context.pushNamed(RouteNames.deploymentProgress);
  static void toDeploymentDetails(BuildContext context, String instanceId) =>
      context.pushNamed(
        RouteNames.deploymentDetails,
        queryParameters: {'instanceId': instanceId},
      );

  static void back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      toHome(context);
    }
  }
}
