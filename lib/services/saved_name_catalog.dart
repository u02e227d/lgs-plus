import 'package:shared_preferences/shared_preferences.dart';

/// カスタム品名の永続化（入力後自動保存／スワイプ削除）
class SavedNameCatalog {
  SavedNameCatalog._();

  static const crossNames = 'cross_dedicated_cross_names';
  static const pasteNames = 'cross_dedicated_paste_names';
  static const pateNames = 'cross_dedicated_pate_custom_names';
  static const fiberTapeNames = 'cross_dedicated_fiber_tape_names';
  static const boardOtherNames = 'ceiling_board_other_custom_names';
  static const ceilingOtherNames = 'ceiling_lgs_other_custom_names';
  static const wallOtherNames = 'wall_other_custom_names';

  static Future<List<String>> load(String key) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key) ?? const <String>[];
    return [
      for (final e in raw)
        if (e.trim().isNotEmpty) e.trim(),
    ];
  }

  static Future<List<String>> add(String key, String name) async {
    final n = name.trim();
    if (n.isEmpty) return load(key);
    final cur = await load(key);
    if (cur.any((e) => e == n)) return cur;
    final next = [n, ...cur];
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, next);
    return next;
  }

  static Future<List<String>> remove(String key, String name) async {
    final n = name.trim();
    final next = [for (final e in await load(key)) if (e != n) e];
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, next);
    return next;
  }
}
