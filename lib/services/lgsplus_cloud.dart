import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'account_plan.dart';
import 'device_session.dart';

class OpsNotice {
  const OpsNotice({
    required this.id,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime? publishedAt;

  factory OpsNotice.fromJson(Map<String, dynamic> m) {
    return OpsNotice(
      id: int.tryParse('${m['id'] ?? 0}') ?? 0,
      title: '${m['title'] ?? ''}'.trim(),
      body: '${m['body'] ?? ''}'.trim(),
      publishedAt: LgsplusCloud.parseDate(m['published_at']),
    );
  }
}

class OrgTeamSnapshot {
  const OrgTeamSnapshot({
    this.members = const [],
    this.pendingInvites = const [],
    this.seatLimit = 0,
    this.seatsUsed = 0,
  });

  static const empty = OrgTeamSnapshot();

  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> pendingInvites;
  final int seatLimit;
  final int seatsUsed;

  int get remaining {
    if (seatLimit <= 0) return 0;
    final left = seatLimit - seatsUsed;
    return left < 0 ? 0 : left;
  }

  factory OrgTeamSnapshot.fromJson(Map<String, dynamic> data) {
    final org = data['org'];
    final seatLimit = org is Map ? _asInt(org['seat_limit']) ?? 0 : 0;
    final seatsUsed = org is Map ? _asInt(org['seats_used']) ?? 0 : 0;
    final members = data['members'];
    final invites = data['invites'];
    return OrgTeamSnapshot(
      seatLimit: seatLimit,
      seatsUsed: seatsUsed,
      members: members is List
          ? members
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      pendingInvites: invites is List
          ? invites
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
    );
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t) ?? double.tryParse(t)?.toInt();
  }
  return null;
}

/// ショップ API への同期。圏外でもアプリは動く（失敗は無視）。
class LgsplusCloud {
  static const baseUrl = 'https://shopws.infmaxai.com/api/lgsplus';
  static const appKey = 'lgsplus-ops-sync-2026';

  /// iOS/iPad = ios / Mac = mac / Windows = windows（サーバー上は別アカウント）
  static String get clientApp => DeviceSession.clientApp();

  static Map<String, dynamic> _withClient(Map<String, dynamic> body) => {
        ...body,
        'client_app': clientApp,
      };


  static const _endedApple = {
    'EXPIRED',
    'REFUND',
    'REVOKE',
    'GRACE_PERIOD_EXPIRED',
  };

  static const _activeApple = {
    'SUBSCRIBED',
    'DID_RENEW',
    'OFFER_REDEEMED',
    'DID_CHANGE_RENEWAL_PREF',
  };

  /// テストでネットワークを切るとき false
  static bool enabled = true;

  static const emailTaken = 'このメールアドレスは既に登録されています';
  static const phoneTaken = 'この電話番号は既に登録されています';

