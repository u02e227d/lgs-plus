import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/models.dart';
import 'board_stack.dart';
import 'drawing_dim_ocr.dart';
import 'edge_snap_engine.dart';
import 'lgs_catalog.dart';

/// AIが図面から検出した壁帯
class DetectedWallBand {
  final Point2 a;
  final Point2 b;
  final double thicknessMm;
  final double confidence;
  final String source; // parallel | stroke | ocr | board_layers
  final List<double>? stackAMm;
  final List<double>? stackBMm;

  const DetectedWallBand({
    required this.a,
    required this.b,
    required this.thicknessMm,
    required this.confidence,
    this.source = 'parallel',
    this.stackAMm,
    this.stackBMm,
  });

  Color get highlightColor => ThicknessHighlight.colorForMm(thicknessMm);

  String get stackLabel {
    final a = stackAMm == null || stackAMm!.isEmpty
        ? null
        : stackAMm!.map((e) => e.toStringAsFixed(e == e.roundToDouble() ? 0 : 1)).join('+');
    final b = stackBMm == null || stackBMm!.isEmpty
        ? null
        : stackBMm!.map((e) => e.toStringAsFixed(e == e.roundToDouble() ? 0 : 1)).join('+');
    if (a != null && b != null) return 'A:$a / B:$b';
    if (a != null) return 'A:$a';
    if (b != null) return 'B:$b';
    return '';
  }
}

/// 測定入場時の壁厚自動抽出（平行線＋線幅の二系統）
class WallAutoDetector {
  WallAutoDetector._();

  static List<DetectedWallBand> detect(
    List<LineSeg> lines,
    double scalePxPerMm, {
    List<DetectedWallBand> strokeBands = const [],
  }) {
    final out = <DetectedWallBand>[...strokeBands];
    if (scalePxPerMm <= 0) return _nms(out, 1);

    if (lines.length >= 2) {
      out.addAll(_fromParallelPairs(lines, scalePxPerMm));
    }

    // それでも空なら：各線に「最近傍平行線」の垂距を厚さとして付与
    if (out.isEmpty && lines.isNotEmpty) {
      out.addAll(_nearestNeighborBands(lines, scalePxPerMm));
    }

    return _nms(out, scalePxPerMm);
  }

  /// 作業画像上で線の黒幅を測り壁厚候補にする
  static List<DetectedWallBand> detectStrokeWidths({
    required img.Image grayWork,
    required List<LineSeg> linesInFullRes,
    required double scaleX,
    required double scaleY,
    required double scalePxPerMm,
  }) {
    if (scalePxPerMm <= 0 || linesInFullRes.isEmpty) return const [];
    final bands = <DetectedWallBand>[];

    for (final full in linesInFullRes) {
      final len = CalcDist.dist(full.a, full.b);
      if (len < 40) continue;

      // work座標へ
      final a = Point2(full.a.x / scaleX, full.a.y / scaleY);
      final b = Point2(full.b.x / scaleX, full.b.y / scaleY);
      final wPx = _strokeWidthPx(grayWork, a, b);
      if (wPx < 2.5 || wPx > 80) continue;

      // 作業画像px → 原画像px → mm
      final fullW = wPx * ((scaleX + scaleY) / 2);
      final mm = fullW / scalePxPerMm;
      // 線幅そのものが壁厚に近い図面／または芯線のみの場合は形に丸める
      final thickness = mm.clamp(20.0, 180.0);
      bands.add(DetectedWallBand(
        a: full.a,
        b: full.b,
        thicknessMm: thickness,
        confidence: 0.4,
        source: 'stroke',
      ));
    }
    return bands;
  }

  static List<DetectedWallBand> _fromParallelPairs(
    List<LineSeg> lines,
    double k,
  ) {
    final bands = <DetectedWallBand>[];
    const minLen = 20.0;
    for (var i = 0; i < lines.length; i++) {
      final la = lines[i];
      final lenA = CalcDist.dist(la.a, la.b);
      if (lenA < minLen) continue;
      final ax = la.b.x - la.a.x;
      final ay = la.b.y - la.a.y;
      final al = math.sqrt(ax * ax + ay * ay);
      if (al < 1) continue;
      final dx = ax / al;
      final dy = ay / al;

      for (var j = i + 1; j < lines.length; j++) {
        final lb = lines[j];
        final lenB = CalcDist.dist(lb.a, lb.b);
        if (lenB < minLen) continue;
        final bx = lb.b.x - lb.a.x;
        final by = lb.b.y - lb.a.y;
        final bl = math.sqrt(bx * bx + by * by);
        if (bl < 1) continue;
        if ((dx * (bx / bl) + dy * (by / bl)).abs() < 0.86) continue;

        final gapPx = _perpGap(la, lb, dx, dy);
        if (gapPx == null || gapPx < 2) continue;
        final mm = gapPx / k;
        if (mm < 12 || mm > 220) continue;

        final overlap = _overlap(la, lb, dx, dy);
        if (overlap < 12) continue;

        final c = _center(la, lb, dx, dy);
        bands.add(DetectedWallBand(
          a: c.$1,
          b: c.$2,
          thicknessMm: mm,
          confidence: (overlap / math.max(lenA, lenB)).clamp(0.25, 0.95),
          source: 'parallel',
        ));
      }
    }
    return bands;
  }

