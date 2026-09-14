import 'dart:math' as math;
import 'dart:ui';

import '../models/models.dart';

/// 天井骨格の1本
class CeilingBarSeg {
  CeilingBarSeg({
    required this.a,
    required this.b,
    required this.isW,
    this.isUke = false,
    this.isSquareStud = false,
  });
  final Offset a;
  final Offset b;
  /// Wバー（両端）。false＝シングルバー
  final bool isW;
  /// 野縁受け
  final bool isUke;
  /// SQ工法の角スタッド
  final bool isSquareStud;

  double get lengthPx => (b - a).distance;
}

class CeilingBoltPt {
  CeilingBoltPt(this.center);
  final Offset center;
}

class CeilingLayoutResult {
  CeilingLayoutResult({
    required this.noenBars,
    required this.ukeBars,
    required this.squareStudBars,
    required this.bolts,
    required this.wBarLengthM,
    required this.singleBarLengthM,
    required this.ukeBarLengthM,
    required this.squareStudLengthM,
  });

  final List<CeilingBarSeg> noenBars;
  final List<CeilingBarSeg> ukeBars;
  final List<CeilingBarSeg> squareStudBars;
  final List<CeilingBoltPt> bolts;
  final double wBarLengthM;
  final double singleBarLengthM;
  final double ukeBarLengthM;
  final double squareStudLengthM;

  int get boltCount => bolts.length;

  /// 角スタッドと野縁受けの交点（角スタクリップ数）
  int get squareStudUkeContactCount =>
      CeilingLayoutEngine.countBarCrossings(squareStudBars, ukeBars);
}

/// 野縁・野縁受・角スタッド・全ネジボルトの配置計算
class CeilingLayoutEngine {
  /// 全ネジ：辺縁から100mmに必ず1列（100〜150の下限）
  /// 全ネジ同士の間隔は ≤900mm（未満可）
  static const boltEdgeMm = 100.0;
  static const boltEdgeMaxMm = 150.0;
  static const maxBoltPitchMm = 900.0;
  static const squareStudPitchMm = 303.0;

  /// 互換：旧名（野縁受格子など）
  static const edgeInsetMm = boltEdgeMm;

