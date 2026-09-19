import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 画面固定サイズの測定マウス（ズームしても大きさ不変）
class MeasureMousePainter extends CustomPainter {
  MeasureMousePainter({
    required this.tip,
    required this.ready,
    this.visible = true,
  });

  final Offset tip;
  final bool ready;
  final bool visible;

  /// 画面ピクセルでの棒長（ズーム非連動）
  static const double stemLengthScreen = 100;
  /// 先端ヒット用（円は描かない）
  static const double tipRadius = 1.0;
  static const double headScale = 1.55;

  /// 指（子座標）→ 先端（子座標）。[viewScale] は InteractiveViewer の現在倍率
  static Offset tipFromFinger(Offset fingerChild, double viewScale) {
    final s = viewScale <= 0.01 ? 1.0 : viewScale;
    return fingerChild - Offset(0, stemLengthScreen / s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final color = ready ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final dark = ready ? const Color(0xFF1B5E20) : const Color(0xFF8B0000);
    const s = headScale;

    // 細い軸（鋭い矢じり下から）
    final stemTop = tip + Offset(0, 24 * s);
    final base = tip + const Offset(0, stemLengthScreen);
    canvas.drawLine(
      stemTop,
      base,
      Paint()
        ..color = dark
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round,
    );

    // 全体は少し広く、尖端だけ細く鋭く（頂点円は描かない）
    final path = Path()
      ..moveTo(tip.dx, tip.dy) // 尖端（幅ゼロ）
      ..lineTo(tip.dx + 3.4 * s, tip.dy + 28 * s)
      ..lineTo(tip.dx + 1.35 * s, tip.dy + 23 * s)
      ..lineTo(tip.dx + 1.35 * s, tip.dy + 54 * s)
      ..lineTo(tip.dx - 1.35 * s, tip.dy + 54 * s)
      ..lineTo(tip.dx - 1.35 * s, tip.dy + 23 * s)
      ..lineTo(tip.dx - 3.4 * s, tip.dy + 28 * s)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..strokeJoin = StrokeJoin.miter
        ..strokeMiterLimit = 12,
    );
  }

  @override
  bool shouldRepaint(covariant MeasureMousePainter oldDelegate) =>
      tip != oldDelegate.tip ||
      ready != oldDelegate.ready ||
      visible != oldDelegate.visible;
}

class MouseToolIcon extends StatelessWidget {
  const MouseToolIcon({super.key, this.size = 18, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.35),
      painter: _MiniMouseIconPainter(color ?? const Color(0xFF0B1F3A)),
    );
  }
}

class _MiniMouseIconPainter extends CustomPainter {
  _MiniMouseIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final tip = Offset(cx, 1);
    final base = Offset(cx, size.height - 1);
    canvas.drawLine(
      tip + Offset(0, size.height * 0.28),
      base,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + size.width * 0.16, tip.dy + size.height * 0.42)
      ..lineTo(tip.dx + size.width * 0.05, tip.dy + size.height * 0.36)
      ..lineTo(tip.dx + size.width * 0.05, tip.dy + size.height * 0.62)
      ..lineTo(tip.dx - size.width * 0.05, tip.dy + size.height * 0.62)
      ..lineTo(tip.dx - size.width * 0.05, tip.dy + size.height * 0.36)
      ..lineTo(tip.dx - size.width * 0.16, tip.dy + size.height * 0.42)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MiniMouseIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

class HoldProgressPainter extends CustomPainter {
  HoldProgressPainter({
    required this.center,
    required this.progress,
    required this.color,
    this.showBaseRing = false,
    this.radius = 14,
  });
  final Offset center;
  final double progress;
  final Color color;
  final bool showBaseRing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (showBaseRing) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
    if (progress <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant HoldProgressPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      center != oldDelegate.center ||
      color != oldDelegate.color ||
      showBaseRing != oldDelegate.showBaseRing ||
      radius != oldDelegate.radius;
}

/// Mac：測点＝中心の十字＋赤→緑リング（矢印カーソルの「胴体」ズレを避ける）
class MacMeasureTipPainter extends CustomPainter {
  MacMeasureTipPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const ringR = 14.0;
    const cross = 7.0;

    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringR),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    final crossPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-cross, 0), c + const Offset(cross, 0), crossPaint);
    canvas.drawLine(c + const Offset(0, -cross), c + const Offset(0, cross), crossPaint);
    canvas.drawCircle(c, 1.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant MacMeasureTipPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

/// AI壁帯蛍光ペン（必ず視認できる最小幅）
class AiWallHighlightPainter extends CustomPainter {
  AiWallHighlightPainter({
    required this.bands,
    required this.scalePxPerMm,
  });

  final List<
          ({
            Offset a,
            Offset b,
            double thicknessMm,
            Color color,
            String source,
            String stackLabel,
          })>
      bands;
  final double scalePxPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in bands) {
      final natural = band.thicknessMm * scalePxPerMm;
      final thickPx = math.max(14.0, math.min(56.0, natural * 1.1));

      canvas.drawLine(
        band.a,
        band.b,
        Paint()
          ..color = band.color.withValues(alpha: 0.62)
          ..strokeWidth = thickPx
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        band.a,
        band.b,
        Paint()
          ..color = band.color
          ..strokeWidth = math.max(4.0, thickPx * 0.32)
          ..strokeCap = StrokeCap.round,
      );

      final mid = Offset(
        (band.a.dx + band.b.dx) / 2,
        (band.a.dy + band.b.dy) / 2,
      );
      final label = (band.source == 'ocr' || band.source == 'board_layers')
          ? (band.stackLabel.isNotEmpty
              ? '${band.source == 'ocr' ? 'OCR' : '層'} ${band.stackLabel}'
              : '${band.source == 'ocr' ? 'OCR ' : ''}${band.thicknessMm.toStringAsFixed(0)}mm')
          : '${band.thicknessMm.toStringAsFixed(0)}mm';
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: 12, textAlign: TextAlign.center),
      )
        ..pushStyle(ui.TextStyle(
          color: const Color(0xFF111111),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          background: Paint()..color = const Color(0xF5FFFFFF),
        ))
        ..addText(' $label ');
      final p = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 80));
      canvas.drawParagraph(
        p,
        Offset(mid.dx - p.maxIntrinsicWidth / 2, mid.dy - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AiWallHighlightPainter oldDelegate) => true;
}
