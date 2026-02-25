import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

/// A BillingService for the FOSS version which assumes all features are available.
class FossBillingService implements BillingService {
  @override
  Future<void> initialize() async {
    // No-op for FOSS
  }

  @override
  Future<bool> isPremium() async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<bool> purchase(String identifier) async => true;

  @override
  Future<List<BillingPackage>> getAvailablePackages() async {
    return [
      const BillingPackage(
        identifier: 'foss_premium',
        title: 'FOSS Premium',
        description: 'Free as in speech and beer.',
        priceString: r'$0.00',
      ),
    ];
  }
}