  static CeilingLayoutResult layout({
    required List<Point2> points,
    required double scalePxPerMm,
    required CeilingMethod method,
  }) {
    if (points.length < 3 || scalePxPerMm <= 0) {
      return CeilingLayoutResult(
        noenBars: const [],
        ukeBars: const [],
        squareStudBars: const [],
        bolts: const [],
        wBarLengthM: 0,
        singleBarLengthM: 0,
        ukeBarLengthM: 0,
        squareStudLengthM: 0,
      );
    }

    var minX = points.first.x, maxX = points.first.x;
    var minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    final wMm = (maxX - minX) / scalePxPerMm;
    final hMm = (maxY - minY) / scalePxPerMm;

    final noenAlongX = !method.rotated90;
    final spanMm = noenAlongX ? hMm : wMm;
    final runMm = noenAlongX ? wMm : hMm;

    final isSq = method.systemKind == CeilingSystemKind.sq;

    // —— 野縁（在来のみ）——
    // ボード2層以上：施工仕様に関わらず 3×6 版のバー配置
    final boardLayerCount = method.finishBoardLayers.length > 1
        ? method.finishBoardLayers.length
        : method.layers.count;
    final noenPanel = (!isSq && boardLayerCount >= 2)
        ? CeilingPanelSpec.panel3x6
        : method.panelSpec;
    final barSlots = isSq
        ? const <({double posMm, bool isW})>[]
        : _placeNoenSlots(
            lengthMm: spanMm,
            panel: noenPanel,
            pitchMm: noenPanel == CeilingPanelSpec.panel3x6
                ? method.noenSpacingMm
                : method.barPitchMm,
          );

    final noenBars = <CeilingBarSeg>[];
    var wLenPx = 0.0;
    var sLenPx = 0.0;
    for (final slot in barSlots) {
      final seg = _barAlongRun(
        posMm: slot.posMm,
        scalePxPerMm: scalePxPerMm,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        noenAlongX: noenAlongX,
        isW: slot.isW,
      );
      noenBars.add(seg);
      if (slot.isW) {
        wLenPx += seg.lengthPx;
      } else {
        sLenPx += seg.lengthPx;
      }
    }

    // —— SQ：角スタッド（選択ピッチ）・両端は図形縁に密着 ——
    final squareStudBars = <CeilingBarSeg>[];
    var sqLenPx = 0.0;
    if (isSq) {
      final studPitch = method.sqStudPitchMm > 0
          ? method.sqStudPitchMm
          : squareStudPitchMm;
      for (final sMm in _placeFlushPitch(spanMm, studPitch)) {
        final seg = _barAlongRun(
          posMm: sMm,
          scalePxPerMm: scalePxPerMm,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          noenAlongX: noenAlongX,
          isW: true,
          isSquareStud: true,
        );
        squareStudBars.add(seg);
        sqLenPx += seg.lengthPx;
      }
    }

    // —— 野縁受・全ネジ ——
    // SQ：スタッド長>2200 のとき野縁受け1列。全ネジはその列の上だけ（辺縁100・間隔≤900）。
    final List<double> ukeSlots;
    if (isSq) {
      if (runMm > 2200) {
        ukeSlots = [runMm / 2];
      } else {
        ukeSlots = const [];
      }
    } else {
      ukeSlots = _placeBoltAxis(runMm);
    }

    // 全ネジの「線方向」格子（bbox基準）＝全赤線で共通 → 前後左右が揃う
    final alongSlots = _placeBoltAxis(spanMm);
    final minAlongPx = noenAlongX ? minY : minX;

    final ukeBars = <CeilingBarSeg>[];
    final bolts = <CeilingBoltPt>[];
    var ukeLenPx = 0.0;
    for (final uMm in ukeSlots) {
      final uPx = uMm * scalePxPerMm;
      final lineSegs = noenAlongX
          ? _clipAxisLineSegments(
              vertical: true,
              coord: minX + uPx,
              poly: points,
            )
          : _clipAxisLineSegments(
              vertical: false,
              coord: minY + uPx,
              poly: points,
            );
      for (final (a, b) in lineSegs) {
        final seg = CeilingBarSeg(a: a, b: b, isW: true, isUke: true);
        ukeBars.add(seg);
        ukeLenPx += seg.lengthPx;

        for (final p in _boltsOnUkeSegment(
          a: a,
          b: b,
          scalePxPerMm: scalePxPerMm,
          noenAlongX: noenAlongX,
          minAlongPx: minAlongPx,
          globalAlongSlotsMm: alongSlots,
        )) {
          bolts.add(CeilingBoltPt(p));
        }
      }
    }

    final mmPerPx = 1.0 / scalePxPerMm;
    return CeilingLayoutResult(
      noenBars: noenBars,
      ukeBars: ukeBars,
      squareStudBars: squareStudBars,
      bolts: bolts,
      wBarLengthM: wLenPx * mmPerPx / 1000.0,
      singleBarLengthM: sLenPx * mmPerPx / 1000.0,
      ukeBarLengthM: ukeLenPx * mmPerPx / 1000.0,
      squareStudLengthM: sqLenPx * mmPerPx / 1000.0,
    );
  }

  static CeilingBarSeg _barAlongRun({
    required double posMm,
    required double scalePxPerMm,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required bool noenAlongX,
    required bool isW,
    bool isSquareStud = false,
  }) {
    final posPx = posMm * scalePxPerMm;
    late Offset a;
    late Offset b;
    if (noenAlongX) {
      a = Offset(minX, minY + posPx);
      b = Offset(maxX, minY + posPx);
    } else {
      a = Offset(minX + posPx, minY);
      b = Offset(minX + posPx, maxY);
    }
    return CeilingBarSeg(
      a: a,
      b: b,
      isW: isW,
      isSquareStud: isSquareStud,
    );
  }

  /// 両端密着・一定ピッチ（SQ角スタッド用）
  static List<double> _placeFlushPitch(double lengthMm, double pitchMm) {
    if (lengthMm <= 0) return const [];
    if (lengthMm < pitchMm * 0.5) return [0, if (lengthMm > 0.5) lengthMm];
    final out = <double>[0];
    var x = pitchMm;
    while (x < lengthMm - 0.5) {
      out.add(x);
      x += pitchMm;
    }
    if ((out.last - lengthMm).abs() > 0.5) {
      out.add(lengthMm);
    } else {
      out[out.length - 1] = lengthMm;
    }
    return out;
  }