  static List<DetectedWallBand> _nearestNeighborBands(
    List<LineSeg> lines,
    double k,
  ) {
    final bands = <DetectedWallBand>[];
    for (var i = 0; i < lines.length; i++) {
      final la = lines[i];
      final lenA = CalcDist.dist(la.a, la.b);
      if (lenA < 36) continue;
      final ax = la.b.x - la.a.x;
      final ay = la.b.y - la.a.y;
      final al = math.sqrt(ax * ax + ay * ay);
      if (al < 1) continue;
      final dx = ax / al;
      final dy = ay / al;

      double? bestGap;
      LineSeg? best;
      for (var j = 0; j < lines.length; j++) {
        if (i == j) continue;
        final lb = lines[j];
        if (CalcDist.dist(lb.a, lb.b) < 24) continue;
        final bx = lb.b.x - lb.a.x;
        final by = lb.b.y - lb.a.y;
        final bl = math.sqrt(bx * bx + by * by);
        if (bl < 1) continue;
        if ((dx * (bx / bl) + dy * (by / bl)).abs() < 0.85) continue;
        if (_overlap(la, lb, dx, dy) < 16) continue;
        final g = _perpGap(la, lb, dx, dy);
        if (g == null) continue;
        final mm = g / k;
        if (mm < 12 || mm > 220) continue;
        if (bestGap == null || g < bestGap) {
          bestGap = g;
          best = lb;
        }
      }
      if (best == null || bestGap == null) continue;
      final c = _center(la, best, dx, dy);
      bands.add(DetectedWallBand(
        a: c.$1,
        b: c.$2,
        thicknessMm: bestGap / k,
        confidence: 0.35,
        source: 'parallel',
      ));
    }
    return bands;
  }

  static double? _perpGap(LineSeg a, LineSeg b, double dx, double dy) {
    final nx = -dy;
    final ny = dx;
    final midB = Point2((b.a.x + b.b.x) / 2, (b.a.y + b.b.y) / 2);
    final midA = Point2((a.a.x + a.b.x) / 2, (a.a.y + a.b.y) / 2);
    final d1 = ((midB.x - a.a.x) * nx + (midB.y - a.a.y) * ny).abs();
    final d2 = ((midA.x - b.a.x) * nx + (midA.y - b.a.y) * ny).abs();
    return (d1 + d2) / 2;
  }

  static double _overlap(LineSeg a, LineSeg b, double dx, double dy) {
    double proj(Point2 p) => p.x * dx + p.y * dy;
    final a0 = proj(a.a), a1 = proj(a.b);
    final b0 = proj(b.a), b1 = proj(b.b);
    final aMin = math.min(a0, a1), aMax = math.max(a0, a1);
    final bMin = math.min(b0, b1), bMax = math.max(b0, b1);
    return math.max(0.0, math.min(aMax, bMax) - math.max(aMin, bMin));
  }

  static (Point2, Point2) _center(
    LineSeg a,
    LineSeg b,
    double dx,
    double dy,
  ) {
    final nx = -dy;
    final ny = dx;
    final midB = Point2((b.a.x + b.b.x) / 2, (b.a.y + b.b.y) / 2);
    final side = (midB.x - a.a.x) * nx + (midB.y - a.a.y) * ny;
    final half = side / 2;
    return (
      Point2(a.a.x + nx * half, a.a.y + ny * half),
      Point2(a.b.x + nx * half, a.b.y + ny * half),
    );
  }

