import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/calc_engine.dart';
import '../services/edge_snap_engine.dart';
import '../theme/app_theme.dart';

/// 壁横断の大頭棒ヒット領域（互換）
class WallRodHit {
  WallRodHit({
    required this.wallId,
    required this.sideA,
    required this.center,
    required this.sideB,
  });
  final String wallId;
  final Offset sideA;
  final Offset center;
  final Offset sideB;

  /// null = 外れ / 'a'|'center'|'b'
  String? hit(Offset p, {double radius = 18}) {
    if ((p - sideA).distance <= radius) return 'a';
    if ((p - sideB).distance <= radius) return 'b';
    if ((p - center).distance <= radius) return 'center';
    return null;
  }
}

/// 壁線色パレット（蛍光）と番号バッジ用の実色
class WallHighlightColors {
  WallHighlightColors._();

  static const List<Color> palette = [
    Color(0xFFFFEB3B), // 蛍光黄
    Color(0xFF76FF03), // 蛍光緑
    Color(0xFF00E5FF), // 蛍光シアン
    Color(0xFFFF4081), // 蛍光ピンク
    Color(0xFFFF9100), // 蛍光オレンジ
    Color(0xFFE040FB), // 蛍光紫
    Color(0xFF2979FF), // 青
  ];

  /// 番号アイコン用の実色（蛍光ではない）
  static const List<Color> solidPalette = [
    Color(0xFFF9A825),
    Color(0xFF43A047),
    Color(0xFF00838F),
    Color(0xFFC2185B),
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
    Color(0xFF1565C0),
  ];

  static Color ofArgb(int? argb) {
    if (argb == null) return palette.first;
    return Color(argb);
  }

  static Color solidOfArgb(int? argb) {
    if (argb == null) return solidPalette.first;
    for (var i = 0; i < palette.length; i++) {
      if (palette[i].toARGB32() == argb) return solidPalette[i];
    }
    return Color((argb & 0x00FFFFFF) | 0xFF000000);
  }

  static const int defaultArgb = 0xFFFFEB3B;
}

/// 線末の番号バッジヒット
class WallBadgeHit {
  WallBadgeHit({
    required this.wallId,
    required this.center,
    required this.number,
  });
  final String wallId;
  final Offset center;
  final int number;

  bool hit(Offset p, {double radius = 22}) => (p - center).distance <= radius;
}

/// 中層：吸着線・天井塗り・壁ドラフト（距離表示）
class OverlayMidPainter extends CustomPainter {
  OverlayMidPainter({
    required this.snapLines,
    required this.ceilings,
    required this.ceilingDraft,
    required this.wallDraft,
    required this.scalePxPerMm,
  });

