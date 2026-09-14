import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/calc_engine.dart';
import '../services/ceiling_layout.dart';
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

/// 下り線末の番号バッジヒット
class DropBadgeHit {
  DropBadgeHit({
    required this.dropId,
    required this.center,
    required this.number,
  });
  final String dropId;
  final Offset center;
  final int number;

  bool hit(Offset p, {double radius = 22}) => (p - center).distance <= radius;
}

/// 第2折以降の「幅＋」ボタンヒット
class DropWidthPlusHit {
  DropWidthPlusHit({
    required this.center,
    required this.origin,
    required this.turnIndex,
    this.dropId,
    this.isDraft = false,
  });
  final Offset center;
  /// 幅測定の始点（線分中心）
  final Offset origin;
  /// 折点インデックス（2＝第2幅、3＝第3幅…）
  final int turnIndex;
  final String? dropId;
  final bool isDraft;

  bool hit(Offset p, {double radius = 20}) => (p - center).distance <= radius;
}

/// 天井面積番号バッジヒット
class CeilingBadgeHit {
  CeilingBadgeHit({
    required this.ceilingId,
    required this.center,
    required this.number,
    this.radius = 28,
  });
  final String ceilingId;
  final Offset center;
  final int number;
  final double radius;

  bool hit(Offset p, {double? radius}) =>
      (p - center).distance <= (radius ?? this.radius);
}

/// 開口マーカーヒット
class OpeningMarkerHit {
  OpeningMarkerHit({
    required this.openingId,
    required this.center,
    required this.halfSize,
  });
  final String openingId;
  final Offset center;
  final double halfSize;

  bool hit(Offset p) {
    final r = math.max(14.0, halfSize + 4);
    return (p - center).dx.abs() <= r && (p - center).dy.abs() <= r;
  }
}

/// 中層：吸着線・天井塗り・壁ドラフト（距離表示）
class OverlayMidPainter extends CustomPainter {
  OverlayMidPainter({
    required this.snapLines,
    required this.ceilings,
    required this.ceilingDraft,
    required this.wallDraft,
    required this.scalePxPerMm,
    this.drops = const [],
    this.dropDraft = const [],
    this.draftFillArgb,
    this.viewScale = 1,
    this.dropBadgeHits,
    this.dropWidthPlusHits,
    this.dropDraftTurnWidths = const [],
    this.dropWidthMeasureOrigin,
    this.dropWidthMeasureTip,
    this.dropWidthMeasureTurnIndex,
    this.ironDraft = false,
  });

  final List<LineSeg> snapLines;
  final List<CeilingRegion> ceilings;
  final List<Offset> ceilingDraft;
  final List<Offset> wallDraft;
  final List<DropRegion> drops;
  final List<Offset> dropDraft;
  final double scalePxPerMm;
  final int? draftFillArgb;
  /// InteractiveViewer の拡大率（ラベルを画面上で一定サイズに近づける）
  final double viewScale;
  final List<DropBadgeHit>? dropBadgeHits;
  final List<DropWidthPlusHit>? dropWidthPlusHits;
  final List<DropTurnWidth> dropDraftTurnWidths;
  final Offset? dropWidthMeasureOrigin;
  final Offset? dropWidthMeasureTip;
  final int? dropWidthMeasureTurnIndex;
  /// 鉄板専用の画線ドラフトは点線
  final bool ironDraft;