  /// 線に直交する暗いラン長（作業画像px）
  static double _strokeWidthPx(img.Image gray, Point2 a, Point2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return 0;
    final ux = dx / len;
    final uy = dy / len;
    final nx = -uy;
    final ny = ux;
    // 数点サンプルの中央値
    final samples = <double>[];
    for (final t in [0.3, 0.5, 0.7]) {
      final p = Point2(a.x + dx * t, a.y + dy * t);
      samples.add(_darkRun(gray, p, nx, ny));
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  static double _darkRun(img.Image g, Point2 p, double nx, double ny) {
    bool dark(int x, int y) {
      if (x < 1 || y < 1 || x >= g.width - 1 || y >= g.height - 1) {
        return false;
      }
      return g.getPixel(x, y).r < 140;
    }

    final cx = p.x.round();
    final cy = p.y.round();
    var neg = 0;
    var pos = 0;
    for (var i = 0; i < 40; i++) {
      final x = (cx + nx * i).round();
      final y = (cy + ny * i).round();
      if (!dark(x, y)) break;
      pos = i + 1;
    }
    for (var i = 0; i < 40; i++) {
      final x = (cx - nx * i).round();
      final y = (cy - ny * i).round();
      if (!dark(x, y)) break;
      neg = i + 1;
    }
    return (pos + neg).toDouble();
  }

  static List<DetectedWallBand> _nms(List<DetectedWallBand> raw, double k) {
    if (raw.length <= 1) return raw;
    final sorted = [...raw]
      ..sort((a, b) {
        final sa = CalcDist.dist(a.a, a.b) * a.confidence;
        final sb = CalcDist.dist(b.a, b.b) * b.confidence;
        return sb.compareTo(sa);
      });
    final kept = <DetectedWallBand>[];
    for (final c in sorted) {
      var ok = true;
      final midC = Point2((c.a.x + c.b.x) / 2, (c.a.y + c.b.y) / 2);
      for (final x in kept) {
        final midX = Point2((x.a.x + x.b.x) / 2, (x.a.y + x.b.y) / 2);
        if (CalcDist.dist(midC, midX) < 28 &&
            (c.thicknessMm - x.thicknessMm).abs() < 25) {
          ok = false;
          break;
        }
      }
      if (ok) kept.add(c);
      if (kept.length >= 120) break;
    }
    return kept;
  }
}

/// analyze 結果をまとめて返すため EdgeSnap から呼ぶヘルパ
class WallAiPipeline {
  WallAiPipeline._();

  static Future<
      ({
        List<LineSeg> lines,
        List<DetectedWallBand> bands,
        int ocrHits,
      })> run(
    Uint8List bytes,
    double scalePxPerMm, {
    int maxSide = 1400,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return (
        lines: <LineSeg>[],
        bands: <DetectedWallBand>[],
        ocrHits: 0,
      );
    }

    var work = decoded;
    final longSide = math.max(work.width, work.height);
    if (longSide > maxSide) {
      final scale = maxSide / longSide;
      work = img.copyResize(
        work,
        width: (work.width * scale).round(),
        height: (work.height * scale).round(),
      );
    }

    final gray = img.grayscale(work);
    final edges = _canny(gray, low: 20, high: 70);
    final scaleX = decoded.width / work.width;
    final scaleY = decoded.height / work.height;
    final raw = _hough(edges, minLen: 18, maxGap: 14, threshold: 22);

    final lines = raw
        .map(
          (l) => LineSeg(
            Point2(l.$1 * scaleX, l.$2 * scaleY),
            Point2(l.$3 * scaleX, l.$4 * scaleY),
          ),
        )
        .toList();

    // ① OCR：図面の寸法数字から壁厚
    List<DetectedWallBand> ocrBands = const [];
    try {
      ocrBands = await DrawingDimOcr.extractBands(
        imageBytes: bytes,
        lines: lines,
        imageWidth: decoded.width.toDouble(),
        imageHeight: decoded.height.toDouble(),
      );
    } catch (_) {
      ocrBands = const [];
    }

    // ② 幾何：平行線・線幅
    final strokeBands = scalePxPerMm > 0
        ? WallAutoDetector.detectStrokeWidths(
            grayWork: gray,
            linesInFullRes: lines,
            scaleX: scaleX,
            scaleY: scaleY,
            scalePxPerMm: scalePxPerMm,
          )
        : <DetectedWallBand>[];

    final geoBands = WallAutoDetector.detect(
      lines,
      scalePxPerMm,
      strokeBands: strokeBands,
    );

    // ③ ボード積層線：片面12.5 / 片面12.5+9.5 など
    final layerBands = <DetectedWallBand>[];
    if (scalePxPerMm > 0 && geoBands.isNotEmpty) {
      for (final g in geoBands.take(40)) {
        final det = BoardLayerLineDetector.detect(
          wallCenter: [LineSeg(g.a, g.b)],
          allLines: lines,
          scalePxPerMm: scalePxPerMm,
        );
        if (det.sideA == null && det.sideB == null) continue;
        final thick = det.finishedMm ?? g.thicknessMm;
        layerBands.add(DetectedWallBand(
          a: g.a,
          b: g.b,
          thicknessMm: thick,
          confidence: det.confidence,
          source: 'board_layers',
          stackAMm: det.sideA?.layersMm,
          stackBMm: det.sideB?.layersMm,
        ));
      }
    }

    // 優先度: board_layers / OCR混層 > OCR厚 > 幾何
    final merged = <DetectedWallBand>[
      ...layerBands,
      ...ocrBands,
      ...geoBands.where((g) {
        for (final o in [...layerBands, ...ocrBands]) {
          final midG = Point2((g.a.x + g.b.x) / 2, (g.a.y + g.b.y) / 2);
          final midO = Point2((o.a.x + o.b.x) / 2, (o.a.y + o.b.y) / 2);
          if (CalcDist.dist(midG, midO) < 60) return false;
        }
        return true;
      }),
    ];

    return (lines: lines, bands: merged, ocrHits: ocrBands.length);
  }

  static img.Image _canny(img.Image gray, {required int low, required int high}) {
    final w = gray.width;
    final h = gray.height;
    final out = img.Image(width: w, height: h);
    img.fill(out, color: img.ColorRgb8(0, 0, 0));
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final tl = gray.getPixel(x - 1, y - 1).r.toDouble();
        final tc = gray.getPixel(x, y - 1).r.toDouble();
        final tr = gray.getPixel(x + 1, y - 1).r.toDouble();
        final ml = gray.getPixel(x - 1, y).r.toDouble();
        final mr = gray.getPixel(x + 1, y).r.toDouble();
        final bl = gray.getPixel(x - 1, y + 1).r.toDouble();
        final bc = gray.getPixel(x, y + 1).r.toDouble();
        final br = gray.getPixel(x + 1, y + 1).r.toDouble();
        final sx = -tl + tr - 2 * ml + 2 * mr - bl + br;
        final sy = -tl - 2 * tc - tr + bl + 2 * bc + br;
        final mag = math.sqrt(sx * sx + sy * sy);
        if (mag >= high) {
          out.setPixelRgb(x, y, 255, 255, 255);
        } else if (mag >= low) {
          out.setPixelRgb(x, y, 180, 180, 180);
        }
      }
    }
    return out;
  }

