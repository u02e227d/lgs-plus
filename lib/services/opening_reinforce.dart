import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// 開口補強の6種（赤H形ベース・xlsx色分け）
enum OpeningReinforcePattern {
  /// ① 赤H形
  redH,
  /// ② 赤H＋橙（H上に横線）
  redHOrange,
  /// ③ 赤H＋緑＋黒（横2＋中央縦）
  redHGreenBlack,
  /// ④ 赤H＋緑＋青（H下に横2）
  redHGreenBlue,
  /// ⑤ 赤H＋黒（H下に縦1）
  redHBlack,
  /// ⑥ 四方形
  square,
}

extension OpeningReinforcePatternX on OpeningReinforcePattern {
  String get label {
    switch (this) {
      case OpeningReinforcePattern.redH:
        return '① 赤H形';
      case OpeningReinforcePattern.redHOrange:
        return '② 赤H＋橙';
      case OpeningReinforcePattern.redHGreenBlack:
        return '③ 赤H＋緑＋黒';
      case OpeningReinforcePattern.redHGreenBlue:
        return '④ 赤H＋緑＋青';
      case OpeningReinforcePattern.redHBlack:
        return '⑤ 赤H＋黒';
      case OpeningReinforcePattern.square:
        return '⑥ 四方形';
    }
  }

  /// 縦の色線本数（1本＝補強材1本）
  int get verticalLines {
    switch (this) {
      case OpeningReinforcePattern.redH:
      case OpeningReinforcePattern.redHOrange:
      case OpeningReinforcePattern.redHGreenBlue:
      case OpeningReinforcePattern.square:
        return 2;
      case OpeningReinforcePattern.redHGreenBlack:
      case OpeningReinforcePattern.redHBlack:
        return 3; // 両側＋内部縦
    }
  }

  /// 図形の横線本数（まぐさ1段時）
  int get graphicHorizontalLines {
    switch (this) {
      case OpeningReinforcePattern.redH:
      case OpeningReinforcePattern.redHBlack:
        return 1; // H横桟
      case OpeningReinforcePattern.redHOrange:
      case OpeningReinforcePattern.redHGreenBlack:
      case OpeningReinforcePattern.square:
        return 2;
      case OpeningReinforcePattern.redHGreenBlue:
        return 3; // 赤H横＋緑＋青
    }
  }

  /// まぐさ段数を増やすと増える横線（図形上のまぐさ枠）
  int get magusaSlots {
    switch (this) {
      case OpeningReinforcePattern.redH:
      case OpeningReinforcePattern.redHOrange:
      case OpeningReinforcePattern.redHGreenBlack:
      case OpeningReinforcePattern.redHGreenBlue:
      case OpeningReinforcePattern.redHBlack:
      case OpeningReinforcePattern.square:
        return 1;
    }
  }

  /// @deprecated 互換 — [graphicHorizontalLines] / [magusaSlots] を使用
  int get magusaBase => magusaSlots;

  /// @deprecated
  int get otherHorizontalLines =>
      math.max(0, graphicHorizontalLines - magusaSlots);

  int horizontalLines(int magusaSegments) {
    final seg = magusaSegments.clamp(1, 4);
    // 1段＝図形どおり。2段〜はまぐさ枠だけ増やす
    return graphicHorizontalLines + magusaSlots * (seg - 1);
  }

  /// 図形の色線総本数（縦＋横）
  int totalLines(int magusaSegments) =>
      verticalLines + horizontalLines(magusaSegments);

  /// 旧名称・現行名からパターン解決
  static OpeningReinforcePattern parse(String? name) {
    switch (name) {
      case 'redH':
      case 'redOnly':
        return OpeningReinforcePattern.redH;
      case 'redHOrange':
      case 'redOrange':
        return OpeningReinforcePattern.redHOrange;
      case 'redHGreenBlack':
      case 'redGreenBlack':
      case 'redGreen':
        return OpeningReinforcePattern.redHGreenBlack;
      case 'redHGreenBlue':
      case 'redGreenBlue':
        return OpeningReinforcePattern.redHGreenBlue;
      case 'redHBlack':
      case 'redBlack':
        return OpeningReinforcePattern.redHBlack;
      case 'square':
        return OpeningReinforcePattern.square;
      default:
        return OpeningReinforcePattern.redHOrange;
    }
  }
}