  /// 在来・野縁スロット（両端は縁に密着のW）
  static List<({double posMm, bool isW})> _placeNoenSlots({
    required double lengthMm,
    required CeilingPanelSpec panel,
    required double pitchMm,
  }) {
    if (lengthMm <= 1) {
      return [(posMm: 0, isW: true)];
    }

    switch (panel) {
      case CeilingPanelSpec.panel3x6:
        return _placeFromEdgeRepeat(
          lengthMm: lengthMm,
          unit: _unit36(pitchMm),
        );
      case CeilingPanelSpec.panel3x3:
        return _placeFromCenterRepeat(
          lengthMm: lengthMm,
          unit: const [
            (0.0, true),
            (303.0, false),
            (606.0, false),
            (910.0, true),
          ],
        );
      case CeilingPanelSpec.panel15x3:
        return _placeFromCenterRepeat(
          lengthMm: lengthMm,
          unit: const [
            (0.0, true),
            (227.0, false),
            (455.0, true),
          ],
        );
    }
  }

  /// 3×6：縁基準の1スパン相対位置（先頭W=0、末尾W=1820）
  static List<(double, bool)> _unit36(double pitchMm) {
    if (pitchMm <= 250) {
      // 227
      return const [
        (0.0, true),
        (227.0, false),
        (455.0, false),
        (683.0, false),
        (910.0, false),
        (1137.0, false),
        (1365.0, false),
        (1593.0, false),
        (1820.0, true),
      ];
    }
    if (pitchMm <= 330) {
      // 303
      return const [
        (0.0, true),
        (303.0, false),
        (606.0, false),
        (910.0, false),
        (1213.0, false),
        (1516.0, false),
        (1820.0, true),
      ];
    }
    // 364
    return const [
      (0.0, true),
      (364.0, false),
      (728.0, false),
      (1092.0, false),
      (1456.0, false),
      (1820.0, true),
    ];
  }

  /// 縁のWからユニットを繰り返し、対縁もW密着
  static List<({double posMm, bool isW})> _placeFromEdgeRepeat({
    required double lengthMm,
    required List<(double, bool)> unit,
  }) {
    final wSpan = unit.last.$1;
    final out = <({double posMm, bool isW})>[];

    void add(double pos, bool isW) {
      if (pos < -0.5 || pos > lengthMm + 0.5) return;
      final p = pos.clamp(0.0, lengthMm);
      if (out.isNotEmpty && (out.last.posMm - p).abs() < 0.75) {
        // 同一位置はW優先
        if (isW && !out.last.isW) {
          out[out.length - 1] = (posMm: p, isW: true);
        }
        return;
      }
      out.add((posMm: p, isW: isW));
    }

    add(0, true);
    var base = 0.0;
    while (base < lengthMm - 0.5) {
      // 先頭Wは共有済み → 2本目以降を追加
      for (var i = 1; i < unit.length; i++) {
        final (off, isW) = unit[i];
        final pos = base + off;
        if (pos > lengthMm + 0.5) {
          add(lengthMm, true);
          base = lengthMm;
          break;
        }
        if ((pos - lengthMm).abs() <= 0.75) {
          add(lengthMm, true);
          base = lengthMm;
          break;
        }
        add(pos, isW);
      }
      base += wSpan;
      if (base >= lengthMm - 0.5) break;
    }
    add(lengthMm, true);

    out.sort((a, b) => a.posMm.compareTo(b.posMm));
    // 先頭・末尾は必ずW
    if (out.isNotEmpty) {
      out[0] = (posMm: 0, isW: true);
      out[out.length - 1] = (posMm: lengthMm, isW: true);
    }
    return out;
  }

