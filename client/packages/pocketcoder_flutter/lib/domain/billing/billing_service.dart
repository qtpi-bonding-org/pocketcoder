abstract class BillingService {
  /// Initialize the billing service.
  Future<void> initialize();

  /// Check if the user has an active premium subscription.
  Future<bool> isPremium();

  /// Restore purchases.
  Future<void> restorePurchases();

  /// Purchase a package or subscription.
  Future<bool> purchase(String identifier);
}
