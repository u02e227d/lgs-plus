import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/account_plan.dart';
import 'package:lgs_plus/services/lgsplus_cloud.dart';

void main() {
  AppUser user({
    SubscriptionPlan plan = SubscriptionPlan.free,
    DateTime? accessUntil,
    bool activated = false,
  }) =>
      AppUser(
        id: 'u1',
        companyName: 'テスト建設',
        address: '',
        contactName: 'テスト',
        phone: '090',
        email: 'a@b.c',
        activated: activated,
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
    final merged = LgsplusCloud.applyServer(
      user(accessUntil: DateTime(2026, 9, 20)),
      {
        'plan': 'paid',
        'access_until': '2026-09-20',
      },
    );
    expect(merged.isPaid, isTrue);
  });

  test('Apple購読中ならローカルも有料にする', () {
    final merged = LgsplusCloud.applyServer(
      user(accessUntil: DateTime(2026, 9, 1)),
      {
        'plan': 'free',
        'apple_status': 'SUBSCRIBED',
        'access_until': '2026-10-14',
        'org': {'seat_limit': 5, 'product_id': 'lgsplus.team.5.monthly'},
      },
    );
    expect(merged.isPaid, isTrue);
    expect(merged.seatLimit, 5);
    expect(merged.uploadUnlimited, isTrue);
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
    expect(merged.uploadUnlimited, isFalse);
  });

  test('アップロード枠をサーバーから取り込む', () {
    final merged = LgsplusCloud.applyServer(user(activated: true), {
      'plan': 'free',
      'upload_quota': {
        'remaining': 1,
        'limit': 6,
        'used': 2,
        'bonus': 3,
        'unlimited': 0,
      },
    });
    expect(merged.uploadRemaining, 1);
    expect(merged.uploadLimit, 6);
    expect(merged.uploadBonus, 3);
  });

  test('サーバーのお知らせを表示する', () {
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

  test('同期ペイロードに端末IDと占有フラグを付ける', () {
    final payload = LgsplusCloud.toPayload(
      user(),
      deviceId: 'dev-1',
      claim: true,
      deviceLabel: 'iOS',
    );
    expect(payload['device_id'], 'dev-1');
    expect(payload['claim'], 1);
    expect(payload['device_label'], 'iOS');
    expect(payload['client_app'], isNotEmpty);
    expect(['ios', 'mac'], contains(payload['client_app']));
  });

  test('テストユーザーはサーバー有料で戻さない', () {
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
      'apple_status': 'SUBSCRIBED',
      'access_until': '2026-09-20 12:00:00',
    });
    expect(merged.isPaid, isFalse);
  });

  test('席位メンバーは org から有料になる', () {
    final local = user(accessUntil: DateTime(2026, 9, 1));
    final merged = LgsplusCloud.applyServer(local, {
      'plan': 'free',
      'org': {
        'seat_limit': 5,
        'product_id': 'lgsplus.team.5.monthly',
        'status': 'active',
        'owner_user_id': 'owner-1',
      },
      'upload_quota': {'unlimited': 1, 'remaining': -1, 'limit': -1},
    });
    expect(merged.isPaid, isTrue);
    expect(merged.uploadUnlimited, isTrue);
    expect(merged.seatLimit, 5);
    expect(merged.orgOwnerUserId, 'owner-1');
    expect(merged.isOrgOwner, isFalse);
  });

  test('OrgTeamSnapshot は残席を計算する', () {
    final team = OrgTeamSnapshot.fromJson({
      'org': {'seat_limit': 5, 'seats_used': 2},
      'members': [
        {'email': 'owner@x.com', 'role': 'owner'},
      ],
      'invites': [
        {'email': 'pending@x.com', 'status': 'pending'},
      ],
    });
    expect(team.seatLimit, 5);
    expect(team.seatsUsed, 2);
    expect(team.remaining, 3);
    expect(team.members, hasLength(1));
    expect(team.pendingInvites, hasLength(1));
  });

  test('サーバー文字列数値でも AppUser.fromMap できる', () {
    final user = AppUser.fromMap({
      'id': 'u1',
      'company_name': 'ABC',
      'address': '横浜',
      'contact_name': '田中',
      'phone': '080',
      'email': 'a@b.c',
      'activated': '0',
      'created_at': '2026-09-16T12:00:00',
      'invite_code': 'LGS-TEST',
      'plan': 'free',
      'upload_bonus': '0',
      'seat_limit': '0',
      'upload_quota': {
        'remaining': '3',
        'limit': '3',
        'used': '0',
        'bonus': '0',
        'unlimited': '0',
      },
      'org': {'seat_limit': '5', 'product_id': 'lgsplus.team.5.monthly'},
    });
    expect(user.uploadBonus, 0);
    expect(user.uploadRemaining, 3);
    expect(user.seatLimit, 5);
    expect(user.activated, isFalse);
  });

  test('toPayload は password_hash と address を送る', () {
    final local = AppUser(
      id: 'u1',
      companyName: 'テスト建設',
      address: '東京都',
      contactName: 'テスト',
      phone: '090',
      email: 'a@b.c',
      passwordHash: 'abc123',
      activated: true,
      accessUntil: DateTime(2026, 10, 1),
    );
    final payload = LgsplusCloud.toPayload(local);
    expect(payload['password_hash'], 'abc123');
    expect(payload['address'], '東京都');
  });
}