/// 定尺から開口幅ぶんの横材を何本にまとめるか。
/// 例④: 横3本×857、定尺2700 → 857+857+857=2571≤2700 → 横は1本。縦2＋横1＝3本。
int cutStockBars({
  required int memberCount,
  required double pieceMm,
  required double stockMm,
}) {
  if (memberCount <= 0 || pieceMm <= 0 || stockMm <= 0) return 0;
  return packPiecesOntoStock(
    piecesMm: List<double>.filled(memberCount, pieceMm),
    stockMm: stockMm,
  );
}

/// 複数の切寸を定尺へ順に割付。余りは次の切寸へ流用する。
/// 例）891 → 定尺2700（余り1809）、次の901は余りから取れる → 横材は計1本。
int packPiecesOntoStock({
  required List<double> piecesMm,
  required double stockMm,
}) {
  if (stockMm <= 0) return 0;
  var bars = 0;
  var leftover = 0.0;
  for (final raw in piecesMm) {
    var need = raw;
    if (need <= 0) continue;
    if (leftover + 1e-6 >= need) {
      leftover -= need;
      continue;
    }
    // 余りでは足りないので新規定尺を開く
    while (need > 1e-6) {
      bars++;
      if (stockMm + 1e-6 >= need) {
        leftover = stockMm - need;
        need = 0;
      } else {
        need -= stockMm;
        leftover = 0;
      }
    }
  }
  return bars;
}

class OpeningReinforceCalc {
  OpeningReinforceCalc._();

  /// 補強材本数＝縦線本数＋横線の定尺割付（単一開口）
  static int reinforceBars({
    required OpeningReinforcePattern pattern,
    required int magusaSegments,
    required double openingWidthMm,
    required double stockLengthMm,
  }) {
    final v = pattern.verticalLines;
    final hMembers = pattern.horizontalLines(magusaSegments);
    final h = cutStockBars(
      memberCount: hMembers,
      pieceMm: openingWidthMm,
      stockMm: stockLengthMm,
    );
    return v + h;
  }

  /// 複数開口の補強材本数。
  /// 縦は開口ごと計上、まぐさ（横）は端材を次開口へ流用して合算。
  /// 例）開口1: 縦2＋まぐさ891、開口2: 縦2＋まぐさ901、定尺2700 → 3+2=5本。
  static int reinforceBarsForOpenings({
    required List<WallOpening> openings,
    required double stockLengthMm,
  }) {
    if (stockLengthMm <= 0) return 0;
    var vertical = 0;
    final horizPieces = <double>[];
    for (final o in openings) {
      if (o.material != OpeningMaterialKind.reinforce) continue;
      if (o.widthMm <= 0) continue;
      final pattern = OpeningReinforcePatternX.parse(o.patternName);
      vertical += pattern.verticalLines;
      final hCount = pattern.horizontalLines(o.magusaSegments);
      for (var i = 0; i < hCount; i++) {
        horizPieces.add(o.widthMm);
      }
    }
    final horiz = packPiecesOntoStock(
      piecesMm: horizPieces,
      stockMm: stockLengthMm,
    );
    return vertical + horiz;
  }

  /// アングルピース個数＝図形の線本数×2
  static int anglePieces({
    required OpeningReinforcePattern pattern,
    required int magusaSegments,
  }) {
    return pattern.totalLines(magusaSegments) * 2;
  }

  /// ランナー延長 (mm)：縦＝開口高×本数、横＝開口幅×本数
  static double runnerMm({
    required OpeningReinforcePattern pattern,
    required int magusaSegments,
    required double openingWidthMm,
    required double openingHeightMm,
  }) {
    final v = pattern.verticalLines;
    final h = pattern.horizontalLines(magusaSegments);
    return v * openingHeightMm + h * openingWidthMm;
  }

  /// 開口が壁折れ線に近いか（両端・中点・開口線分のいずれか）
  static bool openingNearWall({
    required WallOpening opening,
    required WallSegment wall,
    double maxDistPx = 48,
  }) {
    final probes = <Offset>[
      Offset(opening.a.x, opening.a.y),
      Offset(opening.b.x, opening.b.y),
      Offset(
        (opening.a.x + opening.b.x) / 2,
        (opening.a.y + opening.b.y) / 2,
      ),
    ];
    for (final chain in wall.chains) {
      for (var i = 0; i < chain.length - 1; i++) {
        final wa = Offset(chain[i].x, chain[i].y);
        final wb = Offset(chain[i + 1].x, chain[i + 1].y);
        for (final p in probes) {
          if (_distToSeg(p, wa, wb) <= maxDistPx) return true;
        }
        // 開口線分そのものが壁線に近い場合も紐付け
        if (_segSegMinDist(
              Offset(opening.a.x, opening.a.y),
              Offset(opening.b.x, opening.b.y),
              wa,
              wb,
            ) <=
            maxDistPx) {
          return true;
        }
      }
    }
    return false;
  }