  final List<LineSeg> snapLines;
  final List<CeilingRegion> ceilings;
  final List<Offset> ceilingDraft;
  final List<Offset> wallDraft;
  final double scalePxPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    final snapPaint = Paint()
      ..color = const Color(0x8834A853)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final l in snapLines) {
      canvas.drawLine(Offset(l.a.x, l.a.y), Offset(l.b.x, l.b.y), snapPaint);
    }

    final fill = Paint()
      ..color = const Color(0x4D1F8A70)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final c in ceilings) {
      if (c.points.length < 3) continue;
      final path = Path()..moveTo(c.points.first.x, c.points.first.y);
      for (var i = 1; i < c.points.length; i++) {
        path.lineTo(c.points[i].x, c.points[i].y);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    if (ceilingDraft.isNotEmpty) {
      final draftStroke = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(ceilingDraft.first.dx, ceilingDraft.first.dy);
      for (var i = 1; i < ceilingDraft.length; i++) {
        path.lineTo(ceilingDraft[i].dx, ceilingDraft[i].dy);
      }
      canvas.drawPath(path, draftStroke);
      for (final p in ceilingDraft) {
        canvas.drawCircle(p, 5, Paint()..color = Colors.orange);
      }
    }

    if (wallDraft.length >= 2) {
      final p = Paint()
        ..color = AppTheme.navy
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(wallDraft.first.dx, wallDraft.first.dy);
      for (var i = 1; i < wallDraft.length; i++) {
        path.lineTo(wallDraft[i].dx, wallDraft[i].dy);
      }
      canvas.drawPath(path, p);
      for (var i = 0; i < wallDraft.length; i++) {
        final isCorner = i > 0 && i < wallDraft.length - 1;
        canvas.drawCircle(
          wallDraft[i],
          isCorner ? 7 : 5,
          Paint()
            ..color = isCorner ? const Color(0xFFE53935) : AppTheme.navy,
        );
        if (isCorner) {
          for (var k = -1; k <= 1; k++) {
            canvas.drawCircle(
              wallDraft[i] + Offset(k * 5.0, -10),
              2.2,
              Paint()..color = AppTheme.safetyYellow,
            );
          }
        }
      }
      // 区間距離ラベル
      for (var i = 0; i < wallDraft.length - 1; i++) {
        _drawDistanceLabel(
          canvas,
          wallDraft[i],
          wallDraft[i + 1],
          scalePxPerMm,
        );
      }
    } else if (wallDraft.length == 1) {
      canvas.drawCircle(wallDraft.first, 5, Paint()..color = AppTheme.navy);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayMidPainter oldDelegate) => true;
}

/// 上層：確定壁・距離・番号バッジ・天井グリッド
class OverlayTopPainter extends CustomPainter {
  OverlayTopPainter({
    required this.walls,
    required this.ceilings,
    required this.scalePxPerMm,
    this.openings = const [],
    this.openingDraft = const [],
    this.openingDraftArgb,
    this.openingDraftMarkerSize = 16,
    this.selectedWallId,
    this.badgeHits,
  });

  final List<WallSegment> walls;
  final List<CeilingRegion> ceilings;
  final double scalePxPerMm;
  final List<WallOpening> openings;
  final List<Offset> openingDraft;
  final int? openingDraftArgb;
  final double openingDraftMarkerSize;
  final String? selectedWallId;
  final List<WallBadgeHit>? badgeHits;

  @override
  void paint(Canvas canvas, Size size) {
    badgeHits?.clear();
    final dot = Paint()..color = AppTheme.safetyYellow;
    final cornerDot = Paint()..color = const Color(0xFFE53935);

    void drawOpeningMarker(Offset c, double sz, Color color) {
      final half = (sz.clamp(8.0, 64.0)) / 2;
      final rect = Rect.fromCenter(center: c, width: half * 2, height: half * 2);
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: 0.85),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    for (final o in openings) {
      final color = WallHighlightColors.ofArgb(o.highlightArgb);
      drawOpeningMarker(Offset(o.a.x, o.a.y), o.markerSize, color);
      drawOpeningMarker(Offset(o.b.x, o.b.y), o.markerSize, color);
      canvas.drawLine(
        Offset(o.a.x, o.a.y),
        Offset(o.b.x, o.b.y),
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    if (openingDraft.isNotEmpty) {
      final color = WallHighlightColors.ofArgb(openingDraftArgb);
      for (final p in openingDraft) {
        drawOpeningMarker(p, openingDraftMarkerSize, color);
      }
      if (openingDraft.length >= 2) {
        canvas.drawLine(
          openingDraft[0],
          openingDraft[1],
          Paint()
            ..color = color.withValues(alpha: 0.7)
            ..strokeWidth = 2,
        );
      }
    }

    for (var wi = 0; wi < walls.length; wi++) {
      final w = walls[wi];
      if (w.points.length < 2) continue;
      final wallColor = WallHighlightColors.ofArgb(w.highlightArgb);
      final sw = w.strokeWidth.clamp(2.0, 56.0);
      final wallPaint = Paint()
        ..color = wallColor
        ..strokeWidth = selectedWallId == w.id ? sw + 1.5 : sw
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.srcOver;

      for (final chain in w.chains) {
        if (chain.length < 2) continue;
        final path = Path()..moveTo(chain.first.x, chain.first.y);
        for (var i = 1; i < chain.length; i++) {
          path.lineTo(chain[i].x, chain[i].y);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = wallColor.withValues(alpha: 0.35)
            ..strokeWidth = sw * 1.8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(path, wallPaint);

        for (var i = 0; i < chain.length - 1; i++) {
          _drawDistanceLabel(
            canvas,
            Offset(chain[i].x, chain[i].y),
            Offset(chain[i + 1].x, chain[i + 1].y),
            scalePxPerMm,
          );
        }

        if (w.method.useLgs && scalePxPerMm > 0) {
          for (var i = 0; i < chain.length - 1; i++) {
            final a = Offset(chain[i].x, chain[i].y);
            final b = Offset(chain[i + 1].x, chain[i + 1].y);
            final lenPx = CalcEngine.distPx(chain[i], chain[i + 1]);
            final pitchPx = w.method.pitchMm * scalePxPerMm;
            if (pitchPx > 1 && lenPx > 0) {
              final n = (lenPx / pitchPx).floor();
              for (var j = 0; j <= n; j++) {
                final t = (j * pitchPx) / lenPx;
                if (t > 1) break;
                final p = Offset(
                  a.dx + (b.dx - a.dx) * t,
                  a.dy + (b.dy - a.dy) * t,
                );
                canvas.drawCircle(p, 3.5, dot);
              }
              canvas.drawCircle(b, 3.5, dot);
            }
          }
          for (var i = 1; i < chain.length - 1; i++) {
            final c = Offset(chain[i].x, chain[i].y);
            canvas.drawCircle(c, 5, cornerDot);
          }
        }
      }

      // 線尾部の実色番号バッジ（最終チェーンの末端）
      final tip = Offset(w.points.last.x, w.points.last.y);
      final num = wi + 1;
      final solid = WallHighlightColors.solidOfArgb(w.highlightArgb);
      const r = 16.0;
      canvas.drawCircle(tip, r, Paint()..color = solid);
      canvas.drawCircle(
        tip,
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$num',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, tip - Offset(tp.width / 2, tp.height / 2));
      badgeHits?.add(WallBadgeHit(wallId: w.id, center: tip, number: num));
    }

    final gridPaint = Paint()
      ..color = const Color(0xAA1565C0)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (final c in ceilings) {
      if (c.points.length < 3 || scalePxPerMm <= 0) continue;
      final path = Path()..moveTo(c.points.first.x, c.points.first.y);
      for (var i = 1; i < c.points.length; i++) {
        path.lineTo(c.points[i].x, c.points[i].y);
      }
      path.close();

      var minX = c.points.first.x, maxX = c.points.first.x;
      var minY = c.points.first.y, maxY = c.points.first.y;
      for (final p in c.points) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }

      final noenPx = c.method.noenSpacingMm * scalePxPerMm;
      final ukePx = c.method.noenuKeSpacingMm * scalePxPerMm;
      final pitchA = c.method.rotated90 ? ukePx : noenPx;
      final pitchB = c.method.rotated90 ? noenPx : ukePx;

      canvas.save();
      canvas.clipPath(path);

      if (pitchA > 2) {
        for (var y = minY; y <= maxY; y += pitchA) {
          canvas.drawLine(Offset(minX, y), Offset(maxX, y), gridPaint);
        }
      }
      if (pitchB > 2) {
        for (var x = minX; x <= maxX; x += pitchB) {
          canvas.drawLine(Offset(x, minY), Offset(x, maxY), gridPaint);
        }
      }
      canvas.restore();
    }
  }

  static WallRodHit rodForWall(WallSegment w, double scalePxPerMm) {
    // 全長の中点付近の区間を使う
    var total = 0.0;
    final seglen = <double>[];
    for (var i = 0; i < w.points.length - 1; i++) {
      final d = CalcEngine.distPx(w.points[i], w.points[i + 1]);
      seglen.add(d);
      total += d;
    }
    var mid = total / 2;
    var idx = 0;
    for (; idx < seglen.length; idx++) {
      if (mid <= seglen[idx]) break;
      mid -= seglen[idx];
    }
    idx = idx.clamp(0, seglen.length - 1);
    final a = Offset(w.points[idx].x, w.points[idx].y);
    final b = Offset(w.points[idx + 1].x, w.points[idx + 1].y);
    final t = seglen[idx] > 0 ? mid / seglen[idx] : 0.5;
    final center = Offset(
      a.dx + (b.dx - a.dx) * t,
      a.dy + (b.dy - a.dy) * t,
    );
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    // 壁に直交する単位ベクトル
    final nx = len > 0 ? -dy / len : 0.0;
    final ny = len > 0 ? dx / len : 1.0;
    // 壁に平行な単位ベクトル
    final tx = len > 0 ? dx / len : 1.0;
    final ty = len > 0 ? dy / len : 0.0;
    // 0°=壁と十字（直交） / 90°=壁に平行 / 180° / 270°
    final turns = w.triadQuarterTurns % 4;
    late final double ax;
    late final double ay;
    switch (turns) {
      case 1:
        ax = tx;
        ay = ty;
        break;
      case 2:
        ax = -nx;
        ay = -ny;
        break;
      case 3:
        ax = -tx;
        ay = -ty;
        break;
      default:
        ax = nx;
        ay = ny;
    }
    final thickMm = w.quantities['finished_thickness_mm'] ??
        (w.method.studWidthMm +
            w.method.effectiveBoardAMm +
            w.method.effectiveBoardBMm);
    final half = math.max(56.0, (thickMm * scalePxPerMm) / 2 + 48);
    return WallRodHit(
      wallId: w.id,
      sideA: center + Offset(ax * half, ay * half),
      center: center,
      sideB: center - Offset(ax * half, ay * half),
    );
  }

  static WallRodHit _rodForWall(WallSegment w, double scalePxPerMm) =>
      rodForWall(w, scalePxPerMm);

  @override
  bool shouldRepaint(covariant OverlayTopPainter oldDelegate) => true;
}

void _drawDistanceLabel(
  Canvas canvas,
  Offset a,
  Offset b,
  double scalePxPerMm,
) {
  if (scalePxPerMm <= 0) return;
  final lenPx = (b - a).distance;
  if (lenPx < 8) return;
  final mm = lenPx / scalePxPerMm;
  final label = mm >= 1000
      ? '${(mm / 1000).toStringAsFixed(2)} m'
      : '${mm.toStringAsFixed(0)} mm';
  final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 13),
  )
    ..pushStyle(ui.TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: 13,
      fontWeight: FontWeight.w700,
      background: Paint()..color = const Color(0xEEFFF59D),
    ))
    ..addText(' $label ');
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 120));
  canvas.save();
  canvas.translate(mid.dx, mid.dy);
  // 文字が逆さまにならないよう補正
  var rot = angle;
  if (rot > math.pi / 2 || rot < -math.pi / 2) rot += math.pi;
  canvas.rotate(rot);
  canvas.translate(-paragraph.maxIntrinsicWidth / 2, -22);
  canvas.drawParagraph(paragraph, Offset.zero);
  canvas.restore();
}

/// 壁線ヒット（長押し削除・選択用）
String? hitTestWall(List<WallSegment> walls, Offset p, {double thresh = 16}) {
  String? bestId;
  var best = thresh;
  for (final w in walls) {
    for (var i = 0; i < w.points.length - 1; i++) {
      final d = _distToSeg(
        p,
        Offset(w.points[i].x, w.points[i].y),
        Offset(w.points[i + 1].x, w.points[i + 1].y),
      );
      if (d < best) {
        best = d;
        bestId = w.id;
      }
    }
  }
  return bestId;
}

double _distToSeg(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 <= 0) return (p - a).distance;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - proj).distance;
}