  static List<(double, double, double, double)> _hough(
    img.Image edges, {
    required int minLen,
    required int maxGap,
    required int threshold,
  }) {
    // 簡易：水平・垂直・斜めの走査で連結成分を線分化
    final w = edges.width;
    final h = edges.height;
    bool on(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h && edges.getPixel(x, y).r > 100;

    final lines = <(double, double, double, double)>[];

    void scan(int x0, int y0, int sx, int sy) {
      var x = x0;
      var y = y0;
      int? startX;
      int? startY;
      var gap = 0;
      var count = 0;
      while (x >= 0 && y >= 0 && x < w && y < h) {
        if (on(x, y)) {
          startX ??= x;
          startY ??= y;
          gap = 0;
          count++;
        } else if (startX != null) {
          gap++;
          if (gap > maxGap) {
            if (count >= minLen) {
              lines.add((
                startX.toDouble(),
                startY!.toDouble(),
                (x - sx * gap).toDouble(),
                (y - sy * gap).toDouble(),
              ));
            }
            startX = null;
            startY = null;
            count = 0;
            gap = 0;
          }
        }
        x += sx;
        y += sy;
      }
      if (startX != null && count >= minLen) {
        lines.add((
          startX.toDouble(),
          startY!.toDouble(),
          (x - sx).toDouble(),
          (y - sy).toDouble(),
        ));
      }
    }

    // 横
    for (var y = 0; y < h; y += 2) {
      scan(0, y, 1, 0);
    }
    // 縦
    for (var x = 0; x < w; x += 2) {
      scan(x, 0, 0, 1);
    }
    // 斜め
    for (var y = 0; y < h; y += 3) {
      scan(0, y, 1, 1);
      scan(0, y, 1, -1);
    }
    for (var x = 0; x < w; x += 3) {
      scan(x, 0, 1, 1);
      scan(x, h - 1, 1, -1);
    }

    // 間引き
    if (lines.length > 400) {
      return lines.sublist(0, 400);
    }
    return lines;
  }
}
