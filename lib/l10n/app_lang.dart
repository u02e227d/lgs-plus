import 'package:flutter/widgets.dart';

enum AppLang {
  ja,
  en,
  zh,
  vi;

  String get code => name;

  Locale get locale => Locale(code);

  String get nativeLabel => switch (this) {
        AppLang.ja => '日本語',
        AppLang.en => 'English',
        AppLang.zh => '中文',
        AppLang.vi => 'Tiếng Việt',
      };

  static AppLang fromDevice([Locale? raw]) {
    final loc = raw ?? WidgetsBinding.instance.platformDispatcher.locale;
    switch (loc.languageCode.toLowerCase()) {
      case 'ja':
        return AppLang.ja;
      case 'en':
        return AppLang.en;
      case 'zh':
        return AppLang.zh;
      case 'vi':
        return AppLang.vi;
      default:
        return AppLang.ja;
    }
  }

  static AppLang? tryParse(String? raw) {
    switch (raw) {
      case 'ja':
        return AppLang.ja;
      case 'en':
        return AppLang.en;
      case 'zh':
        return AppLang.zh;
      case 'vi':
        return AppLang.vi;
      default:
        return null;
    }
  }
}
