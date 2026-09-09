/// ボード／芯材構成の解析
/// 例: "12.5" / "12.5+" / "12.5+9.5" / "45+グラスウール"
class BoardSpecParse {
  BoardSpecParse._();

  static String _prep(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll('ｍｍ', '')
        .replaceAll('mm', '')
        .replaceAll('MM', '')
        .replaceAll('＋', '+')
        .trim();
  }

  /// "+" 区切りトークン（空は除く）
  static List<String> tokens(String? raw) {
    final t = _prep(raw);
    if (t.isEmpty) return const [];
    return t
        .split('+')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 数値レイヤのみ（石膏ボード用）
  static List<double> layers(String? raw) {
    final out = <double>[];
    for (final p in tokens(raw)) {
      final v = double.tryParse(p);
      if (v != null && v > 0) out.add(v);
    }
    return out;
  }

  static double total(String? raw) =>
      layers(raw).fold(0.0, (s, e) => s + e);

  /// 保存用正規化（末尾の空+は落とす）
  static String normalize(String? raw) {
    final ts = tokens(raw);
    if (ts.isEmpty) return '';
    return ts.join('+');
  }

  /// 表示用（入力途中の末尾+を残す）
  static String displayWithPlus(String? raw, {required String fallback}) {
    final t = _prep(raw);
    if (t.isEmpty) return fallback;
    return t;
  }

  static String kindLabel(String? raw) {
    final ls = layers(raw);
    if (ls.isEmpty) return '';
    final n = ls
        .map((e) =>
            e == e.roundToDouble() ? e.toStringAsFixed(0) : e.toStringAsFixed(1))
        .join('+');
    return 'PB ${n}mm';
  }

  /// 芯材（LGS枠）の先頭数値＝スタッド幅
  static double? firstNumber(String? raw) {
    for (final p in tokens(raw)) {
      final v = double.tryParse(p);
      if (v != null && v > 0) return v;
    }
    // "45形" など
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(_prep(raw));
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      if (v != null && v > 0) return v;
    }
    return null;
  }

  /// 数値以外の付帯材（グラスウールなど）
  static List<String> namedExtras(String? raw) {
    final out = <String>[];
    for (final p in tokens(raw)) {
      if (double.tryParse(p) == null) out.add(p);
    }
    return out;
  }
}
