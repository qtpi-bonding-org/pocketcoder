import 'package:equatable/equatable.dart';

const pocketCoderProEntitlement = 'PocketCoder Pro';

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

  /// Check whether the single PocketCoder Pro entitlement is active.
  ///
  /// An active store trial and a paid subscription both grant this same
  /// entitlement. Callers should gate Pro capabilities on this method rather
  /// than on individual product identifiers.
  Future<bool> hasProAccess();

  /// Restore purchases.
  Future<void> restorePurchases();

  Future<void> manageSubscription();

  /// Purchase the Pro package represented by [identifier].
  Future<bool> purchasePro(String identifier);

  /// Fetch the single Pro package offered for this platform.
  Future<BillingPackage?> getProPackage();
}

enum BillingPeriod { week, month, year, unknown }

class BillingPackage extends Equatable {
  final String identifier;
  final String title;
  final String description;
  final String priceString;
  final BillingPeriod billingPeriod;
  final int? freeTrialDays;

  const BillingPackage({
    required this.identifier,
    required this.title,
    required this.description,
    required this.priceString,
    this.billingPeriod = BillingPeriod.unknown,
    this.freeTrialDays,
  });

  @override
  List<Object?> get props => [
        identifier,
        title,
        description,
        priceString,
        billingPeriod,
        freeTrialDays,
      ];
}
