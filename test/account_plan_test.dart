import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/account_plan.dart';

void main() {
  test('招待コードを正規化しリンクを組み立てる', () {
    expect(AccountPlan.normalizeInviteCode(' lgs-ab12cd '), 'LGS-AB12CD');
    expect(
      AccountPlan.inviteLink('LGS-AB12CD'),
      'https://lgsplus.app/invite?code=LGS-AB12CD',
    );
    expect(AccountPlan.inviteBody('LGS-AB12CD').contains('LGS-AB12CD'), isTrue);
  });

  test('利用日数は当日を含めて残り日を数える', () {
    final user = AppUser(
      id: 'u',
      companyName: '山田太郎',
      address: '',
      contactName: '山田太郎',
      phone: '090',
      email: 'a@b.c',
      createdAt: DateTime(2026, 9, 1),
      accessUntil: DateTime(2026, 9, 15),
    );
    expect(user.remainingDays(DateTime(2026, 9, 14)), 1);
    expect(user.remainingDays(DateTime(2026, 9, 15)), 0);
    expect(user.remainingDays(DateTime(2026, 9, 16)), 0);
  });

  test('無料かつ期限切れは測定のみ、有料または残日数があれば全機能', () {
    final freeExpired = AppUser(
      id: 'f',
      companyName: '無料',
      address: '',
      contactName: '無料',
      phone: '090',
      email: 'f@b.c',
      plan: SubscriptionPlan.free,
      accessUntil: DateTime(2026, 9, 1),
    );
    expect(freeExpired.hasFullAccess(DateTime(2026, 9, 14)), isFalse);

    final bonus = freeExpired.copyWith(accessUntil: DateTime(2026, 9, 21));
    expect(bonus.hasFullAccess(DateTime(2026, 9, 14)), isTrue);

    final paid = freeExpired.copyWith(plan: SubscriptionPlan.paid);
    expect(paid.hasFullAccess(DateTime(2026, 9, 14)), isTrue);
  });

  test('新規登録は7日間全機能、8日目から無料版', () {
    final now = DateTime(2026, 9, 14, 10);
    final user = AccountPlan.applySignupTrial(
      AppUser(
        id: 'n',
        companyName: '新規',
        address: '',
        contactName: '新規',
        phone: '090',
        email: 'n@b.c',
        createdAt: now,
      ),
      now,
    );
    expect(user.accessUntil, DateTime(2026, 9, 21, 10));
    expect(user.hasFullAccess(DateTime(2026, 9, 14)), isTrue);
    expect(user.hasFullAccess(DateTime(2026, 9, 20)), isTrue);
    expect(user.hasFullAccess(DateTime(2026, 9, 21)), isFalse);
    expect(user.pendingNotice, AccountPlan.signupNotice);
  });

  test('招待特典は現在の期限から1週間延長する', () {
    final now = DateTime(2026, 9, 14, 10);
    final user = AppUser(
      id: 'u',
      companyName: '山田太郎',
      address: '',
      contactName: '山田太郎',
      phone: '090',
      email: 'a@b.c',
      accessUntil: DateTime(2026, 9, 10),
    );
    final next = AccountPlan.applyBonus(user, now);
    expect(next.accessUntil, DateTime(2026, 9, 21, 10));
    expect(next.pendingNotice, AccountPlan.bonusNotice);
  });

  test('有料をやめたら日数も消えて番号ページは見られない', () {
    final now = DateTime(2026, 9, 14, 10);
    final paid = AppUser(
      id: 'p',
      companyName: '有料',
      address: '',
      contactName: '有料',
      phone: '090',
      email: 'p@b.c',
      plan: SubscriptionPlan.paid,
      accessUntil: DateTime(2026, 10, 14, 10),
    );
    expect(paid.hasFullAccess(now), isTrue);
    final canceled = AccountPlan.cancelPaid(paid, now);
    expect(canceled.isPaid, isFalse);
    expect(canceled.hasFullAccess(now), isFalse);
  });
}
