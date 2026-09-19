import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../l10n/locale_controller.dart';
import '../models/models.dart';
import 'account_plan.dart';
import 'account_recovery.dart';
import 'device_session.dart';
import 'lgsplus_cloud.dart';

/// 認証：クラウド登録 → メール認証コード → パスワード設定で活性化
class AuthService {
  AuthService(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  String _hash(String password) =>
      sha256.convert(utf8.encode('lgs+$password')).toString();

  S get _s => LocaleController.instance.strings;

  String _wrongClientMessage(String clientApp) {
    switch (DeviceSession.normalizeClientApp(clientApp)) {
      case 'mac':
        return _s.accountForMacOnly;
      case 'windows':
        return _s.accountForWindowsOnly;
      default:
        return _s.accountForIosOnly;
    }
  }

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
    if (phoneKey.isEmpty || phoneKey.length < 10 || phoneKey.length > 11) {
      throw Exception(_s.invalidPhone);
    }
    if (!_looksLikeEmail(normalized)) {
      throw Exception(_s.invalidEmail);
    }
    if (address.trim().length < 4) {
      throw Exception(_s.invalidAddress);
    }
    if (AccountRecovery.normalizeName(contactName).isEmpty) {
      throw Exception(_s.pleaseEnter(_s.contactNameLabel));
    }
    final resolvedCompany =
        companyName.trim().isEmpty ? contactName.trim() : companyName.trim();
    // 端末ローカルに昔の活性化データが残っていても、クラウドが空なら再登録可。
    final cloudConflict = await LgsplusCloud.registrationConflict(
      email: normalized,
      phone: phone,
      companyName: resolvedCompany,
    );
    if (cloudConflict != null) {
      throw Exception(cloudConflict);
    }
    // クラウド未登録＝ローカル残骸を掃除（上書きインストールでは DB が残る）
    final staleByEmail = await _db.findUserByEmail(
      normalized,
      clientApp: DeviceSession.clientApp(),
    );
    if (staleByEmail != null) {
      await _db.deleteUser(staleByEmail.id);
    }
    // 同一会社の同僚は電話番号を共有できるため、電話だけではローカルを消さない
    final code = AccountPlan.friendInviteEnabled
        ? AccountPlan.normalizeInviteCode(inviteCode ?? '')
        : '';
    if (code.isNotEmpty) {
      final exists = await LgsplusCloud.inviteExists(code);
      if (exists == false) {
        throw Exception(_s.inviteNotFound);
      }
    }
    final localId = _uuid.v4();
    try {
      final remote = await LgsplusCloud.registerUser(
        id: localId,
        companyName: resolvedCompany,
        address: address.trim(),
        contactName: contactName.trim(),
        phone: phone.trim(),
        email: normalized,
        inviteCode: code.isEmpty ? null : code,
      );
      final now = DateTime.now();
      var user = AppUser(
        id: remote.id.isNotEmpty ? remote.id : localId,
        companyName: resolvedCompany,
        address: address.trim(),
        contactName: contactName.trim(),
        phone: phone.trim(),
        email: normalized,
        clientApp: DeviceSession.clientApp(),
        activated: false,
        inviteCode: remote.inviteCode.trim().isNotEmpty
            ? remote.inviteCode
            : await _uniqueInviteCode(),
        referredByCode: code.isEmpty ? null : code,
        createdAt: remote.createdAt,
      );
      // 試用期間は setPassword（サーバー活性化）時に確定。ここでは仮置き。
      user = AccountPlan.applySignupTrial(user, now);
      await _db.upsertUser(user);
      await _db.setSession('pending_activation:$normalized', user.id);
      await _db.setSession('email_verified:$normalized', '0');
      return user;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message == 'offline') {
        throw Exception(_s.networkRequired);
      }
      throw Exception(message.isEmpty ? _s.registerFailed : message);
    }
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
    bool passwordReset = false,
  }) async {
    final normalized = email.trim().toLowerCase();
    try {
      await LgsplusCloud.verifyEmailCode(
        email: normalized,
        code: code,
        passwordReset: passwordReset,
      );
      await _db.setSession(
        passwordReset
            ? 'password_reset_verified:$normalized'
            : 'email_verified:$normalized',
        '1',
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(message.isEmpty ? _s.verifyCodeInvalid : message);
    }
  }

  Future<String> resendEmailCode({
    required String email,
    bool passwordReset = false,
  }) async {
    final normalized = email.trim().toLowerCase();
    try {
      return await LgsplusCloud.resendEmailCode(
        email: normalized,
        passwordReset: passwordReset,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(message.isEmpty ? _s.resendFailed : message);
    }
  }

  /// メール認証後：パスワード設定で活性化（リセット時はサーバーで更新）
  Future<AppUser> activateWithPassword({
    required String email,
    required String password,
    bool isPasswordReset = false,
  }) async {
    if (password.length < 6) {
      throw Exception(_s.passwordTooShort);
    }
    final normalized = email.trim().toLowerCase();
    final hash = _hash(password);

    if (isPasswordReset) {
      try {
        final remote = await LgsplusCloud.resetPassword(
          email: normalized,
          passwordHash: hash,
        );
        final local = await _db.findUserByEmail(normalized, clientApp: DeviceSession.clientApp());
        final updated = AppUser(
          id: remote.id.isNotEmpty ? remote.id : (local?.id ?? _uuid.v4()),
          companyName: (local?.companyName.isNotEmpty ?? false)
              ? local!.companyName
              : remote.companyName,
          address: (local?.address.isNotEmpty ?? false)
              ? local!.address
              : remote.address,
          contactName: (local?.contactName.isNotEmpty ?? false)
              ? local!.contactName
              : remote.contactName,
          phone: (local?.phone.isNotEmpty ?? false)
              ? local!.phone
              : remote.phone,
          email: normalized,
          clientApp: DeviceSession.clientApp(),
          passwordHash: hash,
          activated: true,
          inviteCode: (local?.inviteCode.isNotEmpty ?? false)
              ? local!.inviteCode
              : remote.inviteCode,
          referredByCode: local?.referredByCode ?? remote.referredByCode,
          plan: remote.plan,
          accessUntil: remote.accessUntil,
          pendingNotice: remote.pendingNotice,
          createdAt: local?.createdAt ?? remote.createdAt,
          seatLimit: remote.seatLimit,
          productId: remote.productId,
          orgOwnerUserId: remote.orgOwnerUserId,
          uploadUnlimited: remote.uploadUnlimited,
          uploadRemaining: remote.uploadRemaining,
          uploadUsed: remote.uploadUsed,
          uploadBonus: remote.uploadBonus,
        );
        await _db.upsertUser(updated);
        await _db.setSession('current_user_id', updated.id);
        await _db.setSession('password_reset_verified:$normalized', '0');
        await _db.setSession('pending_reset:$normalized', '');
        return _syncCloud(updated, claim: true);
      } catch (e) {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        if (message.contains('email_not_verified')) {
          throw Exception(_s.emailNotVerified);
        }
        throw Exception(message.isEmpty ? _s.accountNotFoundDetail : message);
      }
    }

    try {
      final remote = await LgsplusCloud.setPassword(
        email: normalized,
        passwordHash: hash,
        deviceId: await DeviceSession.id(),
      );
      final local = await _db.findUserByEmail(normalized, clientApp: DeviceSession.clientApp());
      final activated = AppUser(
        id: remote.id.isNotEmpty ? remote.id : (local?.id ?? _uuid.v4()),
        companyName: (local?.companyName.isNotEmpty ?? false)
            ? local!.companyName
            : remote.companyName,
        address: (local?.address.isNotEmpty ?? false)
            ? local!.address
            : remote.address,
        contactName: (local?.contactName.isNotEmpty ?? false)
            ? local!.contactName
            : remote.contactName,
        phone: (local?.phone.isNotEmpty ?? false) ? local!.phone : remote.phone,
        email: normalized,
        clientApp: DeviceSession.clientApp(),
        passwordHash: hash,
        activated: true,
        inviteCode: (local?.inviteCode.isNotEmpty ?? false)
            ? local!.inviteCode
            : remote.inviteCode,
        referredByCode: local?.referredByCode ?? remote.referredByCode,
        plan: remote.plan,
        accessUntil: remote.accessUntil,
        pendingNotice: remote.pendingNotice,
        createdAt: local?.createdAt ?? remote.createdAt,
      );
      await _db.upsertUser(activated);
      await _db.setSession('current_user_id', activated.id);
      await _db.setSession('email_verified:$normalized', '0');
      return _syncCloud(activated, claim: true);
    } on DeviceSwitchCooldownException {
      rethrow;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.contains(DeviceSwitchCooldownException.code)) {
        throw const DeviceSwitchCooldownException();
      }
      if (message.contains('email_not_verified')) {
        throw Exception(_s.emailNotVerified);
      }
      throw Exception(message.isEmpty ? _s.registerFailed : message);
    }
  }

  bool _looksLikeEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final hash = _hash(password);
    final deviceId = await DeviceSession.id();
    final label = DeviceSession.platformLabel();
    final clientApp = DeviceSession.clientApp();

    Exception? mapLoginError(Object e) {
      final text = e.toString();
      if (text.contains(DeviceSwitchCooldownException.code)) {
        return const DeviceSwitchCooldownException();
      }
      if (text.contains('wrong_client_app:mac')) {
        return Exception(_s.accountForMacOnly);
      }
      if (text.contains('wrong_client_app:windows')) {
        return Exception(_s.accountForWindowsOnly);
      }
      if (text.contains('wrong_client_app:ios')) {
        return Exception(_s.accountForIosOnly);
      }
      if (text.contains('password_not_synced')) {
        return Exception(_s.passwordNotSynced);
      }
      if (text.contains('not_activated') || text.contains('未活性化')) {
        return Exception(_s.notActivated);
      }
      if (text.contains('Exception:')) {
        final msg = text.replaceFirst('Exception: ', '').trim();
        if (msg.isNotEmpty &&
            msg != 'null' &&
            !msg.contains('TimeoutException') &&
            !msg.contains('SocketException') &&
            !msg.contains('ClientException')) {
          return Exception(msg);
        }
      }
      return null;
    }

    // オンライン時は必ずクラウドでプラットフォーム照合（iOS↔Mac 相互ログイン禁止）
    if (LgsplusCloud.enabled) {
      try {
        final remote = await LgsplusCloud.login(
          email: normalized,
          passwordHash: hash,
          deviceId: deviceId,
          deviceLabel: label,
        );
        if (remote == null) {
          throw Exception(_s.badLogin);
        }
        final bound = remote.copyWith(clientApp: clientApp);
        await _db.upsertUser(bound);
        await _db.setSession('current_user_id', bound.id);
        return _syncCloud(bound, claim: true);
      } on DeviceSwitchCooldownException {
        rethrow;
      } on SessionKickedException {
        rethrow;
      } catch (e) {
        final mapped = mapLoginError(e);
        if (mapped != null) throw mapped;
        // 通信失敗時のみローカルへフォールバック
      }
    }

    var user = await _db.findUserByEmail(normalized, clientApp: DeviceSession.clientApp());
    if (user == null) {
      throw Exception(_s.badLogin);
    }
    if (user.clientApp != clientApp) {
      throw Exception(_wrongClientMessage(user.clientApp));
    }
    if (!user.activated || user.passwordHash == null) {
      throw Exception(_s.notActivated);
    }
    if (user.passwordHash != hash) {
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
    if (user.clientApp != DeviceSession.clientApp()) {
      await _db.clearSession();
      return null;
    }
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

  Future<AppUser> startPaidPlan(AppUser user, {String? productId}) async {
    final pid = (productId ?? AccountPlan.storeMonthlyProductId).trim();
    final seats = AccountPlan.seatsForProductId(pid);
    final next = user.copyWith(
      plan: SubscriptionPlan.paid,
      seatLimit: seats > 0 ? seats : 1,
      productId: pid,
      uploadUnlimited: true,
      uploadRemaining: -1,
      uploadLimit: -1,
    );
    await _db.upsertUser(next);
    try {
      final remote = await LgsplusCloud.applyStorePurchase(
        userId: user.id,
        productId: pid,
      );
      if (remote != null) {
        final merged = remote.copyWith(
          passwordHash: user.passwordHash,
          activated: true,
        );
        await _db.upsertUser(merged);
        return merged;
      }
    } catch (_) {}
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

  /// サーバーへパスワード再設定コードを送信。
  /// 戻り値: true=未完了の新規登録を再開（登録用認証コードを送った）
  Future<bool> requestPasswordResetByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_looksLikeEmail(normalized)) {
      throw Exception(_s.pleaseEnter(_s.email));
    }
    try {
      final resume =
          await LgsplusCloud.requestPasswordReset(email: normalized);
      if (resume) {
        await _db.setSession('pending_activation:$normalized', '1');
        await _db.setSession('email_verified:$normalized', '0');
        return true;
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.contains('offline')) {
        throw Exception(_s.networkRequired);
      }
      if (message.contains('wrong_client_app:mac')) {
        throw Exception(_s.accountForMacOnly);
      }
      if (message.contains('wrong_client_app:windows')) {
        throw Exception(_s.accountForWindowsOnly);
      }
      if (message.contains('wrong_client_app:ios')) {
        throw Exception(_s.accountForIosOnly);
      }
      throw Exception(
        message.isEmpty ? _s.accountNotFoundDetail : message,
      );
    }
    await _db.setSession('pending_reset:$normalized', '1');
    return false;
  }

  /// 中断した新規登録のメール認証コードを再送（未活性化アカウント向け）
  Future<void> resumeIncompleteRegistration(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_looksLikeEmail(normalized)) {
      throw Exception(_s.pleaseEnter(_s.email));
    }
    await resendEmailCode(email: normalized, passwordReset: false);
    await _db.setSession('pending_activation:$normalized', '1');
    await _db.setSession('email_verified:$normalized', '0');
  }

  /// 電話番号＋氏名でアカウントを探す。一致しなければ見つからない
  Future<AppUser> findAccountByPhoneAndName({
    required String phone,
    required String name,
    bool markPasswordReset = false,
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
    if (markPasswordReset) {
      await _markPendingReset(user);
    }
    return user;
  }

  Future<void> _markPendingReset(AppUser user) async {
    await _db.setSession('pending_reset:${user.email}', user.id);
  }

  /// テスト期間：認証スキップ用のデモユーザーで即ログイン
  Future<AppUser> ensureTestLogin() async {
    const email = 'test@lgsplus.local';
    var user = await _db.findUserByEmail(email, clientApp: DeviceSession.clientApp());
    if (user == null) {
      user = AppUser(
        id: _uuid.v4(),
        companyName: 'テスト建設',
        address: '東京都',
        contactName: 'テストユーザー',
        phone: '000-0000-0000',
        email: email,
        clientApp: DeviceSession.clientApp(),
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

  static String _storeTxnKey(String userId) =>
      'lgsplus_applied_store_txn_$userId';

  Future<AppUser> applyStorePaid(
    AppUser user, {
    String? purchaseId,
    String? productId,
    String? signedTransaction,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storeTxnKey(user.id);
    final already = prefs.getString(key);
    final shouldExtend = AccountPlan.shouldApplyPaidTransaction(
      purchaseId: purchaseId,
      alreadyAppliedPurchaseId: already,
    );
    final pid = (productId ?? user.productId ?? AccountPlan.storeMonthlyProductId)
        .trim();
    final seats = AccountPlan.seatsForProductId(pid);
    final signed = (signedTransaction ?? '').trim();
    if (signed.isEmpty) {
      throw Exception('purchase_verification_required');
    }

    // サーバー検証成功後のみ有料にする（クライアント自己申告は不可）
    final remote = await LgsplusCloud.applyStorePurchase(
      userId: user.id,
      productId: pid,
      originalTransactionId: purchaseId,
      signedTransaction: signed,
    );
    if (remote == null) {
      throw Exception('apply_store_failed');
    }
    final merged = remote.copyWith(
      passwordHash: user.passwordHash,
      activated: true,
      seatLimit: remote.seatLimit > 0
          ? remote.seatLimit
          : (seats > 0 ? seats : user.seatLimit),
      productId: pid,
      uploadUnlimited: true,
      uploadRemaining: -1,
      uploadLimit: -1,
      plan: SubscriptionPlan.paid,
    );
    final id = purchaseId?.trim() ?? '';
    if (shouldExtend && id.isNotEmpty) {
      await prefs.setString(key, id);
    }
    await _db.upsertUser(merged);
    return merged;
  }

  Future<AppUser> syncFromCloud(AppUser user, {bool claim = false}) =>
      _syncCloud(user, claim: claim);

  Future<AppUser> _syncCloud(
    AppUser user, {
    bool claim = false,
    String? appleOriginalTxn,
    String? appleProductId,
    String? appleStatus,
  }) async {
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
        deviceLabel: DeviceSession.platformLabel(),
        appleOriginalTxn: appleOriginalTxn,
        appleProductId: appleProductId,
        appleStatus: appleStatus,
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
    } on DeviceSwitchCooldownException {
      await logout(releaseCloud: false);
      rethrow;
    } on SessionKickedException {
      await logout(releaseCloud: false);
      rethrow;
    } catch (e) {
      if (e.toString().contains(DeviceSwitchCooldownException.code)) {
        await logout(releaseCloud: false);
        throw const DeviceSwitchCooldownException();
      }
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

  /// 席位オーナー：ログインメール変更用コードを新メールへ送信
  Future<void> requestOwnerEmailChange({
    required AppUser user,
    required String newEmail,
  }) async {
    final normalized = newEmail.trim().toLowerCase();
    if (!_looksLikeEmail(normalized)) {
      throw Exception(_s.invalidEmail);
    }
    if (normalized == user.email.trim().toLowerCase()) {
      throw Exception(_s.emailUnchanged);
    }
    try {
      await LgsplusCloud.requestChangeEmail(
        userId: user.id,
        newEmail: normalized,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.contains('offline')) {
        throw Exception(_s.networkRequired);
      }
      throw Exception(message.isEmpty ? _s.changeEmailFailed : message);
    }
  }

  /// 席位オーナー：認証コード確認後にローカルメールも更新
  Future<AppUser> confirmOwnerEmailChange({
    required AppUser user,
    required String newEmail,
    required String code,
  }) async {
    final normalized = newEmail.trim().toLowerCase();
    try {
      final remote = await LgsplusCloud.confirmChangeEmail(
        userId: user.id,
        newEmail: normalized,
        code: code,
      );
      final email =
          remote.email.trim().isNotEmpty ? remote.email.trim().toLowerCase() : normalized;
      final saved = user.copyWith(email: email);
      await _db.upsertUser(saved);
      await _db.setSession('current_user_id', saved.id);
      return saved;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(message.isEmpty ? _s.changeEmailFailed : message);
    }
  }

  /// 席位オーナー：招待中／参加済み同僚を別メールへ差し替え
  Future<void> replaceOrgSeatColleague({
    required AppUser owner,
    required String oldEmail,
    required String newEmail,
  }) async {
    final oldE = oldEmail.trim().toLowerCase();
    final newE = newEmail.trim().toLowerCase();
    if (!_looksLikeEmail(oldE) || !_looksLikeEmail(newE)) {
      throw Exception(_s.invalidEmail);
    }
    if (oldE == newE) {
      throw Exception(_s.emailUnchanged);
    }
    try {
      await LgsplusCloud.replaceOrgSeat(
        userId: owner.id,
        oldEmail: oldE,
        newEmail: newE,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.contains('offline')) {
        throw Exception(_s.networkRequired);
      }
      throw Exception(message.isEmpty ? _s.replaceColleagueFailed : message);
    }
  }

  /// アカウント削除：サーバー個人情報破棄 → 端末データ消去 → ログアウト
  Future<void> deleteAccount(String password) async {
    final id = await _db.getSession('current_user_id');
    final user = id == null || id.isEmpty ? null : await _db.findUserById(id);
    if (user == null) {
      throw Exception('not_logged_in');
    }
    final hash = _hash(password);
    if (user.passwordHash != null && user.passwordHash != hash) {
      throw Exception('wrong_password');
    }
    try {
      await LgsplusCloud.deleteAccount(userId: user.id, passwordHash: hash);
    } catch (e) {
      final text = e.toString();
      if (text.contains('offline') ||
          text.contains('SocketException') ||
          text.contains('TimeoutException') ||
          text.contains('Failed host lookup')) {
        throw Exception('delete_account_need_network');
      }
      rethrow;
    }
    await _db.wipeAllJobData();
    await _db.deleteUser(user.id);
    await _db.clearSession();
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'drawings'));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
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