  static double _segSegMinDist(Offset a1, Offset a2, Offset b1, Offset b2) {
    return [
      _distToSeg(a1, b1, b2),
      _distToSeg(a2, b1, b2),
      _distToSeg(b1, a1, a2),
      _distToSeg(b2, a1, a2),
    ].reduce((a, b) => a < b ? a : b);
  }

  static double _distToSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-6) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }
}

/// 6種グラフィック（赤Hベース）
class OpeningPatternIcon extends StatelessWidget {
  const OpeningPatternIcon({
    super.key,
    required this.pattern,
    this.size = 72,
    this.selected = false,
  });

  final OpeningReinforcePattern pattern;
  final double size;
  final bool selected;

  static const red = Color(0xFFE53935);
  static const orange = Color(0xFFFF9800);
  static const green = Color(0xFF43A047);
  static const black = Color(0xFF212121);
  static const blue = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF1A237E) : Colors.black26,
          width: selected ? 2.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: CustomPaint(painter: _PatternPainter(pattern)),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern);
  final OpeningReinforcePattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(2.5, size.shortestSide * 0.08);
    final inset = stroke;
    final left = inset;
    final right = size.width - inset;
    final top = inset;
    final bottom = size.height - inset;
    final midX = size.width / 2;
    // Hの横桟（やや上寄り）
    final hBarY = size.height * 0.38;
    final below1 = size.height * 0.55;
    final below2 = size.height * 0.72;
    final orangeY = size.height * 0.22;

    void line(Offset a, Offset b, Color c) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = c
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.square,
      );
    }

    void redH({bool drawCrossbar = true}) {
      line(Offset(left, top), Offset(left, bottom), OpeningPatternIcon.red);
      line(Offset(right, top), Offset(right, bottom), OpeningPatternIcon.red);
      if (drawCrossbar) {
        line(Offset(left, hBarY), Offset(right, hBarY), OpeningPatternIcon.red);
      }
    }

    switch (pattern) {
      case OpeningReinforcePattern.redH:
        redH();
        break;

      case OpeningReinforcePattern.redHOrange:
        // 現行⑤相当：両縦＋上寄り横2本（橙＋赤H桟）
        redH();
        line(
          Offset(left, orangeY),
          Offset(right, orangeY),
          OpeningPatternIcon.orange,
        );
        break;

      case OpeningReinforcePattern.redHGreenBlack:
        // ⑤＋中央縦：緑横・黒横＋中央縦
        redH(drawCrossbar: false);
        line(
          Offset(left, orangeY),
          Offset(right, orangeY),
          OpeningPatternIcon.green,
        );
        line(
          Offset(left, hBarY),
          Offset(right, hBarY),
          OpeningPatternIcon.black,
        );
        line(
          Offset(midX, orangeY),
          Offset(midX, bottom),
          OpeningPatternIcon.black,
        );
        break;

      case OpeningReinforcePattern.redHGreenBlue:
        // 赤H下方内に横2本（緑・青）
        redH();
        line(
          Offset(left, below1),
          Offset(right, below1),
          OpeningPatternIcon.green,
        );
        line(
          Offset(left, below2),
          Offset(right, below2),
          OpeningPatternIcon.blue,
        );
        break;

      case OpeningReinforcePattern.redHBlack:
        // 赤H下方内に縦1本（黒）
        redH();
        line(
          Offset(midX, hBarY),
          Offset(midX, bottom),
          OpeningPatternIcon.black,
        );
        break;

      case OpeningReinforcePattern.square:
        line(Offset(left, top), Offset(left, bottom), OpeningPatternIcon.red);
        line(Offset(right, top), Offset(right, bottom), OpeningPatternIcon.red);
        line(Offset(left, top), Offset(right, top), OpeningPatternIcon.red);
        line(
          Offset(left, bottom),
          Offset(right, bottom),
          OpeningPatternIcon.red,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern;
}
