import 'package:pocketcoder_flutter/app_router.dart';

/// The routes the boot policy is allowed to decide.
///
/// Deliberately not the whole route table: everything else in the app is
/// user-driven navigation the policy never touches. Keeping this small is
/// what makes the policy's decisions compile-checked.
enum BootRoute {
  onboarding,
  login,
  harnessAuth,
  chats,
  deploymentProgress,
  instanceGone,
  instanceUnverifiable,
}

/// The `RouteNames` constant for [route].
String bootRouteName(BootRoute route) => switch (route) {
      BootRoute.onboarding => RouteNames.onboarding,
      BootRoute.login => RouteNames.onboardingLogin,
      BootRoute.harnessAuth => RouteNames.onboardingHarnessAuth,
      BootRoute.chats => RouteNames.chats,
      BootRoute.deploymentProgress => RouteNames.deploymentProgress,
      BootRoute.instanceGone => RouteNames.instanceGone,
      BootRoute.instanceUnverifiable => RouteNames.instanceUnverifiable,
    };

/// The [BootRoute] for [name], or null when the user is somewhere the policy
/// has no opinion about.
BootRoute? bootRouteFromName(String name) {
  for (final route in BootRoute.values) {
    if (bootRouteName(route) == name) return route;
  }
  return null;
}
