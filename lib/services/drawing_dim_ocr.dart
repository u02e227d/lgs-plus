import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'board_stack.dart';
import 'edge_snap_engine.dart';
import 'wall_auto_detector.dart';

/// 図面上の寸法・ボード構成（OCR）
class DrawingDimOcr {
  DrawingDimOcr._();

  static const minMm = 20.0;
  static const maxMm = 200.0;
  static const preferred = <double>[
    20, 25, 45, 50, 65, 70, 75, 90, 100, 105, 110, 115, 120, 125, 130, 140, 150,
  ];

  static Future<List<DetectedWallBand>> extractBands({
    required Uint8List imageBytes,
    required List<LineSeg> lines,
    required double imageWidth,
    required double imageHeight,
  }) async {
    final hits = await recognizeHits(imageBytes);
    if (hits.isEmpty) return const [];

    final bands = <DetectedWallBand>[];
    for (final hit in hits) {
      final line = _nearestLongLine(hit.center, lines) ??
          _syntheticLine(hit.center, imageWidth, imageHeight);
      bands.add(DetectedWallBand(
        a: line.a,
        b: line.b,
        thicknessMm: hit.finishedMm,
        confidence: hit.confidence,
        source: 'ocr',
        stackAMm: hit.stackA?.layersMm,
        stackBMm: hit.stackB?.layersMm,
      ));
    }
    return bands;
  }

  static Future<
      List<
          ({
            double finishedMm,
            Point2 center,
            double confidence,
            String raw,
            BoardStackSpec? stackA,
            BoardStackSpec? stackB,
          })>> recognizeHits(Uint8List imageBytes) async {
    // google_mlkit_text_recognition は iOS/Android のみ
    if (!Platform.isIOS && !Platform.isAndroid) {
      return const [];
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return const [];

    var work = decoded;
    var sx = 1.0;
    var sy = 1.0;
    const maxSide = 2000;
    final longSide = math.max(work.width, work.height);
    if (longSide > maxSide) {
      final scale = maxSide / longSide;
      work = img.copyResize(
        work,
        width: (work.width * scale).round(),
        height: (work.height * scale).round(),
      );
      sx = decoded.width / work.width;
      sy = decoded.height / work.height;
    }

    final jpg = Uint8List.fromList(img.encodeJpg(work, quality: 88));
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'lgs_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg'),
    );
    await file.writeAsBytes(jpg, flush: true);

    final input = InputImage.fromFilePath(file.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    try {
      final result = await recognizer.processImage(input);
      final hits = <
          ({
            double finishedMm,
            Point2 center,
            double confidence,
            String raw,
            BoardStackSpec? stackA,
            BoardStackSpec? stackB,
          })>[];

      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = line.text;
          final box = line.boundingBox;
          final center = Point2(
            (box.left + box.width / 2) * sx,
            (box.top + box.height / 2) * sy,
          );
          final parsed = _parseLine(text);
          for (final p in parsed) {
            hits.add((
              finishedMm: p.finishedMm,
              center: center,
              confidence: p.confidence,
              raw: text.trim(),
              stackA: p.stackA,
              stackB: p.stackB,
            ));
          }
        }
      }

