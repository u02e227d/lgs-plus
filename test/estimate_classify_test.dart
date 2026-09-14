import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/estimate_builder.dart';

EstimateLine line(String name, {String unit = '本', String spec = ''}) =>
    EstimateLine(
      id: '1',
      name: name,
      spec: spec,
      qty: 1,
      unit: unit,
      subtotal: 1,
    );

void main() {
  test('user-reported split', () {
    final all = [
      line('LGS ランナー'),
      line('コの字スタッド'),
      line('グラスウール', unit: 'm'),
      line('ランナースペーサー', unit: '個'),
      line('ロックフェルト', unit: '箱'),
      line('普通ボード', unit: '枚'),
      line('スペーサー', unit: '個'),
      line('タイガーUタイト', unit: '箱'),
    ];
    final board = EstimateBuilder.filterByKind(all, EstimateSheetKind.board);
    final lgs = EstimateBuilder.filterByKind(all, EstimateSheetKind.lgs);

    expect(board.map((e) => e.name).toSet(), {
      'グラスウール',
      'ロックフェルト',
      '普通ボード',
      'タイガーUタイト',
    });
    expect(lgs.map((e) => e.name).toSet(), {
      'LGS ランナー',
      'コの字スタッド',
      'ランナースペーサー',
      'スペーサー',
    });
    expect(board.length + lgs.length, all.length);
  });

  test('下り試算のボードとLGSは注文書で合算できる', () {
    final dropBoard = EstimateLine(
      id: 'db',
      name: 'タイガーボード',
      spec: '下り・第1層・9.5mm',
      lw: '3×6',
      qty: 2,
      unit: '枚',
      subtotal: 2,
      note: 'drop|L型',
      areaKind: 'drop',
    );
    final dropLgs = EstimateLine(
      id: 'dl',
      name: '下りランナー',
      spec: 'L型・45形',
      qty: 4,
      unit: '本',
      subtotal: 4,
      note: 'drop|L型',
      areaKind: 'drop',
    );
    final wallBoard = EstimateLine(
      id: 'wb',
      name: 'タイガーボード',
      spec: '第1層・9.5mm',
      lw: '3×6',
      qty: 3,
      unit: '枚',
      subtotal: 3,
      areaKind: 'wall',
    );
    expect(EstimateBuilder.classifyKind(dropBoard), EstimateSheetKind.board);
    expect(EstimateBuilder.classifyKind(dropLgs), EstimateSheetKind.lgs);
    expect(EstimateBuilder.isDropLine(dropBoard), isTrue);
    expect(EstimateBuilder.dropBoardLines([dropBoard, dropLgs]).single.id, 'db');
    expect(EstimateBuilder.dropLgsLines([dropBoard, dropLgs]).single.id, 'dl');

    var n = 0;
    final merged = EstimateBuilder.mergeForOrderDocument(
      [dropBoard, wallBoard],
      idGen: () => 'o${n++}',
    );
    expect(merged.length, 1);
    expect(merged.single.qty, 5);

    final saved = EstimateBuilder.mergeReplacingLineNumbersOfKind(
      existing: [dropBoard, dropLgs],
      incoming: [
        dropLgs
          ..qty = 6
          ..subtotal = 6,
      ],
      kind: EstimateSheetKind.lgs,
    );
    expect(saved.where((e) => e.name == 'タイガーボード').single.qty, 2);
    expect(saved.where((e) => e.name.contains('ランナー')).single.qty, 6);
  });

  test('見切り・その他区分の分類', () {
    expect(
      EstimateBuilder.classifyKind(line('アルミ見切り', unit: '本', spec: '見切り・定尺2000mm')),
      EstimateSheetKind.board,
    );
    expect(
      EstimateBuilder.classifyKind(line('ビス', unit: '箱', spec: 'ボード関連')),
      EstimateSheetKind.board,
    );
    expect(
      EstimateBuilder.classifyKind(line('高速カッター刃', unit: '枚', spec: 'その他')),
      EstimateSheetKind.lgs,
    );
    // ボード欄その他／名称にボード・ビス → ボード試算表
    expect(
      EstimateBuilder.classifyKind(line('ボードビス', unit: '箱', spec: 'その他')),
      EstimateSheetKind.board,
    );
    expect(
      EstimateBuilder.classifyKind(line('ボードビス', unit: '箱', spec: 'ボード関連')),
      EstimateSheetKind.board,
    );
  });

  test('ボード発注単位 箱・坪', () {
    final box = EstimateBuilder.packBoardSheets(19, widthMm: 300, heightMm: 600);
    expect(box.unit, '箱');
    expect(box.qty, 2);

    final tsubo = EstimateBuilder.packBoardSheets(
      9,
      widthMm: 455,
      heightMm: 910,
      thicknessMm: 9.5,
    );
    expect(tsubo.unit, '坪');
    expect(tsubo.qty, 2);

    final tsubo33 = EstimateBuilder.packBoardSheets(
      5,
      widthMm: 910,
      heightMm: 910,
      thicknessMm: 9.5,
      lw: '3×3',
    );
    expect(tsubo33.unit, '坪');
    expect(tsubo33.qty, 2);

    final notTsubo = EstimateBuilder.packBoardSheets(
      5,
      widthMm: 910,
      heightMm: 910,
      thicknessMm: 12.5,
      lw: '3×3',
    );
    expect(notTsubo.unit, '枚');
    expect(notTsubo.qty, 5);

    final sheets = EstimateBuilder.packBoardSheets(5, widthMm: 910, heightMm: 1820);
    expect(sheets.unit, '枚');
    expect(sheets.qty, 5);
  });

  test('壁と天井の試算表保存は互いに上書きしない', () {
    final wall = EstimateLine(
      id: 'w1',
      name: 'コの字スタッド',
      spec: '45',
      qty: 10,
      unit: '本',
      subtotal: 10,
      areaKind: 'wall',
    );
    final ceiling = EstimateLine(
      id: 'c1',
      name: 'Wバー',
      spec: '19',
      qty: 4,
      unit: '本',
      subtotal: 4,
      areaKind: 'ceiling',
    );
    final afterCeiling = EstimateBuilder.mergePreservingOtherAreas(
      existing: [wall],
      incoming: [ceiling],
      incomingArea: 'ceiling',
    );
    expect(afterCeiling.map((e) => e.name).toSet(), {
      'コの字スタッド',
      'Wバー',
    });
    final afterWallAgain = EstimateBuilder.mergePreservingOtherAreas(
      existing: afterCeiling,
      incoming: [
        wall
          ..qty = 12
          ..subtotal = 12,
      ],
      incomingArea: 'wall',
    );
    expect(afterWallAgain.map((e) => e.name).toSet(), {
      'コの字スタッド',
      'Wバー',
    });
    expect(afterWallAgain.firstWhere((e) => e.areaKind == 'wall').qty, 12);
  });

  test('試算表左上は測定名-天井／壁（工地名ではない）', () {
    expect(EstimateBuilder.placeLabel('洋室1', '天井'), '洋室1-天井');
    expect(EstimateBuilder.placeLabel('洋室1', '壁'), '洋室1-壁');
    expect(EstimateBuilder.placeLabel('洋室1-天井', '天井'), '洋室1-天井');
    expect(EstimateBuilder.placeLabel('', '天井'), '天井');
  });

  test('LGS面積欄は工法、ボード面積欄は品名', () {
    final wall = WallSegment(
      id: 'w1',
      points: const [Point2(0, 0), Point2(100, 0)],
      heightMm: 2700,
      estimateReady: true,
      method: const WallMethod(
        useLgs: true,
        useBoard: true,
        lgsFormCode: '45',
        boardKindA: 'タイガーボード',
        bothSides: false,
      ),
      quantities: const {'wall_area_m2': 12.34},
    );
    final ceiling = CeilingRegion(
      id: 'c1',
      points: const [Point2(0, 0), Point2(1, 0), Point2(1, 1)],
      method: const CeilingMethod(
        systemKind: CeilingSystemKind.sq,
        finishBoardLayers: [
          CeilingFinishBoardLayer(name: 'タイガーボード'),
        ],
      ),
      quantities: const {'ceiling_area_m2': 8.5},
    );
    final m = Measurement(
      id: 'm1',
      projectId: 'p1',
      drawingId: 'd1',
      name: '洋室1',
      walls: [wall],
      ceilings: [ceiling],
    );
    expect(EstimateBuilder.lgsMethodLabel(m, areaKind: '壁'), 'コの字45');
    expect(EstimateBuilder.lgsMethodLabel(m, areaKind: '天井'), 'SQ工法');
    final wallBoards = EstimateBuilder.boardAreasByName(m, areaKind: '壁');
    expect(wallBoards.single.name, 'タイガーボード');
    expect(wallBoards.single.m2, 12.34);
    final ceilBoards = EstimateBuilder.boardAreasByName(m, areaKind: '天井');
    expect(ceilBoards.single.name, 'タイガーボード　3×6');
    expect(ceilBoards.single.m2, 8.5);
  });

  test('鉄板数量は総長×段÷定尺', () {
    const m = WallMethod(
      useIronPlate: true,
      ironPlateLengthMm: 1820,
      ironPlateSegments: 3,
    );
    expect(m.ironPlateSegmentCount, 3);
    final sheets = (10000.0 * 3 / 1820).ceil();
    expect(sheets, 17);
    expect(const WallMethod(ironPlateSegments: 0).ironPlateSegmentCount, 1);
  });

  test('天井は非統合なら合算せず、統合時は品名+寸法が同じときだけ合算', () {
    EstimateLine board({
      required String id,
      required String lw,
      required double qty,
      required int group,
      String spec = '第1層・9.5mm',
    }) =>
        EstimateLine(
          id: id,
          name: 'タイガーボード',
          spec: spec,
          lw: lw,
          qty: qty,
          unit: '枚',
          subtotal: qty,
          wallLineNumber: group,
          areaKind: 'ceiling',
        );

    final split = EstimateBuilder.mergeByNameAndSize(
      [
        board(id: 'a', lw: '3×6', qty: 4, group: 1),
        board(id: 'b', lw: '3×6', qty: 5, group: 2),
      ],
      idGen: () => 'x',
    );
    expect(split.length, 2);
    expect(split.map((e) => e.qty).toSet(), {4, 5});

    final unifiedSame = EstimateBuilder.mergeByNameAndSize(
      [
        board(id: 'a', lw: '3×6', qty: 4, group: 1, spec: '第1層・9.5mm'),
        board(id: 'b', lw: '3×6', qty: 5, group: 1, spec: '第2層・9.5mm'),
      ],
      idGen: () => 'x',
    );
    expect(unifiedSame.length, 1);
    expect(unifiedSame.single.qty, 9);

    final unifiedDiffSize = EstimateBuilder.mergeByNameAndSize(
      [
        board(id: 'a', lw: '3×6', qty: 4, group: 1),
        board(id: 'b', lw: '3×3', qty: 5, group: 1),
      ],
      idGen: () => 'x',
    );
    expect(unifiedDiffSize.length, 2);
  });

  test('天井保存は他番号の明細を残す', () {
    final existing = [
      EstimateLine(
        id: '1',
        name: 'Wバー',
        spec: '高19mm',
        qty: 2,
        unit: '本',
        subtotal: 2,
        wallLineNumber: 1,
        areaKind: 'ceiling',
      ),
    ];
    final incoming = [
      EstimateLine(
        id: '2',
        name: 'Wバー',
        spec: '高19mm',
        qty: 3,
        unit: '本',
        subtotal: 3,
        wallLineNumber: 2,
        areaKind: 'ceiling',
      ),
    ];
    final merged = EstimateBuilder.mergeReplacingLineNumbers(
      existing: existing,
      incoming: incoming,
    );
    expect(merged.length, 2);
    expect(
      merged.firstWhere((e) => e.wallLineNumber == 1).qty,
      2,
    );
    expect(
      merged.firstWhere((e) => e.wallLineNumber == 2).qty,
      3,
    );
  });

  test('在来工法の天井施工仕様の既定は3×6', () {
    expect(const CeilingMethod().panelSpec, CeilingPanelSpec.panel3x6);
    expect(
      const CeilingMethod(systemKind: CeilingSystemKind.zairai).panelSpec,
      CeilingPanelSpec.panel3x6,
    );
    expect(
      const CeilingMethod(
        systemKind: CeilingSystemKind.sq,
        panelSpec: CeilingPanelSpec.panel3x3,
      ).copyWith(
        systemKind: CeilingSystemKind.zairai,
        panelSpec: CeilingPanelSpec.panel3x6,
      ).panelSpec,
      CeilingPanelSpec.panel3x6,
    );
  });

  test('別寸法の材料は寸法ごとに試算表へ計上する', () {
    var n = 0;
    String idGen() => 'e${n++}';

    final ceiling = CeilingRegion(
      id: 'c1',
      points: const [Point2(0, 0), Point2(1, 0), Point2(1, 1)],
      method: const CeilingMethod(
        extraSizedItems: [
          ExtraSizedItem(kind: 'w_bar', widthMm: 19, lengthMm: 4000, qty: 2),
          ExtraSizedItem(kind: 'w_bar', widthMm: 25, lengthMm: 4000, qty: 3),
          ExtraSizedItem(kind: 'runner', widthMm: 38, lengthMm: 3000, qty: 1),
          ExtraSizedItem(
            kind: 'sq_stud',
            code: '4050',
            lengthMm: 5000,
            qty: 2,
          ),
          ExtraSizedItem(
            kind: 'bolt',
            code: 'W1/2',
            lengthMm: 1500,
            qty: 4,
          ),
          ExtraSizedItem(
            kind: 'mikiri',
            code: '見切りA',
            lengthMm: 2000,
            qty: 3,
          ),
        ],
      ),
      quantities: const {},
    );
    final ceilLines =
        EstimateBuilder.fromCeiling(ceiling: ceiling, idGen: idGen);
    final wBars = ceilLines.where((e) => e.name == 'Wバー').toList();
    expect(wBars.length, 2);
    expect(wBars.map((e) => e.spec).toSet(), {'高19mm', '高25mm'});
    expect(wBars.map((e) => e.qty).toSet(), {2.0, 3.0});
    expect(
      ceilLines.where((e) => e.name == 'ランナー').single.spec,
      '幅38mm',
    );
    final sqExtra =
        ceilLines.where((e) => e.name == 'SQ角スタッド').single;
    expect(sqExtra.spec, '4050');
    expect(sqExtra.lw, '5000');
    expect(sqExtra.qty, 2);
    final boltExtra = ceilLines.where((e) => e.name == '全ネジボルト').single;
    expect(boltExtra.spec, 'W1/2 × 1500mm');
    expect(boltExtra.qty, 4);
    final mikiriExtra = ceilLines.where((e) => e.name == '見切りA').single;
    expect(mikiriExtra.spec, '見切り・定尺2000mm');
    expect(mikiriExtra.qty, 3);

    final wall = WallSegment(
      id: 'w1',
      points: const [Point2(0, 0), Point2(100, 0)],
      heightMm: 2700,
      method: const WallMethod(
        extraSizedItems: [
          ExtraSizedItem(kind: 'runner', widthMm: 45, lengthMm: 4000, qty: 2),
          ExtraSizedItem(kind: 'runner', widthMm: 65, lengthMm: 4000, qty: 4),
          ExtraSizedItem(
            kind: 'iron',
            widthMm: 300,
            lengthMm: 1820,
            qty: 3,
            unit: '枚',
          ),
        ],
      ),
      quantities: const {},
    );
    final wallLines = EstimateBuilder.fromWall(wall: wall, idGen: idGen);
    final runners = wallLines.where((e) => e.name == 'ランナー').toList();
    expect(runners.length, 2);
    expect(runners.map((e) => e.spec).toSet(), {'45形 天地', '65形 天地'});
    expect(wallLines.where((e) => e.name == '鉄板').single.qty, 3);

    final merged = EstimateBuilder.mergeByNameAndSize(
      [
        ...wBars,
        EstimateLine(
          id: 'x',
          name: 'Wバー',
          spec: '高19mm',
          lw: '4000',
          qty: 5,
          unit: '本',
          subtotal: 5,
          wallLineNumber: 1,
          areaKind: 'ceiling',
        ),
      ],
      idGen: idGen,
    );
    final mergedBars =
        merged.where((e) => e.name == 'Wバー').toList();
    expect(mergedBars.length, 2);
    expect(
      mergedBars.firstWhere((e) => e.spec == '高19mm').qty,
      7,
    );
    expect(
      mergedBars.firstWhere((e) => e.spec == '高25mm').qty,
      3,
    );

    final json = ExtraSizedItem.fromJson(
      const ExtraSizedItem(
        kind: 'channel',
        widthMm: 40,
        lengthMm: 5000,
        qty: 6,
      ).toJson(),
    );
    expect(json.kind, 'channel');
    expect(json.widthMm, 40);
    expect(json.lengthMm, 5000);
    expect(json.qty, 6);

    const pair19 = ExtraSizedItem(kind: 'runner', widthMm: 20, lengthMm: 4000);
    expect(pair19.estimateSpec(ceiling: true), '幅20mm');
  });

  test('天井材料の別寸法はmethodごと保存すると試算表に出る', () {
    const extras = [
      ExtraSizedItem(kind: 'w_bar', widthMm: 25, lengthMm: 4000, qty: 7),
      ExtraSizedItem(kind: 'bolt', code: 'W1/2', lengthMm: 1500, qty: 4),
    ];
    const mat = CeilingMethod(extraSizedItems: extras);
    final ceiling = CeilingRegion(
      id: 'c1',
      points: const [Point2(0, 0), Point2(1, 0), Point2(1, 1)],
      method: mat,
      quantities: const {},
    );
    var n = 0;
    final lines =
        EstimateBuilder.fromCeiling(ceiling: ceiling, idGen: () => 'n${n++}');
    expect(lines.where((e) => e.name == 'Wバー').single.qty, 7);
    expect(lines.where((e) => e.name == '全ネジボルト').single.qty, 4);

    final round = CeilingRegion.fromJson(ceiling.toJson());
    expect(round.method.extraSizedItems.length, 2);
    expect(round.method.extraSizedItems.first.qty, 7);

    final wall = WallSegment(
      id: 'w1',
      points: const [Point2(0, 0), Point2(100, 0)],
      heightMm: 2700,
      method: const WallMethod(
        extraSizedItems: [
          ExtraSizedItem(kind: 'runner', widthMm: 65, lengthMm: 4000, qty: 5),
        ],
      ),
      quantities: const {},
    );
    final wallRound = WallSegment.fromJson(wall.toJson());
    expect(wallRound.method.extraSizedItems.single.qty, 5);
    final wallLines =
        EstimateBuilder.fromWall(wall: wallRound, idGen: () => 'w${n++}');
    expect(wallLines.where((e) => e.name == 'ランナー').single.qty, 5);
  });

  test('品名は下り・天井・壁・LGS接頭辞を除き注文書で合算する', () {
    expect(EstimateBuilder.catalogItemName('下りランナー'), 'ランナー');
    expect(EstimateBuilder.catalogItemName('天井 Wバー'), 'Wバー');
    expect(EstimateBuilder.catalogItemName('壁 コの字スタッド'), 'コの字スタッド');
    expect(EstimateBuilder.catalogItemName('LGS ランナー'), 'ランナー');
    expect(EstimateBuilder.catalogItemName('LGSランナー'), 'ランナー');
    expect(EstimateBuilder.catalogItemName('石膏ボード（天井）'), '石膏ボード');
    expect(EstimateBuilder.catalogItemName('壁紙'), '壁紙');

    var n = 0;
    final merged = EstimateBuilder.mergeForOrderDocument(
      [
        EstimateLine(
          id: 'd',
          name: '下りランナー',
          spec: '45形',
          qty: 2,
          unit: '本',
          subtotal: 2,
          areaKind: 'drop',
        ),
        EstimateLine(
          id: 'c',
          name: '天井 ランナー',
          spec: '45形',
          qty: 3,
          unit: '本',
          subtotal: 3,
          areaKind: 'ceiling',
        ),
        EstimateLine(
          id: 'w',
          name: 'LGS ランナー',
          spec: '45形',
          qty: 4,
          unit: '本',
          subtotal: 4,
          areaKind: 'wall',
        ),
      ],
      idGen: () => 'o${n++}',
    );
    expect(merged.length, 1);
    expect(merged.single.name, 'ランナー');
    expect(merged.single.qty, 9);

    n = 0;
    final dropSpec = EstimateBuilder.mergeForOrderDocument(
      [
        EstimateLine(
          id: 'a',
          name: 'ランナー',
          spec: 'L型下り・45形',
          qty: 1,
          unit: '本',
          subtotal: 1,
          areaKind: 'drop',
        ),
        EstimateLine(
          id: 'b',
          name: 'ランナー',
          spec: '下り・45形',
          qty: 2,
          unit: '本',
          subtotal: 2,
          areaKind: 'drop',
        ),
        EstimateLine(
          id: 'c',
          name: 'ランナー',
          spec: '45形',
          qty: 3,
          unit: '本',
          subtotal: 3,
          areaKind: 'wall',
        ),
      ],
      idGen: () => 's${n++}',
    );
    expect(dropSpec.length, 1);
    expect(dropSpec.single.qty, 6);
  });
}
