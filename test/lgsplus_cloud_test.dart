import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/account_plan.dart';
import 'package:lgs_plus/services/lgsplus_cloud.dart';

void main() {
  AppUser user({
    SubscriptionPlan plan = SubscriptionPlan.free,
    DateTime? accessUntil,
  }) =>
      AppUser(
        id: 'u1',
        companyName: 'テスト建設',
        address: '',
        contactName: 'テスト',
        phone: '090',
        email: 'a@b.c',
        plan: plan,
        accessUntil: accessUntil ?? DateTime(2026, 9, 1),
      );

  test('サーバーの期限が長いときだけ上書きする', () {
    final local = user(accessUntil: DateTime(2026, 9, 10));
    final merged = LgsplusCloud.applyServer(local, {
      'plan': 'free',
      'access_until': '2026-09-20 12:00:00',
    });
    expect(merged.accessUntil, DateTime.parse('2026-09-20T12:00:00'));
    expect(merged.isPaid, isFalse);
  });

  test('サーバーが有料ならローカルも有料にする', () {
    final merged = LgsplusCloud.applyServer(user(), {
      'plan': 'paid',
      'access_until': '2026-09-01',
    });
    expect(merged.isPaid, isTrue);
  });

  test('Apple期限切れは有料を落とす', () {
    final merged = LgsplusCloud.applyServer(
      user(plan: SubscriptionPlan.paid, accessUntil: DateTime(2026, 10, 1)),
      {
        'plan': 'free',
        'apple_status': 'EXPIRED',
        'access_until': '2026-09-01',
      },
    );
    expect(merged.isPaid, isFalse);
  });

  test('サーバーが7日以上延ばしたら招待特典のお知らせを付ける', () {
    final local = user(accessUntil: DateTime(2026, 9, 10));
    final merged = LgsplusCloud.applyServer(local, {
      'plan': 'free',
      'access_until': '2026-09-17 12:00:00',
    });
    expect(merged.pendingNotice, AccountPlan.bonusNotice);
  });

  test('サーバーの採用お知らせを表示する', () {
    final local = user(accessUntil: DateTime(2026, 9, 10));
    final merged = LgsplusCloud.applyServer(local, {
      'plan': 'free',
      'access_until': '2026-09-17 12:00:00',
      'pending_notice': AccountPlan.reportAdoptNotice,
    });
    expect(merged.pendingNotice, AccountPlan.reportAdoptNotice);
  });

  test('意見報告の送信ペイロード', () {
    final payload = LgsplusCloud.reportPayload(
      user: user(),
      kind: 'request',
      title: '天井の寸法',
      body: '3×6を既定にしてほしいです',
      lang: 'zh',
    );
    expect(payload['kind'], 'request');
    expect(payload['title'], '天井の寸法');
    expect(payload['user_id'], 'u1');
    expect(payload['lang'], 'zh');
  });

  test('ローカルの方が期限が長いときは維持', () {
    final local = user(accessUntil: DateTime(2026, 10, 1));
    final merged = LgsplusCloud.applyServer(local, {
      'plan': 'free',
      'access_until': '2026-09-02',
    });
    expect(merged.accessUntil, DateTime(2026, 10, 1));
  });

  test('テストユーザーの余り試用はサーバー期限で戻さない', () {
    final local = AppUser(
      id: 't1',
      companyName: 'テスト建設',
      address: '',
      contactName: 'テスト',
      phone: '000',
      email: 'test@lgsplus.local',
      plan: SubscriptionPlan.free,
      accessUntil: DateTime(2026, 9, 1),
    );
    final merged = LgsplusCloud.applyServer(local, {
      'plan': 'paid',
      'access_until': '2026-09-20 12:00:00',
    });
    expect(merged.isPaid, isFalse);
    expect(merged.accessUntil, DateTime(2026, 9, 1));
  });
}
