import 'package:equatable/equatable.dart';

abstract class BillingService {
  /// Initialize the billing service.
  Future<void> initialize();

  /// Links this device's purchases to the backend's own user id, so
  /// server-side entitlement checks (keyed on that same id) see them.
  /// Call once the id is known: after login, and again on session
  /// restore at a cold start (login() won't re-run in that case).
  Future<void> identify(String userId);

  /// Detaches from the current user id, reverting to an anonymous
  /// identity. Call on logout, so a different user on the same device
  /// doesn't inherit the previous user's linkage.
  Future<void> reset();

  /// Check if the user has an active Pro subscription.
  Future<bool> isPro();

  /// Restore purchases.
  Future<void> restorePurchases();

  /// Purchase a package or subscription.
  Future<bool> purchase(String identifier);

  /// Check if the user has deploy button access.
  Future<bool> hasDeployAccess();

  /// Fetch available offerings.
  Future<List<BillingPackage>> getAvailablePackages();
}

class BillingPackage extends Equatable {
  final String identifier;
  final String title;
  final String description;
  final String priceString;

  const BillingPackage({
    required this.identifier,
    required this.title,
    required this.description,
    required this.priceString,
  });

  @override
  List<Object?> get props => [identifier, title, description, priceString];
}
