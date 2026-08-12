import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

class _FakeBillingService implements BillingService {
  BillingPackage? package;
  bool pro = false;
  bool purchaseResult = false;

  @override
  Future<BillingPackage?> getProPackage() async => package;

  @override
  Future<bool> hasProAccess() async => pro;

  @override
  Future<bool> purchasePro(String identifier) async {
    pro = purchaseResult;
    return purchaseResult;
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> reset() async {}
}

void main() {
  const package = BillingPackage(
    identifier: 'pro',
    title: 'PocketCoder Pro',
    description: 'All Pro capabilities',
    priceString: r'$9.99',
    billingPeriod: BillingPeriod.month,
    freeTrialDays: 7,
  );

  test('loads the single Pro package and entitlement', () async {
    final service = _FakeBillingService()
      ..package = package
      ..pro = true;
    final cubit = BillingCubit(service);

    await cubit.loadOffering();

    expect(cubit.state.package, package);
    expect(cubit.state.isPro, isTrue);
    expect(cubit.state.isSuccess, isTrue);
    await cubit.close();
  });

  test('unlocks Pro after a successful purchase', () async {
    final service = _FakeBillingService()..purchaseResult = true;
    final cubit = BillingCubit(service);

    expect(await cubit.purchasePro(package.identifier), isTrue);
    expect(cubit.state.isPro, isTrue);
    expect(cubit.state.isSuccess, isTrue);
    await cubit.close();
  });

  test('a cancelled purchase returns to a non-error state', () async {
    final cubit = BillingCubit(_FakeBillingService());

    expect(await cubit.purchasePro(package.identifier), isFalse);
    expect(cubit.state.isPro, isFalse);
    expect(cubit.state.isSuccess, isTrue);
    expect(cubit.state.hasError, isFalse);
    await cubit.close();
  });
}
