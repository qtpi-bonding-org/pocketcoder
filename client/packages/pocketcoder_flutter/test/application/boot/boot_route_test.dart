import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/boot/boot_route.dart';

void main() {
  test('every BootRoute maps to a real RouteNames constant', () {
    const expected = <BootRoute, String>{
      BootRoute.onboarding: RouteNames.onboarding,
      BootRoute.login: RouteNames.onboardingLogin,
      BootRoute.harnessAuth: RouteNames.onboardingHarnessAuth,
      BootRoute.chats: RouteNames.chats,
      BootRoute.deploymentProgress: RouteNames.deploymentProgress,
      BootRoute.instanceGone: RouteNames.instanceGone,
      BootRoute.instanceUnverifiable: RouteNames.instanceUnverifiable,
    };

    expect(expected.length, BootRoute.values.length,
        reason: 'a new BootRoute must be given a route name here');
    for (final entry in expected.entries) {
      expect(bootRouteName(entry.key), entry.value);
    }
  });

  test('names round-trip back to their route', () {
    for (final route in BootRoute.values) {
      expect(bootRouteFromName(bootRouteName(route)), route);
    }
  });

  test('an unknown name resolves to null, not a guess', () {
    expect(bootRouteFromName(RouteNames.configureAi), isNull);
    expect(bootRouteFromName('nonsense'), isNull);
  });
}
