import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/ceiling_layout.dart';

void main() {
  test('在来3×6 227ピッチ：縁W〜1820パターン', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(1000, 0),
        Point2(1000, 1820),
        Point2(0, 1820),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(
        systemKind: CeilingSystemKind.zairai,
        panelSpec: CeilingPanelSpec.panel3x6,
        noenSpacingMm: 227,
      ),
    );
    final ys = r.noenBars.map((b) => b.a.dy.round()).toList();
    expect(ys, [0, 227, 455, 683, 910, 1137, 1365, 1593, 1820]);
    expect(r.noenBars.first.isW, isTrue);
    expect(r.noenBars.last.isW, isTrue);
    expect(r.noenBars.where((b) => !b.isW).length, 7);
  });

  test('在来3×6 303ピッチ', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(1000, 0),
        Point2(1000, 1820),
        Point2(0, 1820),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(
        systemKind: CeilingSystemKind.zairai,
        panelSpec: CeilingPanelSpec.panel3x6,
        noenSpacingMm: 303,
      ),
    );
    final ys = r.noenBars.map((b) => b.a.dy.round()).toList();
    expect(ys, [0, 303, 606, 910, 1213, 1516, 1820]);
  });

  test('在来2層：施工仕様1.5×3でもバーは3×6配置', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(1000, 0),
        Point2(1000, 1820),
        Point2(0, 1820),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(
        systemKind: CeilingSystemKind.zairai,
        panelSpec: CeilingPanelSpec.panel15x3,
        layers: BoardLayers.double,
        noenSpacingMm: 303,
      ),
    );
    final ys = r.noenBars.map((b) => b.a.dy.round()).toList();
    expect(ys, [0, 303, 606, 910, 1213, 1516, 1820]);
  });

  test('SQ角スタッド303・両端密着・野縁なし', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(1000, 0),
        Point2(1000, 909),
        Point2(0, 909),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(systemKind: CeilingSystemKind.sq),
    );
    expect(r.noenBars, isEmpty);
    final ys = r.squareStudBars.map((b) => b.a.dy.round()).toList();
    expect(ys.first, 0);
    expect(ys.last, 909);
    expect(ys.contains(303), isTrue);
    expect(ys.contains(606), isTrue);
    expect(r.ukeBars, isEmpty);
    expect(r.bolts, isEmpty);
  });

  test('SQ全ネジは野縁受け1列の上だけ（辺縁100・間隔≤900）', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(3000, 0),
        Point2(3000, 909),
        Point2(0, 909),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(systemKind: CeilingSystemKind.sq),
    );
    expect(r.ukeBars.length, 1);
    expect(r.bolts, isNotEmpty);
    final xs = r.bolts.map((b) => b.center.dx).toSet().toList()..sort();
    final ys = r.bolts.map((b) => b.center.dy).toSet().toList()..sort();
    // 野縁受け1列（スタッド長の中央）上の1列だけ
    expect(xs.length, 1);
    expect(xs.first, closeTo(1500, 0.5));
    expect(ys.first, closeTo(100, 0.5));
    expect(ys.last, closeTo(809, 0.5));
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i] - ys[i - 1], lessThanOrEqualTo(900.01));
    }
    expect(r.bolts.length, isNot(r.squareStudBars.length));
  });

  test('SQスタッド間隔227mm', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(1000, 0),
        Point2(1000, 909),
        Point2(0, 909),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(
        systemKind: CeilingSystemKind.sq,
        sqStudPitchMm: 227,
      ),
    );
    final ys = r.squareStudBars.map((b) => b.a.dy.round()).toList();
    expect(ys.first, 0);
    expect(ys.last, 909);
    expect(ys.contains(227), isTrue);
    expect(ys.contains(454), isTrue);
  });

  test('在来全ネジ：辺縁100mm必須・間隔≤900・前後左右整列', () {
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(2000, 0),
        Point2(2000, 2000),
        Point2(0, 2000),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(
        systemKind: CeilingSystemKind.zairai,
        panelSpec: CeilingPanelSpec.panel3x6,
        noenSpacingMm: 303,
      ),
    );
    expect(r.bolts, isNotEmpty);
    expect(r.ukeBars, isNotEmpty);
    // X・Y ともに辺縁100
    final xs = r.bolts.map((b) => b.center.dx).toSet().toList()..sort();
    final ys = r.bolts.map((b) => b.center.dy).toSet().toList()..sort();
    expect(xs.first, closeTo(100, 0.5));
    expect(xs.last, closeTo(1900, 0.5));
    expect(ys.first, closeTo(100, 0.5));
    expect(ys.last, closeTo(1900, 0.5));
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] - xs[i - 1], lessThanOrEqualTo(900.01));
    }
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i] - ys[i - 1], lessThanOrEqualTo(900.01));
    }
    // 各赤線の両端から100mmにボルト
    for (final uke in r.ukeBars) {
      final len = uke.lengthPx;
      expect(len, greaterThan(200));
      final ux = (uke.b.dx - uke.a.dx) / len;
      final uy = (uke.b.dy - uke.a.dy) / len;
      final head = Offset(uke.a.dx + ux * 100, uke.a.dy + uy * 100);
      final tail = Offset(uke.b.dx - ux * 100, uke.b.dy - uy * 100);
      bool near(Offset p, Offset q) => (p - q).distance < 1.0;
      expect(
        r.bolts.any((b) => near(b.center, head)),
        isTrue,
        reason: '頭から100mmに全ネジが必要',
      );
      expect(
        r.bolts.any((b) => near(b.center, tail)),
        isTrue,
        reason: '尾から100mmに全ネジが必要',
      );
    }
    // 同じ Y のボルトが複数赤線で揃う（左右整列）
    for (final y in ys) {
      final row = r.bolts.where((b) => (b.center.dy - y).abs() < 0.5).length;
      expect(row, equals(xs.length));
    }
  });

  test('定尺継ぎ手：7000→定尺5000で1継ぎ、4000は0', () {
    expect(
      CeilingLayoutEngine.countSpliceJoints(
        lengthsMm: const [7000, 4000, 12000],
        stockLengthMm: 5000,
      ),
      1 + 0 + 2, // 2本/1本/3本 → 1+0+2
    );
  });

  test('野縁受けチャンネル本数：7000×2本・定尺5000→余り流用で3本', () {
    final n = CeilingLayoutEngine.countUkeChannelPieces(
      ukeLengthsMm: const [7000, 7000],
      stockLengthMm: 5000,
    );
    expect(n, 3);
  });

  test('野縁受けチャンネル本数：余り2000未満は次へ流用しない', () {
    // 3500÷4000 → 1本・余り500は破棄。2本目も1本 → 計2
    final n = CeilingLayoutEngine.countUkeChannelPieces(
      ukeLengthsMm: const [3500, 3500],
      stockLengthMm: 4000,
    );
    expect(n, 2);
  });

  test('SQ：角スタッドと野縁受けの交点＝クリップ数', () {
    // 幅2500→野縁受けあり（>2200）、角スタッド303ピッチ
    final r = CeilingLayoutEngine.layout(
      points: const [
        Point2(0, 0),
        Point2(2500, 0),
        Point2(2500, 909),
        Point2(0, 909),
      ],
      scalePxPerMm: 1,
      method: const CeilingMethod(systemKind: CeilingSystemKind.sq),
    );
    expect(r.squareStudBars, isNotEmpty);
    expect(r.ukeBars, isNotEmpty);
    expect(r.squareStudUkeContactCount, greaterThan(0));
    expect(
      r.squareStudUkeContactCount,
      equals(r.squareStudBars.length * r.ukeBars.length),
    );
  });

  test('ランナー：直交両側縁合計÷定尺を切上げ', () {
    // 角スタッド水平 → 左右縁 909+909=1818、定尺3000 → 1本
    // 定尺1000 → ceil(1818/1000)=2
    const pts = [
      Point2(0, 0),
      Point2(2500, 0),
      Point2(2500, 909),
      Point2(0, 909),
    ];
    const method = CeilingMethod(systemKind: CeilingSystemKind.sq);
    final layout = CeilingLayoutEngine.layout(
      points: pts,
      scalePxPerMm: 1,
      method: method,
    );
    final edge = CeilingLayoutEngine.runnerPerpEdgeLengthMm(
      points: pts,
      scalePxPerMm: 1,
      method: method,
      squareStudBars: layout.squareStudBars,
    );
    expect(edge, closeTo(1818, 1));
    expect(
      CeilingLayoutEngine.countRunnerPieces(
        edgeTotalMm: 12100,
        stockLengthMm: 1000,
      ),
      13,
    ); // 12.1 → 13
    expect(
      CeilingLayoutEngine.countRunnerPieces(
        edgeTotalMm: edge,
        stockLengthMm: 1000,
      ),
      2,
    );
  });
}
