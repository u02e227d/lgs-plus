import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../theme/app_theme.dart';
import 'account_plan.dart';

/// WeChat向け：二次元コード＋招待コードの画像
class InviteCard {
  InviteCard._();

  static Future<Uint8List> png({
    required String inviteCode,
    String? extraText,
  }) async {
    const width = 720.0;
    const height = 1080.0;
    final code = AccountPlan.normalizeInviteCode(inviteCode);
    final link = AccountPlan.inviteLink(code);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = AppTheme.navy,
    );
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 40, 640, 1000),
      const Radius.circular(28),
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);

    _paintText(
      canvas,
      'LGS+積算',
      const Offset(360, 110),
      const TextStyle(
        color: AppTheme.navy,
        fontSize: 42,
        fontWeight: FontWeight.w900,
      ),
    );
    _paintText(
      canvas,
      '友達紹介',
      const Offset(360, 168),
      const TextStyle(
        color: AppTheme.steel,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    );
    _paintText(
      canvas,
      '招待コード',
      const Offset(360, 230),
      const TextStyle(color: AppTheme.steel, fontSize: 20),
    );
    _paintText(
      canvas,
      code,
      const Offset(360, 290),
      const TextStyle(
        color: AppTheme.navy,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );

    _drawQr(canvas, link, const Rect.fromLTWH(160, 360, 400, 400));

    _paintText(
      canvas,
      extraText?.trim().isNotEmpty == true
          ? extraText!.trim()
          : 'アプリの新規登録でこのコードを入力してください。\n登録した方に当月アップロード+2枚（最大3枚）。',
      const Offset(360, 830),
      const TextStyle(
        color: AppTheme.navy,
        fontSize: 20,
        height: 1.45,
      ),
      maxWidth: 560,
    );
    _paintText(
      canvas,
      link,
      const Offset(360, 970),
      const TextStyle(color: AppTheme.steel, fontSize: 16),
      maxWidth: 560,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes!.buffer.asUint8List();
  }

  static void _drawQr(Canvas canvas, String data, Rect box) {
    final qr = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    final n = qr.moduleCount;
    final cell = box.width / n;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.inflate(16), const Radius.circular(16)),
      Paint()..color = AppTheme.surface,
    );
    final black = Paint()..color = AppTheme.navy;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!qr.isDark(y, x)) continue;
        canvas.drawRect(
          Rect.fromLTWH(box.left + x * cell, box.top + y * cell, cell, cell),
          black,
        );
      }
    }
  }

  static void _paintText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    double maxWidth = 600,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
