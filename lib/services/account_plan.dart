import 'dart:math';

import '../models/models.dart';

class AccountPlan {
  AccountPlan._();

  static const signupTrialDays = 7;
  static const inviteBonusDays = 7;
  static const paidMonthDays = 30;
  static const signupNotice =
      '新規登録特典：7日間すべての機能をご利用いただけます。7日後は無料版（図面・スケール・測定のみ）になります。';
  static const bonusNotice = '招待特典：1周無料化が適用されました。';
  static const reportAdoptNotice = 'ご提案が採用され、利用日数が追加されました。';
  static const reportAdoptDays = 7;
  static const paidNotice =
      '有料プランは毎月最低更新です。いつでも解約できますが、お支払い済みの月分は返金されません。';

  static const inviteLinkBase = 'https://lgsplus.app/invite';

  static String generateInviteCode([Random? rng]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = rng ?? Random();
    final body = List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
    return 'LGS-$body';
  }

  static String normalizeInviteCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static String inviteLink(String code) =>
      '$inviteLinkBase?code=${Uri.encodeQueryComponent(normalizeInviteCode(code))}';

  static String inviteSubject() => 'LGS+積算のご招待';

  static String inviteBody(String code) {
    final normalized = normalizeInviteCode(code);
    return 'LGS+積算をご紹介します。\n'
        '\n'
        '招待コード：$normalized\n'
        '登録リンク：${inviteLink(normalized)}\n'
        '\n'
        'アプリをダウンロードし、新規登録画面でこの招待コードを入力してください。'
        '友達が登録してログインすると、紹介した方・された方の両方に自動で1週間の無料特典が付きます。受け取り操作は不要です。';
  }

  static DateTime extendAccess({
    required DateTime current,
    required DateTime now,
    int days = inviteBonusDays,
  }) {
    final base = current.isAfter(now) ? current : now;
    return base.add(Duration(days: days));
  }

  static DateTime signupAccessUntil(DateTime now) =>
      now.add(const Duration(days: signupTrialDays));

  static AppUser applySignupTrial(AppUser user, DateTime now) {
    return user.copyWith(
      accessUntil: signupAccessUntil(now),
      pendingNotice: signupNotice,
    );
  }

  static AppUser applyBonus(AppUser user, DateTime now) {
    return user.copyWith(
      accessUntil: extendAccess(current: user.accessUntil, now: now),
      pendingNotice: bonusNotice,
    );
  }
}
