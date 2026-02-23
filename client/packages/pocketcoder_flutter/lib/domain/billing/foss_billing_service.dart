import 'billing_service.dart';

/// A BillingService for the FOSS version which assumes all features are available.
class FossBillingService implements BillingService {
  @override
  Future<void> initialize() async {
    print("FossBillingService initialized (No-op)");
  }

  @override
  Future<bool> isPremium() async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<bool> purchase(String identifier) async => true;
}
