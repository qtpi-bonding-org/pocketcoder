import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/presentation/chat/chat_screen.dart';
import 'package:pocketcoder_flutter/presentation/home/home_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';
import 'package:pocketcoder_flutter/presentation/files/file_screen.dart';
import 'package:pocketcoder_flutter/presentation/settings/settings_screen.dart';
import 'package:pocketcoder_flutter/presentation/settings/agent_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/tool_permissions/tool_permissions_screen.dart';
import 'package:pocketcoder_flutter/presentation/boot/boot_screen.dart';
import 'package:pocketcoder_flutter/presentation/terminal/terminal_screen.dart';
import 'package:pocketcoder_flutter/presentation/observability/agent_observability_screen.dart';
import 'package:pocketcoder_flutter/presentation/mcp/mcp_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/sop/sop_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/system/system_checks_screen.dart';
import 'package:pocketcoder_flutter/presentation/billing/permission_relay_screen.dart';
import 'package:pocketcoder_flutter/presentation/monitor/monitor_screen.dart';
import 'package:pocketcoder_flutter/presentation/llm/llm_management_screen.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_picker_screen.dart';

import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_transition.dart';

/// App routing configuration.
class AppRouter {
  AppRouter._();

  static GoRouter get router => _router;
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Additional routes injected by the proprietary package (e.g. Linode flow).
  static List<RouteBase> _additionalRoutes = const [];

  /// Call before accessing [router] to inject proprietary routes.
  static void setAdditionalRoutes(List<RouteBase> routes) {
    _additionalRoutes = routes;
  }

  static final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.boot,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // Redirect / → /chats
      if (loc == '/') return AppRoutes.chats;
      // Legacy redirects
      if (loc == '/settings') return AppRoutes.configure;
      if (loc == '/settings/ai') return AppRoutes.configureAi;
      if (loc == '/settings/whitelist') return AppRoutes.configureToolPermissions;
      if (loc == '/mcp') return AppRoutes.configureMcp;
      if (loc == '/sop') return AppRoutes.configureSop;
      if (loc == '/system-checks') return AppRoutes.configureSystemChecks;
      if (loc == '/paywall') return AppRoutes.configurePaywall;
      if (loc == '/observability') return AppRoutes.configureObservability;
      return null;
    },
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
      // ── CHATS pillar ──
      GoRoute(
        path: AppRoutes.chats,
        name: RouteNames.chats,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.chat}/:chatId',
        name: RouteNames.chat,
        pageBuilder: (context, state) {
          final chatId = state.pathParameters['chatId'];
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: ChatScreen(chatId: chatId),
          );
        },
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
        path: AppRoutes.files,
        name: RouteNames.files,
        pageBuilder: (context, state) {
          final path = state.uri.queryParameters['path'];
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: FileScreen(initialPath: path),
          );
        },
      ),
      // ── MONITOR pillar ──
      GoRoute(
        path: AppRoutes.monitor,
        name: RouteNames.monitor,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const MonitorScreen(),
        ),
      ),
      // ── CONFIGURE pillar ──
      GoRoute(
        path: AppRoutes.configure,
        name: RouteNames.configure,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureAi,
        name: RouteNames.configureAi,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const AgentManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureToolPermissions,
        name: RouteNames.configureToolPermissions,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const ToolPermissionsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureMcp,
        name: RouteNames.configureMcp,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const McpManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureSop,
        name: RouteNames.configureSop,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SopManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureSystemChecks,
        name: RouteNames.configureSystemChecks,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SystemChecksScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configurePaywall,
        name: RouteNames.configurePaywall,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const PermissionRelayScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureLlm,
        name: RouteNames.configureLlm,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const LlmManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.configureObservability,
        name: RouteNames.configureObservability,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const AgentObservabilityScreen(),
        ),
      ),
      // ── DEPLOY pillar ──
      GoRoute(
        path: AppRoutes.deploy,
        name: RouteNames.deploy,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const DeployPickerScreen(),
        ),
      ),
      // Additional routes injected by proprietary package
      ..._additionalRoutes,
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
  // Pillar routes
  static const String chats = '/chats';
  static const String monitor = '/monitor';
  static const String configure = '/configure';
  // Legacy alias — redirects to /chats
  static const String home = '/';
  static const String chat = '/chat';
  static const String onboarding = '/onboarding';
  static const String boot = '/boot';
  static const String files = '/files';
  static const String terminal = '/terminal';
  // Configure sub-routes
  static const String configureAi = '/configure/ai';
  static const String configureToolPermissions = '/configure/tool-permissions';
  static const String configureMcp = '/configure/mcp';
  static const String configureSop = '/configure/sop';
  static const String configureSystemChecks = '/configure/system-checks';
  static const String configurePaywall = '/configure/paywall';
  static const String configureObservability = '/configure/observability';
  static const String configureLlm = '/configure/llm';
  // Legacy aliases (redirected)
  static const String settings = '/settings';
  static const String aiRegistry = '/settings/ai';
  static const String toolPermissions = '/settings/whitelist';
  static const String agentObservability = '/observability';
  static const String mcpManagement = '/mcp';
  static const String sopManagement = '/sop';
  static const String systemChecks = '/system-checks';
  static const String paywall = '/paywall';
  // Deploy picker
  static const String deploy = '/deploy';
  // Deployment routes (registered by proprietary package)
  static const String auth = '/auth';
  static const String config = '/config';
  static const String deploymentProgress = '/deployment/progress';
  static const String deploymentDetails = '/deployment/details';
}

