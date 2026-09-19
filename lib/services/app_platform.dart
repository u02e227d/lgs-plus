import 'dart:io';

import 'package:flutter/foundation.dart';

/// 端末種別の共通判定（Windows 版はデスクトップ操作を Mac と同様に扱う）
class AppPlatform {
  AppPlatform._();

  static bool get isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// マウス／トラックパッド前提のナビ（拡大・右クリック削除など）
  static bool get usesDesktopPointer => isDesktop;

  /// ログイン画面を横長バナー配置にする
  static bool get usesDesktopLogin =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// サーバー・DB 用 client_app を正規化
  static String normalizeClientApp(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t == 'mac' || t == 'macos' || t == 'osx') return 'mac';
    if (t == 'windows' || t == 'win' || t == 'win32') return 'windows';
    return 'ios';
  }
}
