import '../models/models.dart';

/// 電話番号・氏名によるアカウント照合（オフライン）
class AccountRecovery {
  AccountRecovery._();

  static const notFoundMessage = 'アカウントが見つかりませんでした';

  static String normalizePhone(String raw) {
    final half = _toHalfWidthDigits(raw);
    var s = half.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('+81')) {
      s = '0${s.substring(3)}';
    } else if (s.startsWith('81') && s.length >= 12) {
      s = '0${s.substring(2)}';
    }
    return s;
  }

  static String normalizeName(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').trim();
  }

  static bool namesMatch(String a, String b) =>
      normalizeName(a) == normalizeName(b) && normalizeName(a).isNotEmpty;

  static String joinFamilyGiven(String family, String given) =>
      '${family.trim()} ${given.trim()}'.trim();

  static bool storedNameMatches(AppUser user, String input) {
    return namesMatch(user.contactName, input) ||
        namesMatch(user.companyName, input);
  }

  static AppUser? matchByPhoneAndName({
    required List<AppUser> users,
    required String phone,
    required String name,
    String familyName = '',
    String givenName = '',
  }) {
    final key = normalizePhone(phone);
    if (key.isEmpty) return null;
    final input = familyName.isNotEmpty || givenName.isNotEmpty
        ? joinFamilyGiven(familyName, givenName)
        : name;
    if (normalizeName(input).isEmpty) return null;
    for (final user in users) {
      if (normalizePhone(user.phone) == key &&
          storedNameMatches(user, input)) {
        return user;
      }
    }
    return null;
  }

  static String _toHalfWidthDigits(String input) {
    final buf = StringBuffer();
    for (final r in input.runes) {
      if (r >= 0xFF10 && r <= 0xFF19) {
        buf.writeCharCode(r - 0xFF10 + 0x30);
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }
}
