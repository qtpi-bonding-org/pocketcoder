import 'package:equatable/equatable.dart';

abstract class BillingService {
  /// Initialize the billing service.
  Future<void> initialize();

  /// Check if the user has an active premium subscription.
  Future<bool> isPremium();

  /// Restore purchases.
  Future<void> restorePurchases();

  /// Purchase a package or subscription.
  Future<bool> purchase(String identifier);

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