  /// 友達紹介の宛先が既存アカウントか。true=送信不可 / false=可 / null=判定不能
  static Future<bool?> isFriendInviteDestRegistered(String dest) async {
    if (!enabled) return null;
    final t = dest.trim();
    if (t.isEmpty) return false;
    final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/checkRegister'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode(_withClient({
              'email': isEmail ? t.toLowerCase() : '',
              'phone': isEmail ? '' : t,
              'company_name': '',
            })),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != 1) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      final emailTakenFlag =
          data['email_taken'] == 1 || data['email_taken'] == true;
      final phoneTakenFlag =
          data['phone_taken'] == 1 || data['phone_taken'] == true;
      if (isEmail) return emailTakenFlag;
      return phoneTakenFlag;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> registrationConflict({
    required String email,
    required String phone,
    String companyName = '',
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
            body: jsonEncode(_withClient({
              'email': email,
              'phone': phone,
              'company_name': companyName,
            })),
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

  static Future<AppUser> registerUser({
    required String id,
    required String companyName,
    required String address,
    required String contactName,
    required String phone,
    required String email,
    String? inviteCode,
  }) async {
    if (!enabled) {
      throw Exception('offline');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/registerUser'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'id': id,
            'company_name': companyName,
            'contact_name': contactName,
            'phone': phone,
            'email': email.trim().toLowerCase(),
            'address': address,
            if (inviteCode != null && inviteCode.trim().isNotEmpty)
              'referred_by_code': AccountPlan.normalizeInviteCode(inviteCode),
          })),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('register_failed');
    }
    if (decoded['success'] != 1) {
      final message = '${decoded['message'] ?? ''}'.trim();
      throw Exception(message.isEmpty ? 'register_failed' : message);
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw Exception('register_failed');
    }
    final userMap = data['user'];
    if (userMap is! Map) {
      throw Exception('register_failed');
    }
    return userFromServer(
      Map<String, dynamic>.from(userMap),
      passwordHash: '',
      allowEmptyPassword: true,
    );
  }

  static Future<void> verifyEmailCode({
    required String email,
    required String code,
    bool passwordReset = false,
  }) async {
    if (!enabled) {
      throw Exception('offline');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/verifyEmailCode'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'email': email.trim().toLowerCase(),
            'code': code.trim(),
            if (passwordReset) 'purpose': 'reset',
          })),
        )
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('verify_failed');
    }
    if (decoded['success'] != 1) {
      final message = '${decoded['message'] ?? ''}'.trim();
      throw Exception(message.isEmpty ? 'verify_failed' : message);
    }
  }

  static Future<String> resendEmailCode({
    required String email,
    bool passwordReset = false,
  }) async {
    if (!enabled) {
      throw Exception('offline');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/resendEmailCode'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'email': email.trim().toLowerCase(),
            if (passwordReset) 'purpose': 'reset',
          })),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('resend_failed');
    }
    if (decoded['success'] != 1) {
      final message = '${decoded['message'] ?? ''}'.trim();
      throw Exception(message.isEmpty ? 'resend_failed' : message);
    }
    final data = decoded['data'];
    if (data is Map && '${data['purpose'] ?? ''}' == 'reset') {
      return 'reset';
    }
    return 'register';
  }

  static Future<bool> requestPasswordReset({required String email}) async {
    if (!enabled) {
      throw Exception('offline');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/requestPasswordReset'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({'email': email.trim().toLowerCase()})),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('reset_request_failed');
    }
    if (decoded['success'] != 1) {
      final message = '${decoded['message'] ?? ''}'.trim();
      throw Exception(message.isEmpty ? 'reset_request_failed' : message);
    }
    final data = decoded['data'];
    if (data is Map &&
        (data['resume_registration'] == 1 ||
            data['resume_registration'] == true)) {
      return true;
    }
    return false;
  }

  static Future<AppUser> setPassword({
    required String email,
    required String passwordHash,
    String? deviceId,
  }) async {
    if (!enabled) {
      throw Exception('offline');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/setPassword'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'email': email.trim().toLowerCase(),
            'password_hash': passwordHash,
            if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
          })),
        )
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('set_password_failed');
    }
    if (decoded['success'] != 1) {
      final message = '${decoded['message'] ?? ''}'.trim();
      if (message.contains(DeviceSwitchCooldownException.code)) {
        throw const DeviceSwitchCooldownException();
      }
      throw Exception(message.isEmpty ? 'set_password_failed' : message);
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw Exception('set_password_failed');
    }
    return userFromServer(
      Map<String, dynamic>.from(data),
      passwordHash: passwordHash,
    );
  }

  static Future<AppUser> resetPassword({
    required String email,
    required String passwordHash,
  }) async {
    if (!enabled) {
      throw Exception('offline');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/resetPassword'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'email': email.trim().toLowerCase(),
            'password_hash': passwordHash,
          })),
        )
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('reset_password_failed');
    }
    if (decoded['success'] != 1) {
      final message = '${decoded['message'] ?? ''}'.trim();
      throw Exception(message.isEmpty ? 'reset_password_failed' : message);
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw Exception('reset_password_failed');
    }
    return userFromServer(
      Map<String, dynamic>.from(data),
      passwordHash: passwordHash,
    );
  }

  static Future<AppUser?> login({
    required String email,
    required String passwordHash,
    String? deviceId,
    String deviceLabel = '',
  }) async {
    if (!enabled) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/loginUser'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode(_withClient({
              'email': email.trim().toLowerCase(),
              'password_hash': passwordHash,
              if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
              if (deviceLabel.isNotEmpty) 'device_label': deviceLabel,
            })),
          )
          .timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      if (decoded['success'] != 1) {
        final message = '${decoded['message'] ?? ''}';
        if (message.contains(DeviceSwitchCooldownException.code)) {
          throw const DeviceSwitchCooldownException();
        }
        if (DeviceSession.isKickedMessage(message)) {
          throw const SessionKickedException();
        }
        if (message.contains('password_not_synced')) {
          throw Exception('password_not_synced');
        }
        if (message.contains('wrong_client_app:')) {
          throw Exception(message.trim());
        }
        if (message.contains('未活性化')) {
          throw Exception('not_activated');
        }
        if (message.isNotEmpty) {
          throw Exception(message);
        }
        return null;
      }
      final data = decoded['data'];
      if (data is! Map) return null;
      return userFromServer(
        Map<String, dynamic>.from(data),
        passwordHash: passwordHash,
      );
    } on DeviceSwitchCooldownException {
      rethrow;
    } on SessionKickedException {
      rethrow;
    } on Exception catch (e) {
      final text = e.toString();
      if (text.contains(DeviceSwitchCooldownException.code)) {
        throw const DeviceSwitchCooldownException();
      }
      if (text.contains('password_not_synced') ||
          text.contains('not_activated') ||
          text.contains('wrong_client_app:') ||
          text.contains('既に') ||
          text.contains('違います') ||
          text.contains('未活性化') ||
          text.contains(DeviceSession.kickedCode)) {
        rethrow;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static AppUser userFromServer(
    Map<String, dynamic> data, {
    required String passwordHash,
    bool allowEmptyPassword = false,
  }) {
    final map = Map<String, dynamic>.from(data);
    if (!map.containsKey('created_at') || '${map['created_at']}'.isEmpty) {
      map['created_at'] = DateTime.now().toIso8601String();
    }
    final hash = passwordHash.trim();
    final base = AppUser.fromMap(map);
    return base.copyWith(
      passwordHash: allowEmptyPassword && hash.isEmpty ? null : hash,
      activated: base.activated || allowEmptyPassword,
    );
  }

  static Future<AppUser?> applyStorePurchase({
    required String userId,
    required String productId,
    String? originalTransactionId,
    String? expiresDate,
    String? signedTransaction,
  }) async {
    if (!enabled) return null;
    final signed = (signedTransaction ?? '').trim();
    if (signed.isEmpty) {
      throw Exception('purchase_verification_required');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/applyStorePurchase'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode({
            'user_id': userId,
            'product_id': productId,
            'original_transaction_id': originalTransactionId ?? '',
            'expires_date': expiresDate ?? '',
            'signed_transaction': signed,
            'verification_data': signed,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != 1) {
      final message = decoded is Map ? '${decoded['message'] ?? ''}'.trim() : '';
      throw Exception(message.isEmpty ? 'apply_store_failed' : message);
    }
    final data = decoded['data'];
    if (data is! Map) return null;
    final userMap = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : Map<String, dynamic>.from(data);
    return userFromServer(
      userMap,
      passwordHash: '',
      allowEmptyPassword: true,
    );
  }

  static Future<Map<String, dynamic>?> fetchUploadQuota(String userId) async {
    if (!enabled) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/uploadQuota'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != 1) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> consumeUpload(String userId) async {
    if (!enabled) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/consumeUpload'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      if (decoded['success'] != 1) {
        throw Exception('${decoded['message'] ?? 'upload_limit'}');
      }
      final data = decoded['data'];
      if (data is! Map) return {};
      return Map<String, dynamic>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> inviteOrgMember({
    required String userId,
    required String email,
  }) async {
    if (!enabled) throw Exception('offline');
    final res = await http
        .post(
          Uri.parse('$baseUrl/inviteOrgMember'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode({'user_id': userId, 'email': email}),
        )
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != 1) {
      throw Exception('${decoded is Map ? decoded['message'] : 'invite_failed'}');
    }
  }

  static Future<void> replaceOrgSeat({
    required String userId,
    required String oldEmail,
    required String newEmail,
  }) async {
    if (!enabled) throw Exception('offline');
    final res = await http
        .post(
          Uri.parse('$baseUrl/replaceOrgSeat'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode({
            'user_id': userId,
            'old_email': oldEmail.trim().toLowerCase(),
            'new_email': newEmail.trim().toLowerCase(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != 1) {
      throw Exception(
        '${decoded is Map ? decoded['message'] : 'replace_failed'}',
      );
    }
  }

  static Future<void> requestChangeEmail({
    required String userId,
    required String newEmail,
  }) async {
    if (!enabled) throw Exception('offline');
    final res = await http
        .post(
          Uri.parse('$baseUrl/requestChangeEmail'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'user_id': userId,
            'new_email': newEmail.trim().toLowerCase(),
          })),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != 1) {
      throw Exception(
        '${decoded is Map ? decoded['message'] : 'change_email_failed'}',
      );
    }
  }

  static Future<AppUser> confirmChangeEmail({
    required String userId,
    required String newEmail,
    required String code,
  }) async {
    if (!enabled) throw Exception('offline');
    final res = await http
        .post(
          Uri.parse('$baseUrl/confirmChangeEmail'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode(_withClient({
            'user_id': userId,
            'new_email': newEmail.trim().toLowerCase(),
            'code': code.trim(),
          })),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != 1) {
      throw Exception(
        '${decoded is Map ? decoded['message'] : 'change_email_failed'}',
      );
    }
    final data = decoded['data'];
    if (data is! Map) throw Exception('change_email_failed');
    final userMap = data['user'];
    if (userMap is! Map) throw Exception('change_email_failed');
    return userFromServer(
      Map<String, dynamic>.from(userMap),
      passwordHash: '',
      allowEmptyPassword: true,
    );
  }

  static Future<OrgTeamSnapshot> orgMembers(String userId) async {
    if (!enabled) return OrgTeamSnapshot.empty;
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/orgMembers'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return OrgTeamSnapshot.empty;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != 1) {
        return OrgTeamSnapshot.empty;
      }
      final data = decoded['data'];
      if (data is! Map) return OrgTeamSnapshot.empty;
      return OrgTeamSnapshot.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return OrgTeamSnapshot.empty;
    }
  }

  static Future<AppUser?> sync(
    AppUser user, {
    String? deviceId,
    bool claim = false,
    String deviceLabel = '',
    String? appleOriginalTxn,
    String? appleProductId,
    String? appleStatus,
  }) async {
    if (!enabled) return null;
    try {
      final payload = toPayload(
        user,
        deviceId: deviceId,
        claim: claim,
        deviceLabel: deviceLabel,
        appleOriginalTxn: appleOriginalTxn,
        appleProductId: appleProductId,
        appleStatus: appleStatus,
      );
      final res = await http
          .post(
            Uri.parse('$baseUrl/syncUser'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      if (decoded['success'] != 1) {
        final message = '${decoded['message'] ?? ''}';
        if (message.contains(DeviceSwitchCooldownException.code)) {
          throw const DeviceSwitchCooldownException();
        }
        if (DeviceSession.isKickedMessage(message)) {
          throw const SessionKickedException();
        }
        if (message.contains('既に登録')) {
          throw Exception(message);
        }
        return null;
      }
      final data = decoded['data'];
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (DeviceSession.isKickedMessage('${map['session_kicked'] ?? ''}')) {
        throw const SessionKickedException();
      }
      if (map['session_kicked'] == 1 || map['session_kicked'] == true) {
        throw const SessionKickedException();
      }
      await acceptOrgInvite(userId: user.id);
      return applyServer(user, map);
    } on DeviceSwitchCooldownException {
      rethrow;
    } on SessionKickedException {
      rethrow;
    } on Exception catch (e) {
      if (e.toString().contains(DeviceSwitchCooldownException.code)) {
        throw const DeviceSwitchCooldownException();
      }
      if (e.toString().contains('既に登録')) rethrow;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> releaseDevice({
    required String userId,
    required String deviceId,
  }) async {
    if (!enabled || userId.isEmpty || deviceId.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/releaseDevice'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({
              'user_id': userId,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// アカウント削除（パスワード再確認）。成功時はサーバー上の個人情報を破棄。
  static Future<void> deleteAccount({
    required String userId,
    required String passwordHash,
  }) async {
    if (!enabled) throw Exception('offline');
    final res = await http
        .post(
          Uri.parse('$baseUrl/deleteAccount'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Lgsplus-Key': appKey,
          },
          body: jsonEncode({
            'user_id': userId,
            'password_hash': passwordHash,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != 1) {
      final message = decoded is Map ? '${decoded['message'] ?? ''}'.trim() : '';
      throw Exception(message.isEmpty ? 'delete_account_failed' : message);
    }
  }

  static Map<String, dynamic> toPayload(
    AppUser user, {
    String? deviceId,
    bool claim = false,
    String deviceLabel = '',
    String? appleOriginalTxn,
    String? appleProductId,
    String? appleStatus,
  }) =>
      {
        'id': user.id,
        'company_name': user.companyName,
        'contact_name': user.contactName,
        'phone': user.phone,
        'email': user.email,
        'client_app': clientApp,
        'address': user.address,
        'invite_code': user.inviteCode,
        'referred_by_code': user.referredByCode,
        'plan': user.isPaid ? 'paid' : 'free',
        'access_until': user.accessUntil.toIso8601String(),
        'activated': user.activated ? 1 : 0,
        if (user.passwordHash != null && user.passwordHash!.isNotEmpty)
          'password_hash': user.passwordHash,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        'claim': claim ? 1 : 0,
        if (deviceLabel.isNotEmpty) 'device_label': deviceLabel,
        if (appleOriginalTxn != null && appleOriginalTxn.isNotEmpty)
          'apple_original_txn': appleOriginalTxn,
        if (appleProductId != null && appleProductId.isNotEmpty)
          'apple_product_id': appleProductId,
        if (appleStatus != null && appleStatus.isNotEmpty)
          'apple_status': appleStatus,
      };

  static AppUser applyServer(AppUser local, Map<String, dynamic> data) {
    var next = local;
    final serverEmail = '${data['email'] ?? ''}'.trim().toLowerCase();
    if (serverEmail.isNotEmpty && serverEmail != next.email.trim().toLowerCase()) {
      next = next.copyWith(email: serverEmail);
    }
    final apple = '${data['apple_status'] ?? ''}';
    if (_endedApple.contains(apple)) {
      next = next.copyWith(
        plan: SubscriptionPlan.free,
        seatLimit: 0,
        uploadUnlimited: false,
        clearProductId: true,
        accessUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
    } else if (_activeApple.contains(apple)) {
      if (local.email != 'test@lgsplus.local') {
        next = next.copyWith(plan: SubscriptionPlan.paid);
      }
    } else if (data['plan'] == 'paid' && local.email != 'test@lgsplus.local') {
      next = next.copyWith(plan: SubscriptionPlan.paid);
    }

    // 無料は期限特典なし。サーバが access_until を空にしたらローカルの旧7日残も消す
    final untilRaw = '${data['access_until'] ?? ''}'.trim();
    if (!next.isPaid && untilRaw.isEmpty) {
      final past = DateTime.now().subtract(const Duration(days: 1));
      if (next.accessUntil.isAfter(past)) {
        next = next.copyWith(accessUntil: past);
      }
    }

    final until = parseDate(data['access_until']);
    if (until != null &&
        until.isAfter(next.accessUntil) &&
        !_endedApple.contains(apple) &&
        !(local.email == 'test@lgsplus.local' && !local.isPaid) &&
        (next.isPaid || '${data['plan']}' != 'paid')) {
      final serverNotice = '${data['pending_notice'] ?? ''}'.trim();
      next = next.copyWith(
        accessUntil: until,
        pendingNotice: serverNotice.isNotEmpty
            ? serverNotice
            : AccountPlan.bonusNotice,
      );
    } else {
      final serverNotice = '${data['pending_notice'] ?? ''}'.trim();
      if (serverNotice.isNotEmpty) {
        next = next.copyWith(pendingNotice: serverNotice);
      }
    }

    final quota = data['upload_quota'];
    if (quota is Map) {
      next = next.copyWith(
        uploadUnlimited: _jsonBool(quota['unlimited']) || next.uploadUnlimited,
        uploadRemaining: _asInt(quota['remaining']) ?? next.uploadRemaining,
        uploadLimit: _asInt(quota['limit']) ?? next.uploadLimit,
        uploadUsed: _asInt(quota['used']) ?? next.uploadUsed,
        uploadBonus: _asInt(quota['bonus']) ?? next.uploadBonus,
      );
    }
    final org = data['org'];
    if (org is Map) {
      final status = '${org['status'] ?? 'active'}';
      final ownerId = org['owner_user_id'] as String?;
      next = next.copyWith(
        seatLimit: _asInt(org['seat_limit']) ?? next.seatLimit,
        productId: (org['product_id'] as String?) ?? next.productId,
        orgOwnerUserId: ownerId ?? next.orgOwnerUserId,
      );
      if (status == 'active' || status.isEmpty) {
        if (local.email != 'test@lgsplus.local') {
          next = next.copyWith(
            plan: SubscriptionPlan.paid,
            uploadUnlimited: true,
            uploadRemaining: -1,
          );
        }
      }
    } else if (data.containsKey('org') && data['org'] == null) {
      next = next.copyWith(clearOrgOwner: true);
    }
    if (data['plan'] == 'paid' && next.isPaid) {
      next = next.copyWith(uploadUnlimited: true);
    }
    if (_endedApple.contains(apple)) {
      next = next.copyWith(
        plan: SubscriptionPlan.free,
        uploadUnlimited: false,
        seatLimit: 0,
        clearProductId: true,
        clearOrgOwner: true,
      );
    }
    return next;
  }

  static bool _jsonBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.toLowerCase().trim();
      return t == 'true' || t == '1';
    }
    return false;
  }

  static Future<void> acceptOrgInvite({
    required String userId,
    String token = '',
  }) async {
    if (!enabled) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/acceptOrgInvite'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode({'user_id': userId, 'token': token}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Map<String, dynamic> reportPayload({
    required AppUser user,
    required String kind,
    required String title,
    required String body,
    String lang = 'ja',
    List<Map<String, String>> images = const [],
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
        if (images.isNotEmpty) 'images': images,
      };

  /// null=成功 / 文字列=エラー
  static Future<String?> submitReport({
    required AppUser user,
    required String kind,
    required String title,
    required String body,
    String lang = 'ja',
    List<Map<String, String>> images = const [],
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
              images: images,
            )),
          )
          .timeout(Duration(seconds: images.isEmpty ? 8 : 45));
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

  /// 運営お知らせ一覧
  static Future<List<OpsNotice>> listNotices({int limit = 50}) async {
    if (!enabled) return const [];
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/listNotices'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Lgsplus-Key': appKey,
            },
            body: jsonEncode(_withClient({
              'limit': limit,
            })),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != 1) return const [];
      final data = decoded['data'];
      if (data is! Map) return const [];
      final raw = data['notices'];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            OpsNotice.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  static DateTime? parseDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }
}
