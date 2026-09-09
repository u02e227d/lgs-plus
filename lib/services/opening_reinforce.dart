import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// 開口補強の7種（xlsx色分けに対応）
enum OpeningReinforcePattern {
  /// ① 赤のみ
  redOnly,
  /// ② 赤＋橙
  redOrange,
  /// ③ 赤＋緑
  redGreen,
  /// ④ 赤＋緑＋黒
  redGreenBlack,
  /// ⑤ 赤＋緑＋青
  redGreenBlue,
  /// ⑥ 赤＋黒
  redBlack,
  /// ⑦ 四方形
  square,
}

extension OpeningReinforcePatternX on OpeningReinforcePattern {
  String get label {
    switch (this) {
      case OpeningReinforcePattern.redOnly:
        return '① 赤のみ';
      case OpeningReinforcePattern.redOrange:
        return '② 赤＋橙';
      case OpeningReinforcePattern.redGreen:
        return '③ 赤＋緑';
      case OpeningReinforcePattern.redGreenBlack:
        return '④ 赤＋緑＋黒';
      case OpeningReinforcePattern.redGreenBlue:
        return '⑤ 赤＋緑＋青';
      case OpeningReinforcePattern.redBlack:
        return '⑥ 赤＋黒';
      case OpeningReinforcePattern.square:
        return '⑦ 四方形';
    }
  }

  /// 縦の色線本数（1本＝補強材1本）
  int get verticalLines {
    switch (this) {
      case OpeningReinforcePattern.redOnly:
      case OpeningReinforcePattern.redOrange:
      case OpeningReinforcePattern.redGreen:
      case OpeningReinforcePattern.redGreenBlack:
      case OpeningReinforcePattern.redGreenBlue:
      case OpeningReinforcePattern.redBlack:
      case OpeningReinforcePattern.square:
        return 2;
    }
  }

  /// まぐさ（上横）の基数。段数を掛ける
  int get magusaBase {
    switch (this) {
      case OpeningReinforcePattern.redOnly:
        return 0;
      case OpeningReinforcePattern.redOrange:
      case OpeningReinforcePattern.redGreen:
      case OpeningReinforcePattern.redGreenBlack:
      case OpeningReinforcePattern.redGreenBlue:
      case OpeningReinforcePattern.redBlack:
      case OpeningReinforcePattern.square:
        return 1;
    }
  }

  /// まぐさ以外の横線（下枠・中段など）
  int get otherHorizontalLines {
    switch (this) {
      case OpeningReinforcePattern.redOnly:
      case OpeningReinforcePattern.redOrange:
      case OpeningReinforcePattern.redGreen:
      case OpeningReinforcePattern.redBlack:
        return 0;
      case OpeningReinforcePattern.redGreenBlack:
      case OpeningReinforcePattern.redGreenBlue:
      case OpeningReinforcePattern.square:
        return 1;
    }
  }

  int horizontalLines(int magusaSegments) {
    final seg = magusaSegments.clamp(1, 4);
    if (magusaBase <= 0) return otherHorizontalLines;
    return magusaBase * seg + otherHorizontalLines;
  }
}

/// 定尺から開口幅ぶんを何本切れるか → 必要本数
int cutStockBars({
  required int memberCount,
  required double pieceMm,
  required double stockMm,
}) {
  if (memberCount <= 0 || pieceMm <= 0 || stockMm <= 0) return 0;
  final per = (stockMm / pieceMm).floor();
  if (per >= 1) {
    return ((memberCount + per - 1) / per).ceil();
  }
  final perMember = (pieceMm / stockMm).ceil();
  return memberCount * perMember;
}

class OpeningReinforceCalc {
  OpeningReinforceCalc._();

  /// 補強材本数＝縦線本数＋横線の定尺割付
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

  /// 開口中点が壁折れ線に近いか
  static bool openingNearWall({
    required WallOpening opening,
    required WallSegment wall,
    double maxDistPx = 48,
  }) {
    final mid = Offset(
      (opening.a.x + opening.b.x) / 2,
      (opening.a.y + opening.b.y) / 2,
    );
    for (final chain in wall.chains) {
      for (var i = 0; i < chain.length - 1; i++) {
        final d = _distToSeg(
          mid,
          Offset(chain[i].x, chain[i].y),
          Offset(chain[i + 1].x, chain[i + 1].y),
        );
        if (d <= maxDistPx) return true;
      }
    }
    return false;
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

/// 7種グラフィック（色線）
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
    final midY = size.height * 0.55;

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

    // 赤縦（両側）— ①〜⑦共通
    line(Offset(left, top), Offset(left, bottom), OpeningPatternIcon.red);
    line(Offset(right, top), Offset(right, bottom), OpeningPatternIcon.red);

    switch (pattern) {
      case OpeningReinforcePattern.redOnly:
        break;
      case OpeningReinforcePattern.redOrange:
        line(Offset(left, top), Offset(right, top), OpeningPatternIcon.orange);
        break;
      case OpeningReinforcePattern.redGreen:
        line(Offset(left, top), Offset(right, top), OpeningPatternIcon.green);
        break;
      case OpeningReinforcePattern.redGreenBlack:
        line(Offset(left, top), Offset(right, top), OpeningPatternIcon.green);
        line(
          Offset(left, bottom),
          Offset(right, bottom),
          OpeningPatternIcon.black,
        );
        break;
      case OpeningReinforcePattern.redGreenBlue:
        line(Offset(left, top), Offset(right, top), OpeningPatternIcon.green);
        line(Offset(left, midY), Offset(right, midY), OpeningPatternIcon.blue);
        break;
      case OpeningReinforcePattern.redBlack:
        line(Offset(left, top), Offset(right, top), OpeningPatternIcon.black);
        break;
      case OpeningReinforcePattern.square:
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