  @override
  void paint(Canvas canvas, Size size) {
    dropBadgeHits?.clear();
    dropWidthPlusHits?.clear();
    final snapPaint = Paint()
      ..color = const Color(0x8834A853)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final l in snapLines) {
      canvas.drawLine(Offset(l.a.x, l.a.y), Offset(l.b.x, l.b.y), snapPaint);
    }

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    Offset centroidOf(List<Offset> pts) {
      var sx = 0.0, sy = 0.0;
      for (final p in pts) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / pts.length, sy / pts.length);
    }

    void drawDraftAreaLabel(Offset at, double areaM2) {
      if (areaM2 <= 0) return;
      paintCeilingNumberAreaLabel(
        canvas,
        at: at,
        number: null,
        areaM2: areaM2,
        viewScale: viewScale,
      );
    }

    for (var ci = 0; ci < ceilings.length; ci++) {
      final c = ceilings[ci];
      if (c.points.length < 3) continue;
      final pts = [
        for (final p in c.points) Offset(p.x, p.y),
      ];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      final base = WallHighlightColors.ofArgb(
        c.highlightArgb ?? WallHighlightColors.defaultArgb,
      );
      fill.color = base.withValues(alpha: 0.38);
      stroke.color = WallHighlightColors.solidOfArgb(c.highlightArgb);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    if (ceilingDraft.isNotEmpty) {
      final draftColor = WallHighlightColors.ofArgb(
        draftFillArgb ?? WallHighlightColors.defaultArgb,
      );
      final draftStroke = Paint()
        ..color = WallHighlightColors.solidOfArgb(draftFillArgb)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(ceilingDraft.first.dx, ceilingDraft.first.dy);
      for (var i = 1; i < ceilingDraft.length; i++) {
        path.lineTo(ceilingDraft[i].dx, ceilingDraft[i].dy);
      }

      final canClose = ceilingDraft.length >= 3;
      final nearStart = canClose &&
          (ceilingDraft.last - ceilingDraft.first).distance <= 40;
      if (canClose) {
        final fillPath = Path.from(path)..close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..color = draftColor.withValues(alpha: nearStart ? 0.45 : 0.28)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(fillPath, draftStroke);
        if (nearStart) {
          canvas.drawLine(
            ceilingDraft.last,
            ceilingDraft.first,
            Paint()
              ..color = const Color(0xFF2E7D32)
              ..strokeWidth = 2.5
              ..style = PaintingStyle.stroke,
          );
        }
        final pts2 = [
          for (final o in ceilingDraft) Point2(o.dx, o.dy),
        ];
        final areaM2 =
            CalcEngine.polygonAreaMm2(pts2, scalePxPerMm) / 1e6;
        drawDraftAreaLabel(centroidOf(ceilingDraft), areaM2);
      } else {
        canvas.drawPath(path, draftStroke);
      }

      for (var i = 0; i < ceilingDraft.length; i++) {
        final p = ceilingDraft[i];
        final isFirst = i == 0;
        canvas.drawCircle(
          p,
          isFirst ? 7 : 5,
          Paint()
            ..color = isFirst
                ? const Color(0xFF2E7D32)
                : WallHighlightColors.solidOfArgb(draftFillArgb),
        );
      }
      if (ceilingDraft.length >= 2) {
        canvas.drawCircle(
          ceilingDraft.first,
          14,
          Paint()
            ..color = const Color(0x662E7D32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // 鉄板ドラフトは上層で壁の上に描く
    if (!ironDraft && wallDraft.length >= 2) {
      final p = Paint()
        ..color = AppTheme.navy
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = ironDraft ? StrokeCap.butt : StrokeCap.round;
      final path = Path()..moveTo(wallDraft.first.dx, wallDraft.first.dy);
      for (var i = 1; i < wallDraft.length; i++) {
        path.lineTo(wallDraft[i].dx, wallDraft[i].dy);
      }
      if (ironDraft) {
        _drawDashedPath(canvas, path, p, dash: 10, gap: 7);
      } else {
        canvas.drawPath(path, p);
      }
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
    } else if (!ironDraft && wallDraft.length == 1) {
      canvas.drawCircle(wallDraft.first, 5, Paint()..color = AppTheme.navy);
    }

    // 確定済み下り（破線＋線尾番号）
    for (final d in drops) {
      if (d.points.length < 2) continue;
      final c = WallHighlightColors.solidOfArgb(d.highlightArgb);
      final path = Path()..moveTo(d.points.first.x, d.points.first.y);
      for (var i = 1; i < d.points.length; i++) {
        path.lineTo(d.points[i].x, d.points[i].y);
      }
      final stroke = Paint()
        ..color = c
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      _drawDashedPath(canvas, path, stroke, dash: 10, gap: 8);
      for (var i = 0; i < d.points.length - 1; i++) {
        _drawDistanceLabel(
          canvas,
          Offset(d.points[i].x, d.points[i].y),
          Offset(d.points[i + 1].x, d.points[i + 1].y),
          scalePxPerMm,
          role: i == 0 ? dropWidthCircleLabel(1) : '長さ',
          fontSize: i == 0 ? 15 : 14,
          // ＋がある区間（i≥2）は数値をさらに外側へ
          offsetAlongNormal: i >= 2 ? -40 : -22,
        );
      }
      // 第2折・第3折・第4折…の長さ線上に幅＋（数値から離す）
      for (var i = 2; i < d.points.length - 1; i++) {
        final a = Offset(d.points[i].x, d.points[i].y);
        final b = Offset(d.points[i + 1].x, d.points[i + 1].y);
        final plusAt = _dropWidthPlusAnchor(a, b);
        _drawDropWidthPlus(
          canvas,
          plusAt,
          color: c,
          turnIndex: i,
          hits: dropWidthPlusHits,
          dropId: d.id,
        );
      }
      for (final tw in d.turnWidths) {
        if (tw.from == null || tw.to == null || tw.widthMm <= 0) continue;
        final a = Offset(tw.from!.x, tw.from!.y);
        final b = Offset(tw.to!.x, tw.to!.y);
        _drawDashedPath(
          canvas,
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy),
          Paint()
            ..color = c
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke,
          dash: 6,
          gap: 5,
        );
        _drawDistanceLabel(
          canvas,
          a,
          b,
          scalePxPerMm,
          role: dropWidthCircleLabel(dropWidthDisplayNumber(tw.turnIndex)),
          fontSize: 15,
        );
      }
      final tip = Offset(d.points.last.x, d.points.last.y);
      const r = 16.0;
      canvas.drawCircle(tip, r, Paint()..color = c);
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
          text: '${d.groupNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, tip - Offset(tp.width / 2, tp.height / 2));
      dropBadgeHits?.add(
        DropBadgeHit(dropId: d.id, center: tip, number: d.groupNumber),
      );
    }

    // 下りドラフト（破線・第1区間＝幅、以降＝長さ）
    if (dropDraft.isNotEmpty) {
      final c = WallHighlightColors.solidOfArgb(draftFillArgb);
      final path = Path()..moveTo(dropDraft.first.dx, dropDraft.first.dy);
      for (var i = 1; i < dropDraft.length; i++) {
        path.lineTo(dropDraft[i].dx, dropDraft[i].dy);
      }
      final stroke = Paint()
        ..color = c
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      _drawDashedPath(canvas, path, stroke, dash: 10, gap: 8);
      for (final p in dropDraft) {
        canvas.drawCircle(p, 6, Paint()..color = c);
      }
      for (var i = 0; i < dropDraft.length - 1; i++) {
        _drawDistanceLabel(
          canvas,
          dropDraft[i],
          dropDraft[i + 1],
          scalePxPerMm,
          role: i == 0 ? dropWidthCircleLabel(1) : '長さ',
          fontSize: i == 0 ? 15 : 14,
          offsetAlongNormal: i >= 2 ? -40 : -22,
        );
      }
      for (var i = 2; i < dropDraft.length - 1; i++) {
        final a = dropDraft[i];
        final b = dropDraft[i + 1];
        final plusAt = _dropWidthPlusAnchor(a, b);
        _drawDropWidthPlus(
          canvas,
          plusAt,
          color: c,
          turnIndex: i,
          hits: dropWidthPlusHits,
          isDraft: true,
        );
      }
      for (final tw in dropDraftTurnWidths) {
        if (tw.from == null || tw.to == null || tw.widthMm <= 0) continue;
        final a = Offset(tw.from!.x, tw.from!.y);
        final b = Offset(tw.to!.x, tw.to!.y);
        _drawDashedPath(
          canvas,
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy),
          Paint()
            ..color = c
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke,
          dash: 6,
          gap: 5,
        );
        _drawDistanceLabel(
          canvas,
          a,
          b,
          scalePxPerMm,
          role: dropWidthCircleLabel(dropWidthDisplayNumber(tw.turnIndex)),
          fontSize: 15,
        );
      }
    }

    // 幅＋ドラッグ中のプレビュー
    final wOrigin = dropWidthMeasureOrigin;
    final wTip = dropWidthMeasureTip;
    if (wOrigin != null && wTip != null) {
      final c = WallHighlightColors.solidOfArgb(draftFillArgb);
      final label = dropWidthMeasureTurnIndex != null
          ? dropWidthCircleLabel(
              dropWidthDisplayNumber(dropWidthMeasureTurnIndex!),
            )
          : dropWidthCircleLabel(2);
      _drawDashedPath(
        canvas,
        Path()
          ..moveTo(wOrigin.dx, wOrigin.dy)
          ..lineTo(wTip.dx, wTip.dy),
        Paint()
          ..color = c
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
        dash: 6,
        gap: 5,
      );
      _drawDistanceLabel(
        canvas,
        wOrigin,
        wTip,
        scalePxPerMm,
        role: label,
        fontSize: 15,
      );
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
    this.ceilingBadgeHits,
    this.openingHits,
    this.viewScale = 1,
    this.paintCeilingLabels = true,
    this.ironDraft = false,
    this.wallDraft = const [],
    this.showLgsPreview = true,
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
  final List<CeilingBadgeHit>? ceilingBadgeHits;
  final List<OpeningMarkerHit>? openingHits;
  final double viewScale;
  final bool paintCeilingLabels;
  final bool ironDraft;
  final List<Offset> wallDraft;
  /// 無料版は天井LGS効果図・壁スタッド点を出さない
  final bool showLgsPreview;

  @override
  void paint(Canvas canvas, Size size) {
    badgeHits?.clear();
    ceilingBadgeHits?.clear();
    openingHits?.clear();
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

    // 通常壁を先に、鉄板Tを後に描き、Tが壁線の上に乗る
    var wallNo = 0;
    void paintWall(WallSegment w) {
      if (w.points.length < 2) return;
      final wallColor = WallHighlightColors.ofArgb(w.highlightArgb);
      final sw = w.strokeWidth.clamp(2.0, 56.0);
      final iron = w.isIronPlate;
      final dashed = iron ||
          (w.method.crossDedicated.enabled &&
              w.method.crossDedicated.bothSides);
      final wallPaint = Paint()
        ..color = wallColor
        ..strokeWidth = selectedWallId == w.id ? sw + 1.5 : sw
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round
        ..blendMode = BlendMode.srcOver;

      for (final chain in w.chains) {
        if (chain.length < 2) continue;
        final path = Path()..moveTo(chain.first.x, chain.first.y);
        for (var i = 1; i < chain.length; i++) {
          path.lineTo(chain[i].x, chain[i].y);
        }
        final glow = Paint()
          ..color = wallColor.withValues(alpha: 0.35)
          ..strokeWidth = sw * 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        if (dashed) {
          _drawDashedPath(canvas, path, glow, dash: 10, gap: 8);
          _drawDashedPath(canvas, path, wallPaint, dash: 10, gap: 8);
        } else {
          canvas.drawPath(path, glow);
          canvas.drawPath(path, wallPaint);
        }

        for (var i = 0; i < chain.length - 1; i++) {
          _drawDistanceLabel(
            canvas,
            Offset(chain[i].x, chain[i].y),
            Offset(chain[i + 1].x, chain[i + 1].y),
            scalePxPerMm,
          );
        }

        if (showLgsPreview && w.method.useLgs && scalePxPerMm > 0) {
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

      final tip = Offset(w.points.last.x, w.points.last.y);
      if (!iron) wallNo++;
      final num = wallNo;
      final label = iron ? 'T' : '$num';
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
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: iron ? 16 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, tip - Offset(tp.width / 2, tp.height / 2));
      badgeHits?.add(WallBadgeHit(wallId: w.id, center: tip, number: num));
      if (iron && scalePxPerMm > 0) {
        final totalMm = ironPlateLengthMm(w, scalePxPerMm);
        if (totalMm > 0) {
          _drawPlainLabel(
            canvas,
            tip + const Offset(20, -26),
            'T ${distanceLabelText(totalMm)}',
          );
        }
      }
    }

    for (final w in walls) {
      if (!w.isIronPlate) paintWall(w);
    }

    final ukePaint = Paint()
      ..color = const Color(0xFFE65100)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final boltPaint = Paint()
      ..color = const Color(0xFFC62828)
      ..style = PaintingStyle.fill;
    final squareStudPaint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final c in ceilings) {
      if (c.points.length < 3 || scalePxPerMm <= 0) continue;
      if (!showLgsPreview || !c.method.showLayout) continue;
      final path = Path()..moveTo(c.points.first.x, c.points.first.y);
      for (var i = 1; i < c.points.length; i++) {
        path.lineTo(c.points[i].x, c.points[i].y);
      }
      path.close();

      final layout = CeilingLayoutEngine.layout(
        points: c.points,
        scalePxPerMm: scalePxPerMm,
        method: c.method,
      );
      final isSq = c.method.systemKind == CeilingSystemKind.sq;
      // 在来：W＝特粗、シングル＝粗／SQ：野縁は通常、角スタッドは黒特粗
      final wPaint = Paint()
        ..color = isSq ? const Color(0xFF1565C0) : const Color(0xFF0D47A1)
        ..strokeWidth = isSq ? 2.6 : 5.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final sPaint = Paint()
        ..color = isSq ? const Color(0xFF42A5F5) : const Color(0xFF1976D2)
        ..strokeWidth = isSq ? 1.8 : 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.save();
      canvas.clipPath(path);

      for (final b in layout.ukeBars) {
        canvas.drawLine(b.a, b.b, ukePaint);
      }
      for (final b in layout.noenBars) {
        canvas.drawLine(b.a, b.b, b.isW ? wPaint : sPaint);
      }
      for (final b in layout.squareStudBars) {
        canvas.drawLine(b.a, b.b, squareStudPaint);
      }
      for (final bolt in layout.bolts) {
        canvas.drawCircle(bolt.center, 3.5, boltPaint);
        canvas.drawCircle(
          bolt.center,
          3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      canvas.restore();
    }

    // 開口マーカーは壁線の上に描画
    for (final o in openings) {
      final color = WallHighlightColors.ofArgb(o.highlightArgb);
      final half = (o.markerSize.clamp(8.0, 64.0)) / 2;
      final pa = Offset(o.a.x, o.a.y);
      final pb = Offset(o.b.x, o.b.y);
      drawOpeningMarker(pa, o.markerSize, color);
      drawOpeningMarker(pb, o.markerSize, color);
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      openingHits?.add(
        OpeningMarkerHit(openingId: o.id, center: pa, halfSize: half),
      );
      openingHits?.add(
        OpeningMarkerHit(openingId: o.id, center: pb, halfSize: half),
      );
    }

    if (openingDraft.length == 1) {
      drawOpeningMarker(
        openingDraft.first,
        openingDraftMarkerSize,
        WallHighlightColors.ofArgb(openingDraftArgb),
      );
    } else if (openingDraft.length >= 2) {
      final color = WallHighlightColors.ofArgb(openingDraftArgb);
      drawOpeningMarker(openingDraft[0], openingDraftMarkerSize, color);
      drawOpeningMarker(openingDraft[1], openingDraftMarkerSize, color);
      canvas.drawLine(
        openingDraft[0],
        openingDraft[1],
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 2.5,
      );
    }

    // 天井番号＋面積（Widget側で描画する場合はスキップ）
    if (paintCeilingLabels) {
      for (var ci = 0; ci < ceilings.length; ci++) {
        final c = ceilings[ci];
        if (c.points.length < 3) continue;
        var sx = 0.0, sy = 0.0;
        for (final p in c.points) {
          sx += p.x;
          sy += p.y;
        }
        final at = Offset(sx / c.points.length, sy / c.points.length);
        final areaM2 = (c.quantities['ceiling_area_m2'] ??
            CalcEngine.polygonAreaMm2(c.points, scalePxPerMm) / 1e6);
        if (areaM2 <= 0) continue;
        final n = c.groupNumber <= 0 ? (ci + 1) : c.groupNumber;
        paintCeilingNumberAreaLabel(
          canvas,
          at: at,
          number: n,
          areaM2: areaM2,
          viewScale: viewScale,
          hits: ceilingBadgeHits,
          ceilingId: c.id,
        );
      }
    }

    for (final w in walls) {
      if (w.isIronPlate) paintWall(w);
    }

    if (ironDraft && wallDraft.isNotEmpty) {
      final draftPaint = Paint()
        ..color = AppTheme.navy
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.butt;
      if (wallDraft.length >= 2) {
        final path = Path()..moveTo(wallDraft.first.dx, wallDraft.first.dy);
        for (var i = 1; i < wallDraft.length; i++) {
          path.lineTo(wallDraft[i].dx, wallDraft[i].dy);
        }
        _drawDashedPath(canvas, path, draftPaint, dash: 10, gap: 7);
        for (var i = 0; i < wallDraft.length - 1; i++) {
          _drawDistanceLabel(
            canvas,
            wallDraft[i],
            wallDraft[i + 1],
            scalePxPerMm,
          );
        }
      }
      for (var i = 0; i < wallDraft.length; i++) {
        final isCorner = i > 0 && i < wallDraft.length - 1;
        canvas.drawCircle(
          wallDraft[i],
          isCorner ? 7 : 5,
          Paint()
            ..color = isCorner ? const Color(0xFFE53935) : AppTheme.navy,
        );
      }
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

/// 天井：番号バッジ＋面積を一体で描画（番号なし＝面積のみ）。
/// [viewScale] で画面上の見かけサイズをほぼ一定にする。
void paintCeilingNumberAreaLabel(
  Canvas canvas, {
  required Offset at,
  required double areaM2,
  int? number,
  double viewScale = 1,
  List<CeilingBadgeHit>? hits,
  String? ceilingId,
}) {
  if (areaM2 <= 0) return;
  final inv = 1.0 / viewScale.clamp(0.35, 5.0);
  final areaText = areaM2 >= 10
      ? '${areaM2.toStringAsFixed(1)} ㎡'
      : '${areaM2.toStringAsFixed(2)} ㎡';

  final numSize = 16.0 * inv;
  final areaSize = 17.0 * inv;
  final badgeR = 14.0 * inv;
  final gap = 6.0 * inv;
  final padH = 8.0 * inv;
  final padV = 5.0 * inv;
  final radius = 8.0 * inv;
  final strokeW = 1.6 * inv;

  final areaTp = TextPainter(
    text: TextSpan(
      text: areaText,
      style: TextStyle(
        color: Colors.white,
        fontSize: areaSize,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  TextPainter? numTp;
  if (number != null) {
    numTp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: numSize,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  final hasNum = numTp != null;
  final boxW = hasNum
      ? badgeR * 2 + gap + areaTp.width + padH * 2
      : areaTp.width + padH * 2;
  final boxH = hasNum
      ? math.max(badgeR * 2 + 10 * inv, areaTp.height + padV * 2)
      : areaTp.height + padV * 2;
  final box = RRect.fromRectAndRadius(
    Rect.fromCenter(center: at, width: boxW, height: boxH),
    Radius.circular(radius),
  );

  canvas.drawRRect(
    box.shift(Offset(2 * inv, 3 * inv)),
    Paint()..color = const Color(0x88000000),
  );
  canvas.drawRRect(
    box,
    Paint()..color = hasNum ? const Color(0xFF0D47A1) : const Color(0xFFEF6C00),
  );
  canvas.drawRRect(
    box,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW,
  );

  if (hasNum) {
    final n = number!;
    final badgeCenter = Offset(
      at.dx - boxW / 2 + padH + badgeR,
      at.dy,
    );
    canvas.drawCircle(
      badgeCenter,
      badgeR,
      Paint()..color = const Color(0xFFE53935),
    );
    canvas.drawCircle(
      badgeCenter,
      badgeR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );
    numTp.paint(
      canvas,
      Offset(
        badgeCenter.dx - numTp.width / 2,
        badgeCenter.dy - numTp.height / 2,
      ),
    );
    areaTp.paint(
      canvas,
      Offset(
        badgeCenter.dx + badgeR + gap,
        at.dy - areaTp.height / 2,
      ),
    );
    if (hits != null && ceilingId != null) {
      hits.add(
        CeilingBadgeHit(
          ceilingId: ceilingId,
          center: badgeCenter,
          number: n,
        ),
      );
    }
  } else {
    areaTp.paint(
      canvas,
      Offset(at.dx - areaTp.width / 2, at.dy - areaTp.height / 2),
    );
  }
}

/// 線上の黄色い長さラベルと同じ mm。短すぎてラベルを出さない区間は 0。
double distanceLabelMm(Offset a, Offset b, double scalePxPerMm) {
  if (scalePxPerMm <= 0) return 0;
  final lenPx = (b - a).distance;
  if (lenPx < 8) return 0;
  return lenPx / scalePxPerMm;
}

/// 鉄板線の全長（折点前後の全区間。線ラベル／T／材料選択で同じ式）
double ironPlateLengthMm(WallSegment wall, double scalePxPerMm) {
  if (scalePxPerMm <= 0) return 0;
  var run = 0.0;
  final chains = wall.chains.isNotEmpty ? wall.chains : [wall.points];
  for (final chain in chains) {
    for (var i = 0; i < chain.length - 1; i++) {
      run += CalcEngine.pxToMm(
        CalcEngine.distPx(chain[i], chain[i + 1]),
        scalePxPerMm,
      );
    }
  }
  return run;
}

/// 画線ラベルと同じ表示（3.53 m / 820 mm）
String distanceLabelText(double mm) {
  if (mm <= 0) return '';
  if (mm >= 1000) return '${(mm / 1000).toStringAsFixed(2)} m';
  return '${mm.toStringAsFixed(0)} mm';
}

void _drawPlainLabel(Canvas canvas, Offset at, String text) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: 13),
  )
    ..pushStyle(ui.TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: 13,
      fontWeight: FontWeight.w700,
      background: Paint()..color = const Color(0xEEFFF59D),
    ))
    ..addText(' $text ');
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 200));
  canvas.drawParagraph(paragraph, at);
}

void _drawDistanceLabel(
  Canvas canvas,
  Offset a,
  Offset b,
  double scalePxPerMm, {
  String? role,
  double fontSize = 13,
  double offsetAlongNormal = -22,
}) {
  final mm = distanceLabelMm(a, b, scalePxPerMm);
  if (mm <= 0) return;
  final dist = distanceLabelText(mm);
  final label = role == null ? ' $dist ' : ' $dist $role ';
  final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
  )
    ..pushStyle(ui.TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      background: Paint()..color = const Color(0xEEFFF59D),
    ))
    ..addText(label);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 160));
  canvas.save();
  canvas.translate(mid.dx, mid.dy);
  // 文字が逆さまにならないよう補正
  var rot = angle;
  if (rot > math.pi / 2 || rot < -math.pi / 2) rot += math.pi;
  canvas.rotate(rot);
  canvas.translate(-paragraph.maxIntrinsicWidth / 2, offsetAlongNormal);
  canvas.drawParagraph(paragraph, Offset.zero);
  canvas.restore();
}

/// 長さラベルは線の上方。＋は線分の幾何中心（線上）
Offset _dropWidthPlusAnchor(Offset a, Offset b) {
  return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

/// 第2折以降の長さ線付近に「＋」（幅測定開始）
void _drawDropWidthPlus(
  Canvas canvas,
  Offset at, {
  required Color color,
  required int turnIndex,
  List<DropWidthPlusHit>? hits,
  String? dropId,
  bool isDraft = false,
}) {
  const r = 14.0;
  canvas.drawCircle(at, r, Paint()..color = color);
  canvas.drawCircle(
    at,
    r,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final tp = TextPainter(
    text: const TextSpan(
      text: '+',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2 - 1));
  hits?.add(
    DropWidthPlusHit(
      center: at,
      origin: at,
      turnIndex: turnIndex,
      dropId: dropId,
      isDraft: isDraft,
    ),
  );
}

/// 破線パス（両面クロス壁の表示用）
void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 12,
  double gap = 8,
}) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    var draw = true;
    while (d < metric.length) {
      final len = draw ? dash : gap;
      final next = math.min(d + len, metric.length);
      if (draw) {
        canvas.drawPath(metric.extractPath(d, next), paint);
      }
      d = next;
      draw = !draw;
    }
  }
}

/// 壁線ヒット（長押し削除・選択用）。重なるときは上に浮いている T を優先
String? hitTestWall(List<WallSegment> walls, Offset p, {double thresh = 16}) {
  String? bestReg;
  var bestRegD = thresh;
  String? bestIron;
  var bestIronD = thresh;
  for (final w in walls) {
    for (var i = 0; i < w.points.length - 1; i++) {
      final d = _distToSeg(
        p,
        Offset(w.points[i].x, w.points[i].y),
        Offset(w.points[i + 1].x, w.points[i + 1].y),
      );
      if (w.isIronPlate) {
        if (d < bestIronD) {
          bestIronD = d;
          bestIron = w.id;
        }
      } else if (d < bestRegD) {
        bestRegD = d;
        bestReg = w.id;
      }
    }
  }
  return bestIron ?? bestReg;
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
