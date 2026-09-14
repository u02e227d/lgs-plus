import 'package:flutter/material.dart';

import '../l10n/s_measure.dart';
import '../theme/app_theme.dart';

/// 下りマウス：一横一折（第1辺＝幅、折後＝長）の図解
class DropDrawGuide extends StatelessWidget {
  const DropDrawGuide({
    super.key,
    this.width = 200,
    this.height = 140,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ms = Ms.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DropDrawGuidePainter(
          widthLabel: ms.dropGuideWidth,
          lengthLabel: ms.dropGuideLength,
        ),
      ),
    );
  }
}

class _DropDrawGuidePainter extends CustomPainter {
  _DropDrawGuidePainter({
    required this.widthLabel,
    required this.lengthLabel,
  });

  final String widthLabel;
  final String lengthLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.shortestSide * 0.08;
    final left = pad + 6;
    final top = size.height * 0.36;
    final cornerX = size.width * 0.52;
    final bottom = size.height - pad - 4;

    final line = Paint()
      ..color = AppTheme.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.shortestSide * 0.045).clamp(2.8, 4.2)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(left, top)
      ..lineTo(cornerX, top)
      ..lineTo(cornerX, bottom);
    canvas.drawPath(path, line);

    final dot = Paint()..color = AppTheme.safetyYellow;
    canvas.drawCircle(Offset(left, top), 4.5, dot);
    canvas.drawCircle(
      Offset(left, top),
      4.5,
      Paint()
        ..color = AppTheme.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(Offset(cornerX, top), 4.2, Paint()..color = AppTheme.navy);
    canvas.drawCircle(Offset(cornerX, bottom), 4.2, Paint()..color = AppTheme.navy);

    _label(
      canvas,
      widthLabel,
      Offset((left + cornerX) / 2, top - 16),
      size,
    );
    _label(
      canvas,
      lengthLabel,
      Offset(cornerX + 16, (top + bottom) / 2),
      size,
    );
  }

  void _label(Canvas canvas, String text, Offset center, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppTheme.navy,
          fontSize: (size.shortestSide * 0.13).clamp(11.0, 16.0),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DropDrawGuidePainter oldDelegate) =>
      oldDelegate.widthLabel != widthLabel ||
      oldDelegate.lengthLabel != lengthLabel;
}