class RouteNames {
  RouteNames._();
  static const String chats = 'chats';
  static const String monitor = 'monitor';
  static const String configure = 'configure';
  // Legacy alias
  static const String home = 'chats';
  static const String chat = 'chat';
  static const String settings = 'configure';
  static const String onboarding = 'onboarding';
  static const String boot = 'boot';
  static const String files = 'files';
  static const String terminal = 'terminal';
  // Configure sub-routes
  static const String configureAi = 'configureAi';
  static const String configureToolPermissions = 'configureToolPermissions';
  static const String configureMcp = 'configureMcp';
  static const String configureSop = 'configureSop';
  static const String configureSystemChecks = 'configureSystemChecks';
  static const String configurePaywall = 'configurePaywall';
  static const String configureObservability = 'configureObservability';
  static const String configureLlm = 'configureLlm';
  // Legacy aliases
  static const String aiRegistry = 'configureAi';
  static const String toolPermissions = 'configureToolPermissions';
  static const String agentObservability = 'configureObservability';
  static const String mcpManagement = 'configureMcp';
  static const String sopManagement = 'configureSop';
  static const String systemChecks = 'configureSystemChecks';
  static const String paywall = 'configurePaywall';
  // Deploy picker
  static const String deploy = 'deploy';
  // Deployment route names (registered by proprietary package)
  static const String auth = 'auth';
  static const String config = 'config';
  static const String deploymentProgress = 'deploymentProgress';
  static const String deploymentDetails = 'deploymentDetails';
}

class AppNavigation {
  AppNavigation._();

  static void toHome(BuildContext context) => context.go(AppRoutes.chats);
  static void toChat(BuildContext context, String chatId) =>
      context.go('${AppRoutes.chat}/$chatId');
  static void toNewChat(BuildContext context) =>
      context.go('${AppRoutes.chat}/new');
  static void toSettings(BuildContext context) =>
      context.go(AppRoutes.configure);
  static void toToolPermissions(BuildContext context) =>
      context.push(AppRoutes.configureToolPermissions);
  static void toPaywall(BuildContext context) =>
      context.push(AppRoutes.configurePaywall);
  static void toTerminal(BuildContext context) =>
      context.push(AppRoutes.terminal);
  static void toFiles(BuildContext context) =>
      context.push(AppRoutes.files);
  static void toMonitor(BuildContext context) =>
      context.go(AppRoutes.monitor);
  static void toDeploy(BuildContext context) =>
      context.push(AppRoutes.deploy);

  // Deployment navigation (Linode flow — only works when proprietary routes registered)
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
