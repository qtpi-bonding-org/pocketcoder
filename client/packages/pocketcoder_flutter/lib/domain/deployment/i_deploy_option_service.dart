/// Interface for providing available deploy options.
///
/// Each build returns the providers it can currently expose to the user.
abstract class IDeployOptionService {
  List<DeployOption> getAvailableProviders();
}

/// A single deployment provider option shown in the deploy picker.
class DeployOption {
  final String id;
  final String name;
  final String description;

  /// External URL to open (Hetzner referral, Elestio link).
  final String? url;

  /// In-app route path (e.g. '/auth' for Linode OAuth flow).
  final String? routePath;

  /// Whether this option requires an IAP purchase first.
  final bool requiresPurchase;

  /// Unavailable options stay visible for roadmap context, but cannot launch.
  final DeployOptionAvailability availability;

  const DeployOption({
    required this.id,
    required this.name,
    required this.description,
    this.url,
    this.routePath,
    this.requiresPurchase = false,
    this.availability = DeployOptionAvailability.available,
  });

  bool get isAvailable => availability == DeployOptionAvailability.available;
}

enum DeployOptionAvailability { available, comingSoon }
