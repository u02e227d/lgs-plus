import 'dart:math' as math;

import '../models/models.dart';

/// 下り天井の数量計算
class DropCalc {
  DropCalc._();

  /// 高さ段階（303mm刻み・「超えたら」）。0〜303→0、超303→1、超606→2…
  static int heightTierExceed303(double heightMm) {
    if (heightMm <= 303) return 0;
    return (heightMm / 303).ceil() - 1;
  }

  /// シングルバー倍数（在来L型）：1 + 超303ごとに+1 → ≦303:1、超303:2…
  static int singleBarMultL(double heightMm) {
    if (heightMm <= 0) return 1;
    return math.max(1, (heightMm / 303).ceil());
  }

  /// シングルバー倍数（在来梁型）：0、超303:2、超606:4…
  static int singleBarMultBeam(double heightMm) {
    return 2 * heightTierExceed303(heightMm);
  }

  /// 折れ線の長さ区間ごとに (幅＋高さ)×長さ を合算。
  /// 区間 i（points[i]→[i+1], i≥1）の幅：
  /// - i==1 → firstWidthMm
  /// - i≥2 → turnWidths[i] があれば更新、なければ直前の幅を継続
  /// 直角折りは中心線接続のため角の二重計上なし。
  static double areaM2Polyline({
    required List<Point2> points,
    required double scalePxPerMm,
    required double firstWidthMm,
    required double heightMm,
    Map<int, double> turnWidths = const {},
  }) {
    if (heightMm < 0 || scalePxPerMm <= 0) return 0;
    if (points.length < 3) {
      return areaM2(
        lengthMm: 0,
        widthMm: firstWidthMm,
        heightMm: heightMm,
      );
    }
    double segMm(int i) {
      final a = points[i];
      final b = points[i + 1];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      return math.sqrt(dx * dx + dy * dy) / scalePxPerMm;
    }

    var currentW = firstWidthMm;
    var area = 0.0;
    for (var i = 1; i < points.length - 1; i++) {
      if (i >= 2) {
        final tw = turnWidths[i];
        if (tw != null && tw > 0) currentW = tw;
      }
      final L = segMm(i);
      if (L <= 0) continue;
      area += ((currentW + heightMm) / 1000.0) * (L / 1000.0);
    }
    return area;
  }

  /// 展開面積 (㎡)＝(幅＋高さ)×長さ（単一幅）
  static double areaM2({
    required double lengthMm,
    required double widthMm,
    required double heightMm,
  }) {
    if (lengthMm <= 0 || (widthMm <= 0 && heightMm <= 0)) return 0;
    if (heightMm < 0) return 0;
    return ((widthMm + heightMm) / 1000.0) * (lengthMm / 1000.0);
  }

  static Map<int, double> turnWidthMap(List<DropTurnWidth> list) => {
        for (final t in list)
          if (t.widthMm > 0) t.turnIndex: t.widthMm,
      };

  static Map<String, double> calc({
    required double lengthMm,
    required double widthMm,
    required double heightMm,
    required DropMethod method,
    List<Point2> points = const [],
    double scalePxPerMm = 0,
    List<DropTurnWidth> turnWidths = const [],
  }) {
    final L = lengthMm;
    final W = widthMm;
    final H = heightMm;
    final twMap = turnWidthMap(turnWidths);
    final area = points.length >= 3 && scalePxPerMm > 0
        ? areaM2Polyline(
            points: points,
            scalePxPerMm: scalePxPerMm,
            firstWidthMm: W,
            heightMm: H,
            turnWidths: twMap,
          )
        : areaM2(lengthMm: L, widthMm: W, heightMm: H);
    final out = <String, double>{
      'drop_length_mm': L,
      'drop_width_mm': W,
      'drop_height_mm': H,
      'drop_area_m2': area,
      'drop_shape': method.shape == DropShape.lType ? 0 : 1,
      'drop_system': method.system == CeilingSystemKind.sq ? 0 : 1,
    };
    for (final t in turnWidths) {
      out['drop_turn_width_${t.turnIndex}_mm'] = t.widthMm;
    }
    if (L <= 0 || H <= 0) return out;

    if (method.system == CeilingSystemKind.sq) {
      _calcSq(out, L: L, W: W, H: H, method: method);
    } else {
      _calcZairai(out, L: L, W: W, H: H, method: method);
    }
    return out;
  }

