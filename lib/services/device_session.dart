import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app_platform.dart';

/// 端末ごとの固定 ID。1アカウント1端末の判定に使う
class DeviceSession {
  DeviceSession._();

  static const testEmail = 'test@lgsplus.local';
  static const kickedCode = 'session_kicked';
  static const _idKey = 'lgsplus_device_id';

  static String? _cachedId;

  static bool enforceFor(String email) =>
      email.trim().toLowerCase() != testEmail;

  static bool isKickedMessage(String message) =>
      message.contains(kickedCode);

  /// 管理画面・API 向けの端末種別ラベル
  static String platformLabel() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }

  /// サーバー上のアカウント区分（iOS / Mac / Windows は別アカウント）
  static String clientApp() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'mac';
    return 'ios';
  }

  static String normalizeClientApp(String? raw) =>
      AppPlatform.normalizeClientApp(raw);

  static Future<String> id() async {
    if (_cachedId != null && _cachedId!.isNotEmpty) return _cachedId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey) ?? '';
    if (id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_idKey, id);
    }
    _cachedId = id;
    return id;
  }
}

class SessionKickedException implements Exception {
  const SessionKickedException();

  @override
  String toString() => DeviceSession.kickedCode;
}

/// 端末のアカウント切替クールダウン中
class DeviceSwitchCooldownException implements Exception {
  const DeviceSwitchCooldownException();

  static const code = 'device_switch_cooldown';

  @override
  String toString() => code;
}
