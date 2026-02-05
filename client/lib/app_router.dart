import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/presentation/terminal/terminal_screen.dart';

/// App routing configuration.
class AppRouter {
  AppRouter._();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: RouteNames.home,
        builder: (context, state) => const TerminalScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: RouteNames.settings,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Settings Page')),
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
}

class RouteNames {
  RouteNames._();
  static const String home = 'home';
  static const String settings = 'settings';
}

class AppNavigation {
  AppNavigation._();

  static void toHome(BuildContext context) => context.goNamed(RouteNames.home);
  static void toSettings(BuildContext context) =>
      context.pushNamed(RouteNames.settings);

  static void back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      toHome(context);
    }
  }
}