  /// 中心のWから左右にユニット繰り返し、両縁はW密着
  static List<({double posMm, bool isW})> _placeFromCenterRepeat({
    required double lengthMm,
    required List<(double, bool)> unit,
  }) {
    final wSpan = unit.last.$1;
    final center = lengthMm / 2;
    final raw = <({double posMm, bool isW})>[];

    void add(double pos, bool isW) {
      if (pos < -0.5 || pos > lengthMm + 0.5) return;
      final p = pos.clamp(0.0, lengthMm);
      for (var i = 0; i < raw.length; i++) {
        if ((raw[i].posMm - p).abs() < 0.75) {
          if (isW && !raw[i].isW) {
            raw[i] = (posMm: p, isW: true);
          }
          return;
        }
      }
      raw.add((posMm: p, isW: isW));
    }

    add(center, true);

    // 正方向
    var base = center;
    while (base < lengthMm - 0.5) {
      for (var i = 1; i < unit.length; i++) {
        final (off, isW) = unit[i];
        final pos = base + off;
        if (pos > lengthMm + 0.5) {
          add(lengthMm, true);
          base = lengthMm;
          break;
        }
        if ((pos - lengthMm).abs() <= 0.75) {
          add(lengthMm, true);
          base = lengthMm;
          break;
        }
        add(pos, isW);
      }
      base += wSpan;
      if (base >= lengthMm - 0.5) break;
    }

    // 負方向
    base = center;
    while (base > 0.5) {
      for (var i = 1; i < unit.length; i++) {
        final (off, isW) = unit[i];
        final pos = base - off;
        if (pos < -0.5) {
          add(0, true);
          base = 0;
          break;
        }
        if (pos.abs() <= 0.75) {
          add(0, true);
          base = 0;
          break;
        }
        add(pos, isW);
      }
      base -= wSpan;
      if (base <= 0.5) break;
    }

    add(0, true);
    add(lengthMm, true);

    raw.sort((a, b) => a.posMm.compareTo(b.posMm));
    if (raw.isNotEmpty) {
      raw[0] = (posMm: 0, isW: true);
      raw[raw.length - 1] = (posMm: lengthMm, isW: true);
    }
    return raw;
  }

  /// 全ネジ／受けの1軸配置：両端は辺縁100mm固定、間は≤900で均等
  static List<double> _placeBoltAxis(double lengthMm) {
    final edge = boltEdgeMm;
    if (lengthMm <= edge * 2) {
      // 狭すぎる場合は中央1点（辺縁条件を満たせない）
      return lengthMm > 0 ? [lengthMm / 2] : const [];
    }
    final first = edge; // 必ず100mm
    final last = lengthMm - edge; // 対辺も100mm
    final usable = last - first;
    if (usable <= 0.5) {
      return [first];
    }
    // 間隔が900を超えない本数
    final gaps = math.max(1, (usable / maxBoltPitchMm).ceil());
    final pitch = usable / gaps;
    assert(pitch <= maxBoltPitchMm + 1e-6);
    // pitch は通常 ≤900。辺縁は常に100（150未満）
    assert(first >= 100 && first < boltEdgeMaxMm + 1e-6);
    return [for (var i = 0; i <= gaps; i++) first + i * pitch];
  }

  /// 野縁受け線分上の全ネジ：頭尾100mm必須＋全体格子で前後左右整列、間隔≤900
  static List<Offset> _boltsOnUkeSegment({
    required Offset a,
    required Offset b,
    required double scalePxPerMm,
    required bool noenAlongX,
    required double minAlongPx,
    required List<double> globalAlongSlotsMm,
  }) {
    final lenPx = (b - a).distance;
    if (lenPx < 1 || scalePxPerMm <= 0) return const [];
    final lenMm = lenPx / scalePxPerMm;

    double alongPx(Offset p) => noenAlongX ? p.dy : p.dx;
    final aMm = (alongPx(a) - minAlongPx) / scalePxPerMm;
    final bMm = (alongPx(b) - minAlongPx) / scalePxPerMm;
    final lo = math.min(aMm, bMm);
    final hi = math.max(aMm, bMm);

    final pos = <double>{};
    if (lenMm <= boltEdgeMm * 2) {
      pos.add((lo + hi) / 2);
    } else {
      // 赤線の頭・尾から100mmは必ず
      pos.add(lo + boltEdgeMm);
      pos.add(hi - boltEdgeMm);
      // bbox基準の共通格子 → 他の赤線と前後左右が揃う
      for (final g in globalAlongSlotsMm) {
        if (g >= lo + boltEdgeMm - 0.5 && g <= hi - boltEdgeMm + 0.5) {
          pos.add(g);
        }
      }
    }

    var sorted = pos.toList()..sort();
    sorted = _fillGapsMaxPitch(sorted, maxBoltPitchMm);

    final denom = bMm - aMm;
    return [
      for (final m in sorted)
        Offset(
          a.dx + (b.dx - a.dx) * (denom.abs() < 1e-9 ? 0.5 : ((m - aMm) / denom).clamp(0.0, 1.0)),
          a.dy + (b.dy - a.dy) * (denom.abs() < 1e-9 ? 0.5 : ((m - aMm) / denom).clamp(0.0, 1.0)),
        ),
    ];
  }

