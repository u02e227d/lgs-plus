import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/account_plan.dart';

void main() {
  test('招待コードを正規化しリンクを組み立てる', () {
    expect(AccountPlan.normalizeInviteCode(' lgs-ab12cd '), 'LGS-AB12CD');
    expect(
      AccountPlan.inviteLink('LGS-AB12CD'),
      'https://shop.infmaxai.com/invite?code=LGS-AB12CD',
    );
    expect(AccountPlan.inviteBody('LGS-AB12CD').contains('LGS-AB12CD'), isTrue);
    expect(AccountPlan.inviteBody('LGS-AB12CD').contains('双方'), isFalse);
    expect(AccountPlan.inviteBody('LGS-AB12CD').contains('登録・ログインした方'), isTrue);
  });

  test('席位Product IDと席数', () {
    expect(AccountPlan.seatsForProductId('lgsplus.team.5.monthly'), 5);
    expect(AccountPlan.seatsForProductId('lgsplus.team.20.monthly'), 20);
    expect(AccountPlan.seatsForProductId('lgsplus.mac.team.5.monthly'), 5);
    expect(AccountPlan.seatsForProductId('lgsplus.premium.monthly'), 1);
    expect(AccountPlan.monthlyProductId, 'lgsplus.team.1.monthly');
    expect(AccountPlan.monthlyPriceYen, 9980);
    expect(
      AccountPlan.productIds.contains('lgsplus.mac.team.1.monthly'),
      isTrue,
    );
  });

  test('無料はアップロード枠内で全機能、有料は無制限', () {
    final free = AppUser(
      id: 'f',
      companyName: '無料',
      address: '',
      contactName: '無料',
      phone: '090',
      email: 'f@b.c',
      activated: true,
      plan: SubscriptionPlan.free,
      uploadRemaining: 2,
    );
    expect(free.hasFullAccess(), isTrue);
    expect(free.canUploadDrawing, isTrue);

    final exhausted = free.copyWith(uploadRemaining: 0);
    expect(exhausted.hasFullAccess(), isTrue);
    expect(exhausted.canUploadDrawing, isFalse);

    final paid = free.copyWith(
      plan: SubscriptionPlan.paid,
      uploadUnlimited: true,
      uploadRemaining: -1,
      seatLimit: 5,
    );
    expect(paid.canUploadDrawing, isTrue);
    expect(paid.seatLimit, 5);
  });

  test('新規登録はアップロード案内のみ', () {
    final now = DateTime(2026, 9, 14, 10);
    final user = AccountPlan.applySignupTrial(
      AppUser(
        id: 'n',
        companyName: '新規',
        address: '',
        contactName: '新規',
        phone: '090',
        email: 'n@b.c',
        activated: true,
        createdAt: now,
      ),
      now,
    );
    expect(user.pendingNotice, AccountPlan.signupNotice);
    expect(user.hasFullAccess(), isTrue);
  });

  test('有料をやめたら席位と無制限アップロードを外す', () {
    final now = DateTime(2026, 9, 14, 10);
    final paid = AppUser(
      id: 'p',
      companyName: '有料',
      address: '',
      contactName: '有料',
      phone: '090',
      email: 'p@b.c',
      activated: true,
      plan: SubscriptionPlan.paid,
      seatLimit: 5,
      productId: 'lgsplus.team.5.monthly',
      uploadUnlimited: true,
    );
    final canceled = AccountPlan.cancelPaid(paid, now);
    expect(canceled.isPaid, isFalse);
    expect(canceled.seatLimit, 0);
    expect(canceled.productId, isNull);
    expect(canceled.hasFullAccess(), isTrue);
  });
}
