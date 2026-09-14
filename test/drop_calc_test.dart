import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/drop_calc.dart';
import 'package:lgs_plus/services/estimate_builder.dart';

void main() {
  test('L型SQ：面積は（幅＋高さ）×長さ', () {
    final q = DropCalc.calc(
      lengthMm: 3600,
      widthMm: 450,
      heightMm: 300,
      method: const DropMethod(
        shape: DropShape.lType,
        system: CeilingSystemKind.sq,
        runnerLengthMm: 4000,
        pitchMm: 303,
        studLengthMm: 2800,
      ),
    );
    expect(q['runner_count'], 4);
    expect(q['drop_area_m2'], closeTo((0.45 + 0.3) * 3.6, 0.01));
  });

  test('第2・第3幅：区間ごとに (W+H)×L、直角二重計上なし', () {
    // P0-P1 幅400 / P1-P2 L=2000 W1 / P2-P3 L=1500 W2=500 / P3-P4 L=1000 W3=600
    final pts = [
      const Point2(0, 0),
      const Point2(400, 0),
      const Point2(400, 2000),
      const Point2(1900, 2000),
      const Point2(1900, 3000),
    ];
    final area = DropCalc.areaM2Polyline(
      points: pts,
      scalePxPerMm: 1,
      firstWidthMm: 400,
      heightMm: 300,
      turnWidths: {2: 500, 3: 600},
    );
    // (0.4+0.3)*2 + (0.5+0.3)*1.5 + (0.6+0.3)*1
    expect(area, closeTo(1.4 + 1.2 + 0.9, 0.001));
  });

  test('L型在来：シングルバー倍数・クリップ', () {
    expect(DropCalc.singleBarMultL(303), 1);
    expect(DropCalc.singleBarMultL(304), 2);

    final qLow = DropCalc.calc(
      lengthMm: 2400,
      widthMm: 500,
      heightMm: 300,
      method: const DropMethod(
        shape: DropShape.lType,
        system: CeilingSystemKind.zairai,
        runnerLengthMm: 4000,
        wBarLengthMm: 4000,
        singleBarLengthMm: 4000,
        channelLengthMm: 4000,
      ),
    );
    expect(qLow['single_bar_count'], 1);
    expect(qLow['single_clip_count'], closeTo(2400 / 800 * 1, 0.01));
  });

  test('梁型SQランナー×6', () {
    final q = DropCalc.calc(
      lengthMm: 4000,
      widthMm: 400,
      heightMm: 300,
      method: const DropMethod(
        shape: DropShape.beam,
        system: CeilingSystemKind.sq,
        runnerLengthMm: 4000,
      ),
    );
    expect(q['runner_count'], 6);
  });

  test('在来：ランナー幅20mmはWバー／シングルバー19mmと対標', () {
    expect(DropMethod.barHeightForRunner(20), 19);
    expect(DropMethod.barHeightForRunner(25), 25);
    expect(DropMethod.runnerWidthForBar(19), 20);
    expect(DropMethod.runnerWidthForBar(25), 25);
    expect(DropMethod.runnerMatchesBar(20, 19), isTrue);
    expect(DropMethod.runnerMatchesBar(25, 25), isTrue);
    expect(DropMethod.runnerMatchesBar(20, 25), isFalse);
    expect(const DropMethod().wBarHeightMm, 19);
    expect(const DropMethod().singleBarHeightMm, 19);
    expect(const DropMethod().runnerHeightMm, 20);

    final old = DropMethod.fromJson(const {
      'wBarHeightMm': 20,
      'singleBarHeightMm': 20,
      'runnerHeightMm': 20,
    });
    expect(old.wBarHeightMm, 19);
    expect(old.singleBarHeightMm, 19);
    expect(old.runnerHeightMm, 20);
  });

  test('DropMethod ボード層は JSON で保持', () {
    const m = DropMethod(
      boards: [
        CeilingFinishBoardLayer(
          name: 'ケイカル平',
          widthMm: 910,
          heightMm: 1820,
          thicknessMm: 12.5,
        ),
      ],
    );
    final back = DropMethod.fromJson(m.toJson());
    expect(back.boards.single.name, 'ケイカル平');
    expect(back.boards.single.thicknessMm, 12.5);
  });

  test('下りボード：面積から枚数を切り上げて試算行へ', () {
    const method = DropMethod(
      shape: DropShape.lType,
      system: CeilingSystemKind.sq,
      runnerLengthMm: 4000,
      pitchMm: 303,
      studLengthMm: 2800,
      boards: [
        CeilingFinishBoardLayer(
          name: 'タイガーボード',
          widthMm: 910,
          heightMm: 1820,
          thicknessMm: 9.5,
        ),
      ],
    );
    final qty = DropCalc.calc(
      lengthMm: 3600,
      widthMm: 450,
      heightMm: 300,
      method: method,
    );
    final lines = EstimateBuilder.fromDrop(
      drop: DropRegion(
        id: 't',
        points: const [],
        lengthMm: 3600,
        widthMm: 450,
        heightMm: 300,
        method: method,
        quantities: qty,
      ),
      idGen: () => 'x',
    );
    final board = lines.firstWhere((e) => e.name == 'タイガーボード');
    expect(board.unit, '枚');
    expect(board.qty, 2);
    expect(board.note, startsWith('drop|'));
    expect(EstimateBuilder.classifyKind(board), EstimateSheetKind.board);
    expect(EstimateBuilder.isDropLine(board), isTrue);
    expect(EstimateBuilder.isLgsLine(lines.firstWhere((e) => e.name.contains('ランナー'))), isTrue);
  });
}