  /// 連続点の間隔が [maxPitch] を超えないよう中間点を均等挿入
  static List<double> _fillGapsMaxPitch(List<double> sorted, double maxPitch) {
    if (sorted.length < 2) return sorted;
    final out = <double>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final prev = out.last;
      final next = sorted[i];
      final gap = next - prev;
      if (gap > maxPitch + 1e-6) {
        final n = math.max(1, (gap / maxPitch).ceil());
        final pitch = gap / n;
        for (var k = 1; k < n; k++) {
          out.add(prev + k * pitch);
        }
      }
      out.add(next);
    }
    return out;
  }

  /// 互換：線分相対オフセット（テスト・旧呼び出し用）
  static List<double> _boltOffsetsOnSegment(double lenMm) {
    if (lenMm <= 0) return const [];
    if (lenMm <= boltEdgeMm * 2) return [lenMm / 2];
    final first = boltEdgeMm;
    final last = lenMm - boltEdgeMm;
    final span = last - first;
    if (span <= 0.5) return [first];
    final gaps = math.max(1, (span / maxBoltPitchMm).ceil());
    final pitch = span / gaps;
    return [for (var i = 0; i <= gaps; i++) first + i * pitch];
  }

  /// 野縁受け（チャンネル）定尺本数。
  /// 各赤線長さを順に消費し、余り≥[minReuseLeftoverMm]は次の赤線に流用。
  static int countUkeChannelPieces({
    required List<double> ukeLengthsMm,
    required double stockLengthMm,
    double minReuseLeftoverMm = 2000,
  }) {
    if (stockLengthMm <= 0) return 0;
    var pieces = 0;
    var leftover = 0.0;
    for (final raw in ukeLengthsMm) {
      var need = raw;
      if (need <= 0) continue;
      if (leftover >= minReuseLeftoverMm) {
        final use = math.min(leftover, need);
        leftover -= use;
        need -= use;
        if (leftover < minReuseLeftoverMm) leftover = 0;
      }
      while (need > 1e-6) {
        pieces++;
        if (stockLengthMm + 1e-6 >= need) {
          leftover = stockLengthMm - need;
          if (leftover < minReuseLeftoverMm) leftover = 0;
          need = 0;
        } else {
          need -= stockLengthMm;
          leftover = 0;
        }
      }
    }
    return pieces;
  }

  /// 定尺継ぎ手数：1本の長さが定尺で足りないとき、对接箇所ごとに1個。
  /// 例）2本对接→1個、3本对接→2個。1本で足りれば0。
  static int countSpliceJoints({
    required List<double> lengthsMm,
    required double stockLengthMm,
  }) {
    if (stockLengthMm <= 0) return 0;
    var joints = 0;
    for (final len in lengthsMm) {
      if (len <= 1e-6) continue;
      final pieces = (len / stockLengthMm).ceil();
      if (pieces > 1) joints += pieces - 1;
    }
    return joints;
  }

  /// 2組の線分の交点数（軸平行を想定。角スタッド×野縁受け）
  static int countBarCrossings(
    List<CeilingBarSeg> aBars,
    List<CeilingBarSeg> bBars,
  ) {
    var n = 0;
    for (final a in aBars) {
      for (final b in bBars) {
        if (_axisSegIntersection(a.a, a.b, b.a, b.b) != null) n++;
      }
    }
    return n;
  }

  /// 角スタッドと直交する両側縁の合計長さ (mm)
  static double runnerPerpEdgeLengthMm({
    required List<Point2> points,
    required double scalePxPerMm,
    required CeilingMethod method,
    List<CeilingBarSeg> squareStudBars = const [],
  }) {
    if (points.length < 3 || scalePxPerMm <= 0) return 0;
    var sx = 0.0, sy = 0.0;
    if (squareStudBars.isNotEmpty) {
      final s = squareStudBars.first;
      sx = s.b.dx - s.a.dx;
      sy = s.b.dy - s.a.dy;
    } else {
      // SQ配置と同じ：野縁沿X時は角スタッドも水平
      final noenAlongX = !method.rotated90;
      sx = noenAlongX ? 1.0 : 0.0;
      sy = noenAlongX ? 0.0 : 1.0;
    }
    final sl = math.sqrt(sx * sx + sy * sy);
    if (sl < 1e-9) return 0;
    final ux = sx / sl;
    final uy = sy / sl;

    var sumPx = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final ex = b.x - a.x;
      final ey = b.y - a.y;
      final el = math.sqrt(ex * ex + ey * ey);
      if (el < 1) continue;
      final dot = (ex / el) * ux + (ey / el) * uy;
      // 角スタッド方向と直交（|dot|≈0）な辺を両側縁として合算
      if (dot.abs() <= 0.35) {
        sumPx += el;
      }
    }
    return sumPx / scalePxPerMm;
  }

  /// ランナー本数＝直交両側縁合計 ÷ 定尺（切り上げ）
  static int countRunnerPieces({
    required double edgeTotalMm,
    required double stockLengthMm,
  }) {
    if (edgeTotalMm <= 0 || stockLengthMm <= 0) return 0;
    return (edgeTotalMm / stockLengthMm).ceil();
  }

  static Offset? _axisSegIntersection(
    Offset a1,
    Offset a2,
    Offset b1,
    Offset b2, {
    double eps = 2.0,
  }) {
    final aHoriz = (a1.dy - a2.dy).abs() <= eps;
    final aVert = (a1.dx - a2.dx).abs() <= eps;
    final bHoriz = (b1.dy - b2.dy).abs() <= eps;
    final bVert = (b1.dx - b2.dx).abs() <= eps;
    if (aHoriz && bVert) {
      final y = (a1.dy + a2.dy) / 2;
      final x = (b1.dx + b2.dx) / 2;
      final aMinX = math.min(a1.dx, a2.dx) - eps;
      final aMaxX = math.max(a1.dx, a2.dx) + eps;
      final bMinY = math.min(b1.dy, b2.dy) - eps;
      final bMaxY = math.max(b1.dy, b2.dy) + eps;
      if (x >= aMinX && x <= aMaxX && y >= bMinY && y <= bMaxY) {
        return Offset(x, y);
      }
    } else if (aVert && bHoriz) {
      final x = (a1.dx + a2.dx) / 2;
      final y = (b1.dy + b2.dy) / 2;
      final aMinY = math.min(a1.dy, a2.dy) - eps;
      final aMaxY = math.max(a1.dy, a2.dy) + eps;
      final bMinX = math.min(b1.dx, b2.dx) - eps;
      final bMaxX = math.max(b1.dx, b2.dx) + eps;
      if (y >= aMinY && y <= aMaxY && x >= bMinX && x <= bMaxX) {
        return Offset(x, y);
      }
    }
    return null;
  }

  /// 垂直/水平ラインをポリゴン内の線分にクリップ
  static List<(Offset, Offset)> _clipAxisLineSegments({
    required bool vertical,
    required double coord,
    required List<Point2> poly,
  }) {
    final hits = <double>[];
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i];
      final q = poly[(i + 1) % poly.length];
      if (vertical) {
        final x1 = p.x, x2 = q.x;
        if ((x1 <= coord && coord < x2) || (x2 <= coord && coord < x1)) {
          final y = p.y + (coord - x1) * (q.y - p.y) / (x2 - x1);
          hits.add(y);
        }
      } else {
        final y1 = p.y, y2 = q.y;
        if ((y1 <= coord && coord < y2) || (y2 <= coord && coord < y1)) {
          final x = p.x + (coord - y1) * (q.x - p.x) / (y2 - y1);
          hits.add(x);
        }
      }
    }
    hits.sort();
    final out = <(Offset, Offset)>[];
    for (var i = 0; i + 1 < hits.length; i += 2) {
      final aVal = hits[i];
      final bVal = hits[i + 1];
      if ((bVal - aVal).abs() < 1) continue;
      final a = vertical ? Offset(coord, aVal) : Offset(aVal, coord);
      final b = vertical ? Offset(coord, bVal) : Offset(bVal, coord);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      if (_pointInPolygon(mid, poly)) {
        out.add((a, b));
      }
    }
    return out;
  }

  static bool _pointInPolygon(Offset p, List<Point2> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].x, yi = poly[i].y;
      final xj = poly[j].x, yj = poly[j].y;
      final intersect = ((yi > p.dy) != (yj > p.dy)) &&
          (p.dx <
              (xj - xi) * (p.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
