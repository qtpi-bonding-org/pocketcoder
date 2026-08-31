/// Carries a just-generated deployment's login details across navigation
/// (e.g. from DetailsScreen's "LOG IN NOW" action to GetStartedScreen) so
/// the user can review and submit them instead of typing them from
/// memory. Deliberately a plain object, not persisted anywhere.
class OnboardingPrefill {
  const OnboardingPrefill({
    required this.url,
    required this.email,
    required this.password,
  });

  final String url;
  final String email;
  final String password;
}
