import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../widgets/measure_painters.dart';

/// 測定済み図面＋線・塗りを原画像解像度で PDF 化する
class MeasureDrawingExporter {
  MeasureDrawingExporter._();

  static bool hasContent(Measurement m) {
    return m.walls.any((w) => w.points.length >= 2) ||
        m.ceilings.any((c) => c.points.length >= 3) ||
        m.drops.any((d) => d.points.length >= 2) ||
        m.openings.isNotEmpty;
  }

  static Future<Uint8List> build({
    required SiteProject project,
    required List<Measurement> measurements,
    required Map<String, DrawingFile> drawingsById,
  }) async {
    final targets = measurements.where(hasContent).toList();
    if (targets.isEmpty) {
      throw Exception('no_measured_drawings');
    }

    final font = await PdfGoogleFonts.iBMPlexSansJPRegular();
    final fontBold = await PdfGoogleFonts.iBMPlexSansJPBold();
    final doc = pw.Document();

    for (final m in targets) {
      final drawing = drawingsById[m.drawingId];
      if (drawing == null) {
        throw Exception('drawing_missing:${m.name}');
      }
      final pagePng = await _compositePage(drawing, m);
      final decoded = await _decodeSize(pagePng);
      final headerH = 36.0;
      final longPt = 1684.0;
      final aspect = decoded.width / decoded.height;
      final imageW = aspect >= 1 ? longPt : longPt * aspect;
      final imageH = aspect >= 1 ? longPt / aspect : longPt;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(imageW, imageH + headerH, marginAll: 0),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: headerH,
                color: PdfColor.fromInt(0xFF0B1F3A),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${project.name}  /  ${m.name}  /  ${drawing.fileName}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    pw.Text(
                      'LGS+',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Image(
                pw.MemoryImage(pagePng),
                width: imageW,
                height: imageH,
                fit: pw.BoxFit.fill,
              ),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  static Future<({int width, int height})> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    return (width: w, height: h);
  }

  static Future<Uint8List> _compositePage(
    DrawingFile drawing,
    Measurement measurement,
  ) async {
    final file = File(drawing.localPath);
    if (!await file.exists()) {
      throw Exception('drawing_missing:${measurement.name}');
    }
    final raw = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(raw);
    final frame = await codec.getNextFrame();
    final bg = frame.image;
    final w = bg.width;
    final h = bg.height;
    final size = Size(w.toDouble(), h.toDouble());
    final k = drawing.scalePxPerMm ?? 1;
    // 図面全体を1枚で見たときのラベル大きさ（測定画面のフィット表示に近い）
    final viewScale = (1200 / (w > h ? w : h)).clamp(0.35, 1.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    canvas.drawImageRect(
      bg,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    OverlayMidPainter(
      snapLines: const [],
      ceilings: measurement.ceilings,
      ceilingDraft: const [],
      wallDraft: const [],
      drops: measurement.drops,
      dropDraft: const [],
      scalePxPerMm: k,
      viewScale: viewScale,
    ).paint(canvas, size);

    OverlayTopPainter(
      walls: measurement.walls,
      ceilings: measurement.ceilings,
      openings: measurement.openings,
      scalePxPerMm: k,
      viewScale: viewScale,
      paintCeilingLabels: true,
      showLgsPreview: true,
    ).paint(canvas, size);

    final picture = recorder.endRecording();
    final composed = await picture.toImage(w, h);
    bg.dispose();
    picture.dispose();
    final data = await composed.toByteData(format: ui.ImageByteFormat.png);
    composed.dispose();
    if (data == null) {
      throw Exception('export_render_failed');
    }
    return data.buffer.asUint8List();
  }
}
