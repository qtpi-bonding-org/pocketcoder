/// Interface for providing available deploy options.
///
/// FOSS builds return only free providers (Hetzner referral link).
/// Proprietary builds add paid providers (Linode, Elestio).
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

  const DeployOption({
    required this.id,
    required this.name,
    required this.description,
    this.url,
    this.routePath,
    this.requiresPurchase = false,
  });
}
