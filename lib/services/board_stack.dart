import 'dart:math' as math;

import '../models/models.dart';
import 'edge_snap_engine.dart';
import 'lgs_catalog.dart';

/// 片面の石膏ボード構成（例: [12.5] / [12.5, 9.5]）
class BoardStackSpec {
  final List<double> layersMm;
  const BoardStackSpec(this.layersMm);

  double get totalMm => layersMm.fold(0.0, (s, e) => s + e);

  String get label {
    if (layersMm.isEmpty) return 'なし';
    return '${layersMm.map((e) => e == e.roundToDouble() ? e.toStringAsFixed(0) : e.toStringAsFixed(1)).join('+')}mm';
  }

  String get kindLabel => 'PB $label';

  /// 代表厚（積算の主ボード）＝最厚層
  BoardThickness get primaryThickness {
    if (layersMm.isEmpty) return BoardThickness.t12_5;
    final max = layersMm.reduce(math.max);
    if (max <= 10) return BoardThickness.t9_5;
    if (max >= 14) return BoardThickness.t15;
    return BoardThickness.t12_5;
  }

  BoardLayers get asLayersEnum => BoardLayersX.fromCount(layersMm.length);

  static const single12_5 = BoardStackSpec([12.5]);
  static const single9_5 = BoardStackSpec([9.5]);
  static const single15 = BoardStackSpec([15]);
  static const double12_5 = BoardStackSpec([12.5, 12.5]);
  static const mixed12_5_9_5 = BoardStackSpec([12.5, 9.5]);
  static const mixed9_5_12_5 = BoardStackSpec([9.5, 12.5]);
  static const mixed15_9_5 = BoardStackSpec([15, 9.5]);
  static const mixed12_5_15 = BoardStackSpec([12.5, 15]);

  /// 現場でよくある片面構成
  static const common = <BoardStackSpec>[
    single12_5,
    single9_5,
    single15,
    double12_5,
    mixed12_5_9_5,
    mixed9_5_12_5,
    mixed15_9_5,
    mixed12_5_15,
    BoardStackSpec([12.5, 12.5, 9.5]),
    BoardStackSpec([9.5, 9.5]),
  ];

  /// ギャップ列（mm）をボード層にマッチ
  static BoardStackSpec? matchGaps(List<double> gapsMm, {double tol = 2.2}) {
    if (gapsMm.isEmpty) return null;
    final snapped = <double>[];
    for (final g in gapsMm) {
      final hit = _snapBoardMm(g, tol: tol);
      if (hit == null) return null;
      snapped.add(hit);
    }
    // 既知構成と一致？
    for (final c in common) {
      if (c.layersMm.length != snapped.length) continue;
      var ok = true;
      for (var i = 0; i < snapped.length; i++) {
        if ((c.layersMm[i] - snapped[i]).abs() > 0.1) {
          ok = false;
          break;
        }
      }
      if (ok) return c;
    }
    return BoardStackSpec(snapped);
  }

  static double? _snapBoardMm(double mm, {double tol = 2.2}) {
    const cands = [9.5, 12.5, 15.0];
    double? best;
    var bestD = tol;
    for (final c in cands) {
      final d = (c - mm).abs();
      if (d <= bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }
}

/// 図面の平行線ギャップから片面のボード積層を推定
class BoardLayerLineDetector {
  BoardLayerLineDetector._();

  /// 壁中心線付近の平行線を符号付き距離で並べ、左右のギャップ列をボード化
  static ({
    BoardStackSpec? sideA,
    BoardStackSpec? sideB,
    double? finishedMm,
    double confidence,
  }) detect({
    required List<LineSeg> wallCenter,
    required List<LineSeg> allLines,
    required double scalePxPerMm,
  }) {
    if (wallCenter.length < 1 || scalePxPerMm <= 0) {
      return (sideA: null, sideB: null, finishedMm: null, confidence: 0);
    }
    final a = wallCenter.first.a;
    final b = wallCenter.first.b;
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 20) {
      return (sideA: null, sideB: null, finishedMm: null, confidence: 0);
    }
    final ux = dx / len;
    final uy = dy / len;
    final nx = -uy;
    final ny = ux;

    // 平行線の中点 → 符号付き垂距(mm)
    final dists = <double>[];
    for (final l in allLines) {
      final lx = l.b.x - l.a.x;
      final ly = l.b.y - l.a.y;
      final llen = math.sqrt(lx * lx + ly * ly);
      if (llen < 24) continue;
      final parallel = (ux * (lx / llen) + uy * (ly / llen)).abs();
      if (parallel < 0.9) continue;
      final mid = Point2((l.a.x + l.b.x) / 2, (l.a.y + l.b.y) / 2);
      final signedPx = (mid.x - a.x) * nx + (mid.y - a.y) * ny;
      final mm = signedPx / scalePxPerMm;
      if (mm.abs() < 2 || mm.abs() > 120) continue;
      dists.add(mm);
    }
    if (dists.length < 2) {
      return (sideA: null, sideB: null, finishedMm: null, confidence: 0);
    }

    dists.sort();
    // 近い距離をクラスタ
    final clusters = <double>[];
    for (final d in dists) {
      if (clusters.isEmpty || (d - clusters.last).abs() > 2.5) {
        clusters.add(d);
      } else {
        clusters[clusters.length - 1] =
            (clusters.last + d) / 2; // 平均
      }
    }

    final neg = clusters.where((e) => e < 0).map((e) => -e).toList()
      ..sort();
    final pos = clusters.where((e) => e > 0).toList()..sort();

    List<double> gapsFromOrigin(List<double> absSorted) {
      final gaps = <double>[];
      var prev = 0.0;
      var skippedStud = false;
      for (final x in absSorted) {
        final g = x - prev;
        if (!skippedStud && g > 18 && g < 55) {
          // スタッド半分をスキップ
          skippedStud = true;
          prev = x;
          continue;
        }
        if (g >= 7 && g <= 18) {
          gaps.add(g);
          prev = x;
          skippedStud = true;
        } else {
          prev = x;
        }
      }
      return gaps;
    }

    final gapsA = gapsFromOrigin(pos);
    final gapsB = gapsFromOrigin(neg);
    final stackA = BoardStackSpec.matchGaps(gapsA);
    final stackB = BoardStackSpec.matchGaps(gapsB);

    double? finished;
    if (pos.isNotEmpty && neg.isNotEmpty) {
      finished = pos.last + neg.last;
    }

    var conf = 0.2;
    if (stackA != null) conf += 0.3;
    if (stackB != null) conf += 0.3;
    if (stackA != null &&
        stackB != null &&
        stackA.label != stackB.label) {
      conf += 0.15; // 非対称を検出できた
    }

    return (
      sideA: stackA,
      sideB: stackB,
      finishedMm: finished,
      confidence: conf.clamp(0.0, 0.95),
    );
  }
}
