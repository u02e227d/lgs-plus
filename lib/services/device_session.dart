import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
