import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/services/account_plan.dart';
import 'package:lgs_plus/services/store_billing.dart';

void main() {
  test('席位Product IDはConnectの製品IDと一致する', () {
    expect(AccountPlan.monthlyProductId, 'lgsplus.team.1.monthly');
    expect(AccountPlan.monthlyPriceYen, 9980);
    expect(
      AccountPlan.productIds.contains('lgsplus.team.5.monthly'),
      isTrue,
    );
    expect(
      AccountPlan.productIds.contains('lgsplus.team.20.monthly'),
      isTrue,
    );
  });

  test('appAccountToken は UUID だけ通す', () {
    expect(
      StoreBilling.appAccountToken('4c2a1d8e-9b70-4f31-8a55-0c1d2e3f4a5b'),
      '4c2a1d8e-9b70-4f31-8a55-0c1d2e3f4a5b',
    );
    expect(StoreBilling.appAccountToken('not-a-uuid'), isNull);
    expect(StoreBilling.appAccountToken(''), isNull);
  });

  test('同一 purchaseId は有料を二重に適用しない', () {
    expect(
      AccountPlan.shouldApplyPaidTransaction(
        purchaseId: 'txn-1',
        alreadyAppliedPurchaseId: null,
      ),
      isTrue,
    );
    expect(
      AccountPlan.shouldApplyPaidTransaction(
        purchaseId: 'txn-1',
        alreadyAppliedPurchaseId: 'txn-1',
      ),
      isFalse,
    );
    expect(
      AccountPlan.shouldApplyPaidTransaction(
        purchaseId: 'txn-2',
        alreadyAppliedPurchaseId: 'txn-1',
      ),
      isTrue,
    );
  });
}
