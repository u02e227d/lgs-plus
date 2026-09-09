import 'dart:math' as math;

import '../models/models.dart';
import 'edge_snap_engine.dart';
import 'lgs_catalog.dart';

/// 図面上の壁厚・LGS形を端側CVで推定（オフライン）
class WallSpecSuggestion {
  final double? wallThicknessMm;
  final LgsForm suggestedForm;
  final LgsMethodPreset preset;
  final double confidence; // 0〜1
  final String summaryJa;

  const WallSpecSuggestion({
    required this.wallThicknessMm,
    required this.suggestedForm,
    required this.preset,
    required this.confidence,
    required this.summaryJa,
  });
}

class WallSpecDetector {
  /// [wallPoints] 図面座標の壁折れ線
  /// [scalePxPerMm] K
  /// [lines] エッジ抽出済み線分
  static WallSpecSuggestion detect({
    required List<Point2> wallPoints,
    required double scalePxPerMm,
    required List<LineSeg> lines,
  }) {
    if (wallPoints.length < 2 || scalePxPerMm <= 0) {
      final preset = LgsCatalog.presets.first;
      return WallSpecSuggestion(
        wallThicknessMm: null,
        suggestedForm: preset.form,
        preset: preset,
        confidence: 0,
        summaryJa: 'スケールまたは壁線が不足のため、標準65形を提案します',
      );
    }

    // 壁にほぼ平行な線分の、壁からの距離を収集 → 壁厚候補
    final thicknesses = <double>[];
    for (var i = 0; i < wallPoints.length - 1; i++) {
      final a = wallPoints[i];
      final b = wallPoints[i + 1];
      final segLen = CalcDist.dist(a, b);
      if (segLen < 20) continue;
      final dirX = (b.x - a.x) / segLen;
      final dirY = (b.y - a.y) / segLen;
      // 法線
      final nx = -dirY;
      final ny = dirX;

      for (final line in lines) {
        final lx = line.b.x - line.a.x;
        final ly = line.b.y - line.a.y;
        final llen = math.sqrt(lx * lx + ly * ly);
        if (llen < 30) continue;
        // 平行判定（角度）
        final dot = ((lx / llen) * dirX + (ly / llen) * dirY).abs();
        if (dot < 0.92) continue; // ~23°以内

        // 線分中点から壁への符号付き距離
        final mid = Point2(
          (line.a.x + line.b.x) / 2,
          (line.a.y + line.b.y) / 2,
        );
        final distPx = _signedDistToSegment(mid, a, b).abs();
        final distMm = distPx / scalePxPerMm;
        // 壁厚として妥当な範囲（20形薄壁〜厚壁）
        if (distMm >= 30 && distMm <= 160) {
          thicknesses.add(distMm);
        }
        // 二重線の間隔：壁と平行な別線との距離も使う
        final d2 = _parallelGapMm(line, lines, scalePxPerMm, nx, ny);
        if (d2 != null && d2 >= 30 && d2 <= 160) {
          thicknesses.add(d2);
        }
      }
    }

    double? thickness;
    var confidence = 0.25;
    if (thicknesses.isNotEmpty) {
      thicknesses.sort();
      thickness = _median(thicknesses);
      // クラスタが JIS 形に近いほど信頼度↑
      final form = LgsFormX.fromStudWidth((thickness - 25).clamp(20, 100));
      final expected = form.studWidthMm + 25; // 両面12.5想定
      final err = (thickness - expected).abs();
      confidence = (1.0 - err / 40).clamp(0.35, 0.95);
    }

    final preset = thickness == null
        ? LgsCatalog.presets.first
        : LgsCatalog.suggestFromThickness(thickness);

    final summary = thickness == null
        ? '壁厚を検出できませんでした。標準「${preset.name}」を提案します'
        : '壁厚 約 ${thickness.toStringAsFixed(0)}mm を検出 → '
            '${preset.form.label}（${preset.form.studCode} / ${preset.form.runnerCode}）'
            '・ボード${preset.boardThickness.label}'
            '・ピッチ@${preset.pitch == LgsPitch.p303 || preset.pitch == LgsPitch.p300 ? '303' : '455'} を提案';

    return WallSpecSuggestion(
      wallThicknessMm: thickness,
      suggestedForm: preset.form,
      preset: preset,
      confidence: confidence,
      summaryJa: summary,
    );
  }

  static double _median(List<double> xs) {
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    if (s.length.isOdd) return s[m];
    return (s[m - 1] + s[m]) / 2;
  }

  static double _signedDistToSegment(Point2 p, Point2 a, Point2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return CalcDist.dist(p, a);
    var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = Point2(a.x + t * dx, a.y + t * dy);
    final cross = (p.x - a.x) * dy - (p.y - a.y) * dx;
    final sign = cross >= 0 ? 1.0 : -1.0;
    return sign * CalcDist.dist(p, proj);
  }

  static double? _parallelGapMm(
    LineSeg line,
    List<LineSeg> all,
    double k,
    double nx,
    double ny,
  ) {
    final mid = Point2(
      (line.a.x + line.b.x) / 2,
      (line.a.y + line.b.y) / 2,
    );
    double? best;
    for (final other in all) {
      if (identical(other, line)) continue;
      final ox = other.b.x - other.a.x;
      final oy = other.b.y - other.a.y;
      final olen = math.sqrt(ox * ox + oy * oy);
      if (olen < 30) continue;
      final lx = line.b.x - line.a.x;
      final ly = line.b.y - line.a.y;
      final llen = math.sqrt(lx * lx + ly * ly);
      final dot = ((ox / olen) * (lx / llen) + (oy / olen) * (ly / llen)).abs();
      if (dot < 0.95) continue;
      final omid = Point2(
        (other.a.x + other.b.x) / 2,
        (other.a.y + other.b.y) / 2,
      );
      final gapPx = CalcDist.dist(mid, omid);
      final gapMm = gapPx / k;
      if (gapMm < 40 || gapMm > 160) continue;
      if (best == null || gapMm < best) best = gapMm;
    }
    return best;
  }
}