  static void _calcSq(
    Map<String, double> out, {
    required double L,
    required double W,
    required double H,
    required DropMethod method,
  }) {
    final runStock = method.runnerLengthMm > 0 ? method.runnerLengthMm : 4000.0;
    final studStock = method.studLengthMm > 0 ? method.studLengthMm : 2800.0;
    final pitch = method.pitchMm > 0 ? method.pitchMm : 303.0;
    final runnerFactor = method.shape == DropShape.lType ? 4.0 : 6.0;
    final runnerPcs = (L * runnerFactor / runStock).ceilToDouble();
    out['runner_count'] = runnerPcs < 1 ? 1.0 : runnerPcs;
    out['runner_width_mm'] = method.runnerWidthMm;
    out['runner_length_mm'] = runStock;

    // (幅＋高さ×面)×(長さ÷間隔)+1 → 総延長÷定尺
    final depth = method.shape == DropShape.lType ? (W + H) : (W + H * 2);
    final along = L / pitch;
    final studTotalMm = depth * along + 1;
    final studPcs = studStock > 0
        ? (studTotalMm / studStock).ceilToDouble()
        : 0.0;
    out['stud_count'] = studPcs < 1 && studTotalMm > 0 ? 1.0 : studPcs;
    out['stud_length_mm'] = studStock;
    out['stud_pitch_mm'] = pitch;
    out['stud_total_mm'] = studTotalMm;
  }

  static void _calcZairai(
    Map<String, double> out, {
    required double L,
    required double W,
    required double H,
    required DropMethod method,
  }) {
    final runStock = method.runnerLengthMm > 0 ? method.runnerLengthMm : 4000.0;
    final wStock = method.wBarLengthMm > 0 ? method.wBarLengthMm : 4000.0;
    final sStock =
        method.singleBarLengthMm > 0 ? method.singleBarLengthMm : 4000.0;
    final chStock =
        method.channelLengthMm > 0 ? method.channelLengthMm : 4000.0;

    final runnerPcs = (L * 4 / runStock).ceilToDouble();
    out['runner_count'] = runnerPcs < 1 ? 1.0 : runnerPcs;
    out['runner_height_mm'] = method.runnerHeightMm;
    out['runner_length_mm'] = runStock;

    final wFactor = method.shape == DropShape.lType ? 2.0 : 4.0;
    final wPcs = (L * wFactor / wStock).ceilToDouble();
    out['w_bar_count'] = wPcs < 1 && L > 0 ? 1.0 : wPcs;
    out['w_bar_height_mm'] = method.wBarHeightMm;
    out['w_bar_length_mm'] = wStock;

    final sMult = method.shape == DropShape.lType
        ? singleBarMultL(H).toDouble()
        : singleBarMultBeam(H).toDouble();
    final sNeed = L * sMult;
    final sPcs = sMult <= 0
        ? 0.0
        : (sNeed / sStock).ceilToDouble();
    out['single_bar_count'] = sPcs;
    out['single_bar_height_mm'] = method.singleBarHeightMm;
    out['single_bar_length_mm'] = sStock;
    out['single_bar_mult'] = sMult;

    final chPitch = method.shape == DropShape.lType ? 800.0 : 400.0;
    final chTotal = H * (L / chPitch);
    final chPcs = chStock > 0 ? (chTotal / chStock).ceilToDouble() : 0.0;
    out['channel_count'] = chPcs < 1 && chTotal > 0 ? 1.0 : chPcs;
    out['channel_width_mm'] = method.channelWidthMm;
    out['channel_length_mm'] = chStock;
    out['channel_total_mm'] = chTotal;

    final bay = L / 800.0;
    out['w_clip_count'] = bay * 2;
    // シングルクリップ倍数＝シングルバーと同じ（≦303→1、超303→2…）
    final clipTier = method.shape == DropShape.lType
        ? singleBarMultL(H).toDouble()
        : singleBarMultBeam(H).toDouble();
    out['single_clip_count'] = bay * clipTier;
    out['w_clip_uke_mm'] = method.wClipUkeWidthMm;
    out['single_clip_uke_mm'] = method.singleClipUkeWidthMm;
  }
}
