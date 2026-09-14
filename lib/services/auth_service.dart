import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../l10n/locale_controller.dart';
import '../models/models.dart';
import 'account_plan.dart';
import 'account_recovery.dart';
import 'device_session.dart';
import 'lgsplus_cloud.dart';

/// 認証（オフラインデモ：メール活性化リンク相当をローカルで模擬）
class AuthService {
  AuthService(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  String _hash(String password) =>
      sha256.convert(utf8.encode('lgs+$password')).toString();

  S get _s => LocaleController.instance.strings;

  Future<AppUser> register({
    required String companyName,
    required String address,
    required String contactName,
    required String phone,
    required String email,
    String? inviteCode,
  }) async {
    final normalized = email.trim().toLowerCase();
    final phoneKey = AccountRecovery.normalizePhone(phone);
    if (phoneKey.isEmpty) {
      throw Exception(_s.enterPhone);
    }
    final existing = await _db.findUserByEmail(normalized);
    if (existing != null) {
      throw Exception(_s.emailTaken);
    }
    final byPhone = await _db.findUserByPhone(phone);
    if (byPhone != null) {
      throw Exception(_s.phoneTaken);
    }
    final cloudConflict = await LgsplusCloud.registrationConflict(
      email: normalized,
      phone: phone,
    );
    if (cloudConflict != null) {
      throw Exception(cloudConflict);
    }
    final code = AccountPlan.normalizeInviteCode(inviteCode ?? '');
    if (code.isNotEmpty) {
      final exists = await LgsplusCloud.inviteExists(code);
      if (exists == false) {
        throw Exception(_s.inviteNotFound);
      }
    }
    final now = DateTime.now();
    var user = AppUser(
      id: _uuid.v4(),
      companyName: companyName.trim(),
      address: address.trim(),
      contactName: contactName.trim(),
      phone: phone.trim(),
      email: normalized,
      activated: false,
      inviteCode: await _uniqueInviteCode(),
      referredByCode: code.isEmpty ? null : code,
    );
    user = AccountPlan.applySignupTrial(user, now);
    await _db.upsertUser(user);
    await _db.setSession('pending_activation:$normalized', user.id);
    try {
      return await _syncCloud(user);
    } catch (e) {
      final message = e.toString();
      if (message.contains('既に登録')) {
        await _db.deleteUser(user.id);
      }
      rethrow;
    }
  }

  /// メールリンク相当：パスワード設定で活性化
  Future<AppUser> activateWithPassword({
    required String email,
    required String password,
  }) async {
    if (password.length < 6) {
      throw Exception(_s.passwordTooShort);
    }
    final normalized = email.trim().toLowerCase();
    final user = await _db.findUserByEmail(normalized);
    if (user == null) throw Exception(_s.accountNotFound);
    var activated = user.copyWith(
      passwordHash: _hash(password),
      activated: true,
    );
    if ((user.referredByCode ?? '').isNotEmpty) {
      activated = AccountPlan.applyBonus(activated, DateTime.now());
      activated = activated.copyWith(
        pendingNotice: '${AccountPlan.signupNotice}\n${AccountPlan.bonusNotice}',
      );
    }
    await _db.upsertUser(activated);
    await _db.setSession('current_user_id', activated.id);
    return _syncCloud(activated, claim: true);
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final user = await _db.findUserByEmail(email.trim().toLowerCase());
    if (user == null) throw Exception(_s.badLogin);
    if (!user.activated || user.passwordHash == null) {
      throw Exception(_s.notActivated);
    }
    if (user.passwordHash != _hash(password)) {
      throw Exception(_s.badLogin);
    }
    await _db.setSession('current_user_id', user.id);
    return _syncCloud(user, claim: true);
  }

  Future<AppUser?> currentUser() async {
    final id = await _db.getSession('current_user_id');
    if (id == null) return null;
    final user = await _db.findUserById(id);
    if (user == null) return null;
    return ensureAccountReady(user);
  }

  Future<String> _uniqueInviteCode() async {
    for (var i = 0; i < 12; i++) {
      final code = AccountPlan.generateInviteCode();
      final existing = await _db.findUserByInviteCode(code);
      if (existing == null) return code;
    }
    return AccountPlan.generateInviteCode();
  }

  Future<AppUser> ensureAccountReady(AppUser user) async {
    var next = user;
    if (next.inviteCode.trim().isEmpty) {
      next = next.copyWith(inviteCode: await _uniqueInviteCode());
    }
    if (next.inviteCode != user.inviteCode) {
      await _db.upsertUser(next);
    }
    return next;
  }

  Future<AppUser> startPaidPlan(AppUser user) async {
    final now = DateTime.now();
    final next = user.copyWith(
      plan: SubscriptionPlan.paid,
      accessUntil: AccountPlan.extendAccess(
        current: user.accessUntil,
        now: now,
        days: AccountPlan.paidMonthDays,
      ),
    );
    await _db.upsertUser(next);
    return _syncCloud(next);
  }

  Future<AppUser> cancelPaidPlan(AppUser user) async {
    final next = AccountPlan.cancelPaid(user, DateTime.now());
    await _db.upsertUser(next);
    return _syncCloud(next);
  }

  Future<AppUser> clearPendingNotice(AppUser user) async {
    final next = user.copyWith(clearNotice: true);
    await _db.upsertUser(next);
    return next;
  }

  /// メールアドレスでパスワード再設定（ローカル模擬：送信済みとして扱う）
  Future<AppUser> requestPasswordResetByEmail(String email) async {
    final user = await _db.findUserByEmail(email.trim().toLowerCase());
    if (user == null) {
      throw Exception(_s.accountNotFoundDetail);
    }
    await _markPendingReset(user);
    return user;
  }

  /// 電話番号＋氏名でアカウントを探す。一致しなければ見つからない
  Future<AppUser> findAccountByPhoneAndName({
    required String phone,
    required String name,
  }) async {
    final users = await _db.listUsers();
    final user = AccountRecovery.matchByPhoneAndName(
      users: users,
      phone: phone,
      name: name,
    );
    if (user == null) {
      throw Exception(_s.accountNotFoundDetail);
    }
    await _markPendingReset(user);
    return user;
  }

  Future<void> _markPendingReset(AppUser user) async {
    await _db.setSession('pending_reset:${user.email}', user.id);
  }

  /// テスト期間：認証スキップ用のデモユーザーで即ログイン
  Future<AppUser> ensureTestLogin() async {
    const email = 'test@lgsplus.local';
    var user = await _db.findUserByEmail(email);
    if (user == null) {
      user = AppUser(
        id: _uuid.v4(),
        companyName: 'テスト建設',
        address: '東京都',
        contactName: 'テストユーザー',
        phone: '000-0000-0000',
        email: email,
        passwordHash: _hash('test1234'),
        activated: true,
      );
      await _db.upsertUser(user);
    } else if (!user.activated || user.passwordHash == null) {
      user = user.copyWith(
        passwordHash: _hash('test1234'),
        activated: true,
      );
      await _db.upsertUser(user);
    }
    await _db.setSession('current_user_id', user.id);
    user = await ensureAccountReady(user);
    if (!user.isPaid && user.referredByCode == null && user.remainingDays() > 0) {
      user = user.copyWith(
        accessUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
      await _db.upsertUser(user);
    }
    return user;
  }

  Future<AppUser> syncFromCloud(AppUser user, {bool claim = false}) =>
      _syncCloud(user, claim: claim);

  Future<AppUser> _syncCloud(AppUser user, {bool claim = false}) async {
    if (!DeviceSession.enforceFor(user.email)) {
      try {
        final merged = await LgsplusCloud.sync(user);
        if (merged == null) return user;
        if (merged.plan != user.plan ||
            merged.accessUntil != user.accessUntil ||
            merged.pendingNotice != user.pendingNotice) {
          await _db.upsertUser(merged);
        }
        return merged;
      } catch (_) {
        return user;
      }
    }
    final pending = await _db.getSession('pending_session_claim') == '1';
    final take = claim || pending;
    try {
      final merged = await LgsplusCloud.sync(
        user,
        deviceId: await DeviceSession.id(),
        claim: take,
        deviceLabel: Platform.isIOS ? 'iOS' : 'Android',
      );
      if (merged == null) {
        if (take) await _db.setSession('pending_session_claim', '1');
        return user;
      }
      await _db.setSession('pending_session_claim', '0');
      if (merged.plan != user.plan ||
          merged.accessUntil != user.accessUntil ||
          merged.pendingNotice != user.pendingNotice) {
        await _db.upsertUser(merged);
      }
      return merged;
    } on SessionKickedException {
      await logout(releaseCloud: false);
      rethrow;
    } catch (_) {
      if (take) await _db.setSession('pending_session_claim', '1');
      return user;
    }
  }

  Future<void> logout({bool releaseCloud = true}) async {
    if (releaseCloud) {
      final id = await _db.getSession('current_user_id');
      if (id != null && id.isNotEmpty) {
        await LgsplusCloud.releaseDevice(
          userId: id,
          deviceId: await DeviceSession.id(),
        );
      }
    }
    await _db.clearSession();
  }
}

/// 図面ファイルをアプリ Documents にコピー
class DrawingImportService {
  static Future<File> persistBytes(List<int> bytes, String preferredName) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'drawings'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = File(p.join(dir.path, '${const Uuid().v4()}_$preferredName'));
    await dest.writeAsBytes(bytes, flush: true);
    return dest;
  }

  static Future<File> persistFile(File source, String preferredName) async {
    return persistBytes(await source.readAsBytes(), preferredName);
  }
}
