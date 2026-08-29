import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

/// A BillingService for the FOSS version which assumes all features are available.
class FossBillingService implements BillingService {
  @override
  Future<void> initialize() async {
  }

  @override
  Future<void> identify(String userId) async {
  }

  @override
  Future<void> reset() async {
  }

  @override
  Future<bool> hasProAccess() async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<bool> purchasePro(String identifier) async => true;

  @override
  Future<BillingPackage?> getProPackage() async => null;
}