      hits.sort((a, b) => b.confidence.compareTo(a.confidence));
      final kept = <
          ({
            double finishedMm,
            Point2 center,
            double confidence,
            String raw,
            BoardStackSpec? stackA,
            BoardStackSpec? stackB,
          })>[];
      for (final h in hits) {
        final dup = kept.any(
          (k) =>
              (k.finishedMm - h.finishedMm).abs() < 1 &&
              CalcDist.dist(k.center, h.center) < 48,
        );
        if (!dup) kept.add(h);
        if (kept.length >= 60) break;
      }
      return kept;
    } finally {
      await recognizer.close();
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  static List<
      ({
        double finishedMm,
        double confidence,
        BoardStackSpec? stackA,
        BoardStackSpec? stackB,
      })> _parseLine(String raw) {
    final t = raw
        .replaceAll('ｍｍ', 'mm')
        .replaceAll('ＭＭ', 'mm')
        .replaceAll('㎜', 'mm')
        .replaceAll('＋', '+')
        .replaceAll('×', 'x')
        .replaceAll(',', '')
        .replaceAll(' ', '');

    final out = <
        ({
          double finishedMm,
          double confidence,
          BoardStackSpec? stackA,
          BoardStackSpec? stackB,
        })>[];

    // 混層: 12.5+9.5 / 12.5＋9.5mm / PB12.5+9.5
    final mix = RegExp(
      r'(?:PB|pb|ボード)?(\d+\.?\d*)\+(\d+\.?\d*)(?:\+(\d+\.?\d*))?(?:mm)?',
    );
    for (final m in mix.allMatches(t)) {
      final layers = <double>[];
      for (var i = 1; i <= m.groupCount; i++) {
        final g = m.group(i);
        if (g == null) continue;
        final v = double.tryParse(g);
        if (v != null && v >= 8 && v <= 20) layers.add(v);
      }
      if (layers.length >= 2) {
        final stack = BoardStackSpec(layers);
        out.add((
          finishedMm: 65 + stack.totalMm + 12.5, // 仮：反対面12.5+65
          confidence: 0.88,
          stackA: stack,
          stackB: BoardStackSpec.single12_5,
        ));
        // スタック自体の合計も候補（片面構成として）
        out.add((
          finishedMm: stack.totalMm,
          confidence: 0.7,
          stackA: stack,
          stackB: null,
        ));
      }
    }

    // 両面異なる明示: A12.5/B12.5+9.5 など
    final ab = RegExp(
      r'[AaＡ面]?(\d+\.?\d*(?:\+\d+\.?\d*)*)[/／][BbＢ面]?(\d+\.?\d*(?:\+\d+\.?\d*)*)',
    );
    for (final m in ab.allMatches(t)) {
      final sa = _parseStackToken(m.group(1)!);
      final sb = _parseStackToken(m.group(2)!);
      if (sa != null && sb != null) {
        out.add((
          finishedMm: 65 + sa.totalMm + sb.totalMm,
          confidence: 0.92,
          stackA: sa,
          stackB: sb,
        ));
      }
    }

    // 通常壁厚
    final patterns = <RegExp>[
      RegExp(r'(?:壁厚|厚み|厚さ|t[=:：]?|T[=:：]?)(\d{2,3})(?:mm)?'),
      RegExp(r'(\d{2,3})\s*(?:mm)'),
      RegExp(r'[WwＷｗ](\d{2,3})'),
    ];
    for (final re in patterns) {
      for (final m in re.allMatches(t)) {
        final v = double.tryParse(m.group(1)!);
        if (v != null && v >= minMm && v <= maxMm) {
          out.add((
            finishedMm: v,
            confidence: 0.6,
            stackA: null,
            stackB: null,
          ));
        }
      }
    }

    if (out.isEmpty) {
      final alone = RegExp(r'(?<!\d)(\d{2,3})(?!\d)');
      for (final m in alone.allMatches(t)) {
        final v = double.tryParse(m.group(1)!);
        if (v != null && v >= minMm && v <= maxMm) {
          out.add((
            finishedMm: v,
            confidence: 0.45,
            stackA: null,
            stackB: null,
          ));
        }
      }
    }
    return out;
  }

  static BoardStackSpec? _parseStackToken(String token) {
    final parts = token.split('+');
    final layers = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p);
      if (v == null || v < 8 || v > 20) return null;
      layers.add(v);
    }
    if (layers.isEmpty) return null;
    return BoardStackSpec.matchGaps(layers) ?? BoardStackSpec(layers);
  }

  static LineSeg? _nearestLongLine(Point2 c, List<LineSeg> lines) {
    LineSeg? best;
    var bestD = 120.0;
    for (final l in lines) {
      if (CalcDist.dist(l.a, l.b) < 40) continue;
      final d = _distPointToSeg(c, l);
      if (d < bestD) {
        bestD = d;
        best = l;
      }
    }
    return best;
  }

  static LineSeg _syntheticLine(Point2 c, double w, double h) {
    final half = math.min(w, h) * 0.08;
    return LineSeg(Point2(c.x - half, c.y), Point2(c.x + half, c.y));
  }

  static double _distPointToSeg(Point2 p, LineSeg s) {
    final dx = s.b.x - s.a.x;
    final dy = s.b.y - s.a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 <= 0) return CalcDist.dist(p, s.a);
    var t = ((p.x - s.a.x) * dx + (p.y - s.a.y) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    return CalcDist.dist(p, Point2(s.a.x + dx * t, s.a.y + dy * t));
  }
}
