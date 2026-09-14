import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'account_plan.dart';

/// ショップ API への同期。圏外でもアプリは動く（失敗は無視）。
class LgsplusCloud {
  static const baseUrl = 'https://shopws.infmaxai.com/api/lgsplus';
  static const appKey = 'lgsplus-ops-sync-2026';

  static const _endedApple = {
    'EXPIRED',
    'REFUND',
    'REVOKE',
    'GRACE_PERIOD_EXPIRED',
  };

  /// テストでネットワークを切るとき false
  static bool enabled = true;

  static const emailTaken = 'このメールアドレスは既に登録されています';
  static const phoneTaken = 'この電話番号は既に登録されています';

  static Future<String?> registrationConflict({
    required String email,
    required String phone,
  }) async {
    if (!enabled) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/checkRegister'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({'email': email, 'phone': phone}),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != 1) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      if (data['email_taken'] == 1 || data['email_taken'] == true) {
        return emailTaken;
      }
      if (data['phone_taken'] == 1 || data['phone_taken'] == true) {
        return phoneTaken;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// true=存在する / false=存在しない / null=通信できず判定不能
  static Future<bool?> inviteExists(String code) async {
    if (!enabled) return null;
    final normalized = AccountPlan.normalizeInviteCode(code);
    if (normalized.isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/checkInvite'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({'invite_code': normalized}),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return decoded['success'] == 1;
    } catch (_) {
      return null;
    }
  }

  static Future<AppUser?> sync(AppUser user) async {
    if (!enabled) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/syncUser'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode(toPayload(user)),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      if (decoded['success'] != 1) {
        final message = '${decoded['message'] ?? ''}';
        if (message.contains('既に登録')) {
          throw Exception(message);
        }
        return null;
      }
      final data = decoded['data'];
      if (data is! Map) return null;
      return applyServer(user, Map<String, dynamic>.from(data));
    } on Exception catch (e) {
      if (e.toString().contains('既に登録')) rethrow;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> toPayload(AppUser user) => {
        'id': user.id,
        'company_name': user.companyName,
        'contact_name': user.contactName,
        'phone': user.phone,
        'email': user.email,
        'invite_code': user.inviteCode,
        'referred_by_code': user.referredByCode,
        'plan': user.isPaid ? 'paid' : 'free',
        'access_until': user.accessUntil.toIso8601String(),
        'activated': user.activated ? 1 : 0,
      };

  static AppUser applyServer(AppUser local, Map<String, dynamic> data) {
    var next = local;
    final apple = '${data['apple_status'] ?? ''}';
    if (_endedApple.contains(apple)) {
      next = next.copyWith(plan: SubscriptionPlan.free);
    } else if (data['plan'] == 'paid' && !next.isPaid) {
      // テストユーザーは端末の余り試用を見せる。サーバー有料で解除しない
      if (local.email != 'test@lgsplus.local') {
        next = next.copyWith(plan: SubscriptionPlan.paid);
      }
    }
    final until = parseDate(data['access_until']);
    if (until != null &&
        until.isAfter(next.accessUntil) &&
        !(local.email == 'test@lgsplus.local' && !local.isPaid)) {
      final extra = until.difference(next.accessUntil).inDays;
      final serverNotice = '${data['pending_notice'] ?? ''}'.trim();
      next = next.copyWith(
        accessUntil: until,
        pendingNotice: serverNotice.isNotEmpty
            ? serverNotice
            : extra >= 6
                ? AccountPlan.bonusNotice
                : '利用可能日数が追加されました。',
      );
    } else {
      final serverNotice = '${data['pending_notice'] ?? ''}'.trim();
      if (serverNotice.isNotEmpty) {
        next = next.copyWith(pendingNotice: serverNotice);
      }
    }
    return next;
  }

  static Map<String, dynamic> reportPayload({
    required AppUser user,
    required String kind,
    required String title,
    required String body,
    String lang = 'ja',
  }) =>
      {
        'user_id': user.id,
        'email': user.email,
        'company_name': user.companyName,
        'contact_name': user.contactName,
        'phone': user.phone,
        'kind': kind == 'request' ? 'request' : 'opinion',
        'title': title.trim(),
        'body': body.trim(),
        'lang': lang,
      };

  /// null=成功 / 文字列=エラー
  static Future<String?> submitReport({
    required AppUser user,
    required String kind,
    required String title,
    required String body,
    String lang = 'ja',
  }) async {
    if (!enabled) return 'offline';
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/submitReport'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode(reportPayload(
              user: user,
              kind: kind,
              title: title,
              body: body,
              lang: lang,
            )),
          )
          .timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['success'] == 1) return null;
      if (decoded is Map) {
        final message = '${decoded['message'] ?? ''}'.trim();
        if (message.isNotEmpty) return message;
      }
      return 'send_failed';
    } catch (_) {
      return 'send_failed';
    }
  }

  static DateTime? parseDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }
}
