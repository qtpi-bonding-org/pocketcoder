/// Interface for providing available deploy options.
///
/// Each build returns the providers it can currently expose to the user.
abstract class IProviderOptionService {
  List<ProviderOption> getAvailableProviders();
}

/// A single deployment provider option shown in the deploy picker.
class ProviderOption {
  final String id;
  final String name;
  final String description;

  /// External URL to open (Hetzner referral, Elestio link).
  final String? url;

  /// In-app route path (e.g. '/auth' for Linode OAuth flow).
  final String? routePath;

  /// Whether this option requires an active PocketCoder Pro entitlement.
  final bool requiresPro;

  /// Unavailable options stay visible for roadmap context, but cannot launch.
  final ProviderOptionAvailability availability;

  const ProviderOption({
    required this.id,
    required this.name,
    required this.description,
    this.url,
    this.routePath,
    this.requiresPro = false,
    this.availability = ProviderOptionAvailability.available,
  });

  bool get isAvailable => availability == ProviderOptionAvailability.available;
}

enum ProviderOptionAvailability { available, comingSoon }
