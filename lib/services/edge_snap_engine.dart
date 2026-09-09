import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/models.dart';

/// 端側線分抽出 + マグネット吸着（OpenCV HoughLinesP 相当の軽量実装）
/// 依存ゼロのオンデバイス処理：API費用なし・オフライン可
class EdgeSnapEngine {
  static const double snapRadiusPx = 10;

  List<LineSeg> lines = [];

  /// 図面バイト列から直線を抽出
  Future<void> analyze(Uint8List bytes, {int maxSide = 1200}) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      lines = [];
      return;
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
    final edges = _cannyLite(gray, low: 25, high: 80);
    final scaleX = decoded.width / work.width;
    final scaleY = decoded.height / work.height;
    final raw = _houghLinesP(edges, minLen: 24, maxGap: 12, threshold: 28);

    lines = raw
        .map(
          (l) => LineSeg(
            Point2(l.x1 * scaleX, l.y1 * scaleY),
            Point2(l.x2 * scaleX, l.y2 * scaleY),
          ),
        )
        .toList();
  }

  /// カーソル位置を最も近い線分へ吸着
  Point2 snap(Point2 raw) {
    if (lines.isEmpty) return raw;
    Point2 best = raw;
    var bestDist = snapRadiusPx;
    for (final line in lines) {
      final p = _closestOnSegment(raw, line.a, line.b);
      final d = CalcDist.dist(raw, p);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    // 端点優先（角吸着）
    for (final line in lines) {
      for (final ep in [line.a, line.b]) {
        final d = CalcDist.dist(raw, ep);
        if (d < bestDist) {
          bestDist = d;
          best = ep;
        }
      }
    }
    return best;
  }

  static Point2 _closestOnSegment(Point2 p, Point2 a, Point2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return a;
    var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    return Point2(a.x + t * dx, a.y + t * dy);
  }

  /// 軽量 Canny（Sobel + 非最大抑制 + 双閾値）
  img.Image _cannyLite(img.Image gray, {required int low, required int high}) {
    final w = gray.width;
    final h = gray.height;
    final gx = List.filled(w * h, 0.0);
    final gy = List.filled(w * h, 0.0);
    final mag = List.filled(w * h, 0.0);

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
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
        gx[i] = sx;
        gy[i] = sy;
        mag[i] = math.sqrt(sx * sx + sy * sy);
      }
    }

    final out = img.Image(width: w, height: h);
    img.fill(out, color: img.ColorRgb8(0, 0, 0));

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final angle = math.atan2(gy[i], gx[i]) * 180 / math.pi;
        final a = (angle < 0 ? angle + 180 : angle);
        double n1, n2;
        if ((a >= 0 && a < 22.5) || (a >= 157.5 && a <= 180)) {
          n1 = mag[i - 1];
          n2 = mag[i + 1];
        } else if (a >= 22.5 && a < 67.5) {
          n1 = mag[(y - 1) * w + (x + 1)];
          n2 = mag[(y + 1) * w + (x - 1)];
        } else if (a >= 67.5 && a < 112.5) {
          n1 = mag[(y - 1) * w + x];
          n2 = mag[(y + 1) * w + x];
        } else {
          n1 = mag[(y - 1) * w + (x - 1)];
          n2 = mag[(y + 1) * w + (x + 1)];
        }
        final m = mag[i];
        if (m >= n1 && m >= n2 && m >= high) {
          out.setPixelRgb(x, y, 255, 255, 255);
        } else if (m >= n1 && m >= n2 && m >= low) {
          out.setPixelRgb(x, y, 128, 128, 128);
        }
      }
    }
    return out;
  }

  /// 確率的霍夫変換の簡易版
  List<_RawLine> _houghLinesP(
    img.Image edges, {
    required int minLen,
    required int maxGap,
    required int threshold,
  }) {
    final w = edges.width;
    final h = edges.height;
    const thetaStep = math.pi / 180;
    final numTheta = 180;
    final maxRho = math.sqrt(w * w + h * h).ceil();
    final numRho = maxRho * 2;
    final acc = List.filled(numRho * numTheta, 0);
    final cosT = List.generate(numTheta, (t) => math.cos(t * thetaStep));
    final sinT = List.generate(numTheta, (t) => math.sin(t * thetaStep));

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (edges.getPixel(x, y).r < 200) continue;
        for (var t = 0; t < numTheta; t++) {
          final rho = (x * cosT[t] + y * sinT[t]).round() + maxRho;
          if (rho < 0 || rho >= numRho) continue;
          acc[rho * numTheta + t]++;
        }
      }
    }

    final candidates = <(int rho, int t, int votes)>[];
    for (var rho = 0; rho < numRho; rho++) {
      for (var t = 0; t < numTheta; t++) {
        final v = acc[rho * numTheta + t];
        if (v >= threshold) candidates.add((rho, t, v));
      }
    }
    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    final top = candidates.take(80).toList();

    final result = <_RawLine>[];
    for (final c in top) {
      final rho = c.$1 - maxRho;
      final t = c.$2;
      final pts = <(int, int)>[];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (edges.getPixel(x, y).r < 200) continue;
          final r = (x * cosT[t] + y * sinT[t]).round();
          if ((r - rho).abs() <= 1) pts.add((x, y));
        }
      }
      if (pts.length < minLen) continue;
      pts.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
      // 連結セグメント抽出
      var start = 0;
      for (var i = 1; i <= pts.length; i++) {
        final broken = i == pts.length ||
            (math.sqrt(
                  math.pow(pts[i].$1 - pts[i - 1].$1, 2) +
                      math.pow(pts[i].$2 - pts[i - 1].$2, 2),
                ) >
                maxGap);
        if (broken) {
          final seg = pts.sublist(start, i);
          if (seg.length >= minLen ~/ 2) {
            final a = seg.first;
            final b = seg.last;
            final len = math.sqrt(
              math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2),
            );
            if (len >= minLen) {
              result.add(_RawLine(a.$1.toDouble(), a.$2.toDouble(),
                  b.$1.toDouble(), b.$2.toDouble()));
            }
          }
          start = i;
        }
      }
    }
    return result;
  }
}

class LineSeg {
  final Point2 a;
  final Point2 b;
  LineSeg(this.a, this.b);
}

class _RawLine {
  final double x1, y1, x2, y2;
  _RawLine(this.x1, this.y1, this.x2, this.y2);
}

class CalcDist {
  static double dist(Point2 a, Point2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
