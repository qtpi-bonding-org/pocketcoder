/// Carries the admin email/password chosen on GetStartedScreen's DEPLOY
/// tab forward through the deploy route chain, so ChooseProviderScreen ->
/// AuthScreen -> ConfigScreen don't each need to re-collect or
/// auto-generate them. Deliberately a plain object, not persisted
/// anywhere -- same spirit as OnboardingPrefill's opposite direction.
class ServerCredentials {
  const ServerCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}
