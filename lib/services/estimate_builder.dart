import 'dart:math' as math;

import '../models/models.dart';
import 'board_spec_parse.dart';
import 'calc_engine.dart';

/// 積算結果から試算表／注文書行を生成
class EstimateBuilder {
  EstimateBuilder._();

  static List<EstimateLine> fromWall({
    required WallSegment wall,
    required String Function() idGen,
    int lineNumber = 0,
  }) {
    final q = wall.quantities;
    final m = wall.method;
    final lines = <EstimateLine>[];
    final waste = (m.crossWasteRate * 100).clamp(0, 50).toDouble();
    final h = wall.heightMm;
    final stockH = m.studLengthMm > 0
        ? m.studLengthMm.round()
        : _nearestStock(h);
    final areaM2 = q['wall_area_m2'] ?? 0.0;
    final lineNo = lineNumber > 0 ? lineNumber : 0;
    final lineColor = wall.highlightArgb;

    void add({
      required String name,
      required String spec,
      required double qty,
      required String unit,
      String lw = '',
      double lengthMm = 0,
      double? subtotal,
      double wastePct = 5,
      String note = '',
    }) {
      if (qty <= 0) return;
      final sub = subtotal ??
          (lengthMm > 0 ? (lengthMm / 1000.0) * qty : qty);
      lines.add(EstimateLine(
        id: idGen(),
        name: name,
        spec: spec,
        lw: lw,
        lengthMm: lengthMm,
        qty: qty,
        unit: unit,
        subtotal: sub,
        wastePercent: wastePct,
        note: '',
        wallHeightMm: h,
        wallLineNumber: lineNo,
        wallLineColorArgb: lineColor,
      ));
    }

    if (q.containsKey('stud_count')) {
      final isSquare = m.studProfile == 'square';
      final w = (q['stud_width_mm'] ?? m.studWidthMm).round();
      final code = m.squareStudCode.isNotEmpty
          ? m.squareStudCode
          : (isSquare ? SquareStudSizeX.fromCode(m.lgsFormCode).code : '');
      add(
        name: isSquare ? '角スタッド' : 'コの字スタッド',
        spec: isSquare ? code : '${w}形',
        lw: stockH.toString(),
        lengthMm: stockH.toDouble(),
        qty: q['stud_count']!,
        unit: '本',
      );
    }
    // ランナー幅＞スタッド幅：端・折点のランナー幅スタッド
    final runnerStuds = q['runner_width_stud_count'];
    final isSquareProfile = m.studProfile == 'square';
    var perSpacer = (q['stud_spacer_per_stud'] ?? 0).round();
    if (perSpacer <= 0 && !isSquareProfile) {
      perSpacer = CalcEngine.studSpacerCountPerStud(stockH.toDouble());
    }
    if (runnerStuds != null && runnerStuds > 0) {
      final rw = (q['runner_width_mm'] ?? m.runnerWidthMm).round();
      add(
        name: 'コの字スタッド',
        spec: '${rw}形',
        lw: stockH.toString(),
        lengthMm: stockH.toDouble(),
        qty: runnerStuds,
        unit: '本',
        note: '端・折点（ランナー同幅）',
      );
    }
    // スペーサー：スタッド形ごとに同寸法で計上
    if (!isSquareProfile && perSpacer > 0) {
      final studQty = q['stud_count'] ?? 0;
      if (studQty > 0) {
        final w = (q['stud_width_mm'] ?? m.studWidthMm).round();
        add(
          name: 'スペーサー',
          spec: '${w}形・間隔600mm以下',
          lw: '$w',
          qty: studQty * perSpacer,
          unit: '個',
          wastePct: 3,
          note: 'スタッド1本あたり$perSpacer個',
        );
      }
      if (runnerStuds != null && runnerStuds > 0) {
        final rw = (q['runner_width_mm'] ?? m.runnerWidthMm).round();
        add(
          name: 'スペーサー',
          spec: '${rw}形・間隔600mm以下',
          lw: '$rw',
          qty: runnerStuds * perSpacer,
          unit: '個',
          wastePct: 3,
          note: 'スタッド1本あたり$perSpacer個',
        );
      }
    }
    if (q.containsKey('runner_m')) {
      final w = (q['runner_width_mm'] ?? m.runnerWidthMm).round();
      final runM = q['runner_m']!;
      final stock = m.runnerLengthMm > 0 ? m.runnerLengthMm : 4000.0;
      final pcs = (runM * 1000 / stock).ceilToDouble();
      add(
        name: 'LGS ランナー',
        spec: '${w}形 天地',
        lw: stock.toStringAsFixed(0),
        lengthMm: stock,
        qty: pcs,
        unit: '本',
        subtotal: runM,
        note: '延長 ${runM.toStringAsFixed(2)}m',
      );
    }
    final spacerQty =
        q['runner_spacer_count'] ?? q['spacer_count'];
    if (spacerQty != null && spacerQty > 0) {
      final spMm = (q['runner_spacer_mm'] ?? m.runnerSpacerMm).round();
      add(
        name: 'ランナースペーサー',
        spec: '${spMm}mm',
        qty: spacerQty,
        unit: '個',
        wastePct: 3,
        note: '細スタッド本数×2',
      );
    }
    if (q.containsKey('furedome_m')) {
      final fm = q['furedome_m']!;
      final stock = m.fureDomeLengthMm > 0 ? m.fureDomeLengthMm : 4000.0;
      final pcs = (fm * 1000 / stock).ceilToDouble();
      final fdMm = (q['furedome_width_mm'] ?? m.fureDomeWidthMm).round();
      add(
        name: '振れ止め',
        spec: 'WB-${fdMm} ${fdMm}mm',
        lw: stock.toStringAsFixed(0),
        lengthMm: stock,
        qty: pcs,
        unit: '本',
        subtotal: fm,
      );
    }

    if (q.containsKey('rock_felt_boxes') && (q['rock_felt_boxes'] ?? 0) > 0) {
      final w = (q['rock_felt_width_mm'] ?? m.rockFeltWidthMm);
      final wLabel = w == w.roundToDouble()
          ? w.toStringAsFixed(0)
          : w.toStringAsFixed(1);
      add(
        name: 'ロックフェルト',
        spec: '幅${wLabel}mm×長さ1000mm',
        lw: '1000',
        lengthMm: 1000,
        qty: q['rock_felt_boxes']!,
        unit: '箱',
        wastePct: 0,
        note: '1箱100本／延長 ${(q['rock_felt_m'] ?? 0).toStringAsFixed(1)}m',
      );
    }

    if (q.containsKey('tiger_utight_boxes') &&
        (q['tiger_utight_boxes'] ?? 0) > 0) {
      final is720 = (q['tiger_utight_type'] ?? 320) >= 700;
      add(
        name: 'タイガーUタイト',
        spec: is720
            ? '720ml15本入りジャンボタイプ'
            : '320ml30本入りスタンダードタイプ',
        qty: q['tiger_utight_boxes']!,
        unit: '箱',
        wastePct: 0,
        note: '延長 ${(q['tiger_utight_m'] ?? 0).toStringAsFixed(1)}m',
      );
    }

    if (m.useBoard) {
      String cleanKind(String kind) {
        var t = kind.trim();
        t = t.replaceAll(
          RegExp(r'\s*\d+(?:\.\d+)?\s*mm', caseSensitive: false),
          '',
        );
        t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (t.isEmpty) return '石膏ボード';
        // 「普通PB 12.5mm」などから厚さだけ残っている場合
        if (RegExp(r'^PB$', caseSensitive: false).hasMatch(t)) {
          return '石膏ボード';
        }
        return t;
      }

      void addFace({
        required String stack,
        required String kind,
        required List<BoardSize> sizes,
        required String faceNote,
      }) {
        var layers = BoardSpecParse.layers(stack);
        if (layers.isEmpty) {
          // stack が空でも useBoard なら厚みから1層作る
          final th = m.boardThicknessMm > 0 ? m.boardThicknessMm : 12.5;
          layers = [th];
        }
        final name = cleanKind(kind);
        // 厚さ×サイズごとに集計（層ごとにサイズが違う場合に対応）
        final bag = <String, (String th, String lw, double qty)>{};
        for (var i = 0; i < layers.length; i++) {
          final th = layers[i];
          final size = i < sizes.length
              ? sizes[i]
              : (sizes.isNotEmpty ? sizes.first : m.boardSize);
          final (bw, bh) = CalcEngine.boardMm(size);
          final boardAreaM2 = (bw / 1000.0) * (bh / 1000.0);
          final sheets = boardAreaM2 > 0 && areaM2 > 0
              ? (areaM2 / boardAreaM2).ceilToDouble()
              : 0.0;
          if (sheets <= 0) continue;
          final thKey = th == th.roundToDouble()
              ? th.toStringAsFixed(0)
              : th.toStringAsFixed(1);
          final key = '$thKey\u0001${size.label}';
          final cur = bag[key];
          bag[key] = (thKey, size.label, (cur?.$3 ?? 0) + sheets);
        }
        final keys = bag.keys.toList()
          ..sort((a, b) {
            final ta = double.tryParse(bag[a]!.$1) ?? 0;
            final tb = double.tryParse(bag[b]!.$1) ?? 0;
            return tb.compareTo(ta);
          });
        for (final k in keys) {
          final e = bag[k]!;
          var lineName = name.trim().isEmpty ? '石膏ボード' : name.trim();
          if (!_hasAnyKeyword(lineName, _boardKeywords)) {
            lineName =
                lineName.endsWith('ボード') ? lineName : '$lineNameボード';
          }
          add(
            name: lineName,
            spec: '${e.$1}mm',
            lw: e.$2,
            qty: e.$3,
            unit: '枚',
            wastePct: 5,
            note: faceNote,
          );
        }
      }

      final layersA = BoardSpecParse.layers(m.boardStackA);
      final layersB = BoardSpecParse.layers(m.boardStackB);
      addFace(
        stack: m.boardStackA,
        kind: m.boardKindA,
        sizes: m.resolvedLayerSizesA(
          layersA.isEmpty ? 1 : layersA.length,
        ),
        faceNote: 'A面',
      );
      if (m.bothSides) {
        addFace(
          stack: m.boardStackB,
          kind: m.boardKindB,
          sizes: m.resolvedLayerSizesB(
            layersB.isEmpty ? 1 : layersB.length,
          ),
          faceNote: 'B面',
        );
      }
    }

    if (q.containsKey('keikal_sheets')) {
      final th = (q['keikal_thickness_mm'] ?? m.keikalThicknessMm);
      final thLabel = th == th.roundToDouble()
          ? th.toStringAsFixed(0)
          : th.toStringAsFixed(1);
      add(
        name: 'ケイカル',
        spec: '${thLabel}mm',
        lw: m.keikalBoardSize.label,
        qty: q['keikal_sheets']!,
        unit: '枚',
        wastePct: 5,
        note: m.bothSides ? '両面分' : '片面',
      );
    }

    // グラスウール（発注は幅910mm換算の m）
    final gw = q['glass_wool_m2'];
    if (gw != null && gw > 0) {
      final orderM = q['glass_wool_order_m'] ?? (gw / 0.91);
      final k = (q['glass_wool_k'] ?? m.glassWoolK).round();
      add(
        name: 'グラスウール',
        spec: '${k}K・幅910mm',
        lw: '910',
        qty: double.parse(orderM.toStringAsFixed(2)),
        unit: 'm',
        subtotal: gw,
        wastePct: 5,
        note: '面積 ${gw.toStringAsFixed(2)}㎡',
      );
    } else {
      for (final extra in BoardSpecParse.namedExtras(m.lgsCoreSpec)) {
        final isGw = extra.contains('グラスウール') ||
            extra.toUpperCase().contains('GW') ||
            extra.contains('グラス');
        if (!isGw || areaM2 <= 0) continue;
        add(
          name: 'グラスウール',
          spec: extra,
          qty: double.parse((areaM2 / 0.91).toStringAsFixed(2)),
          unit: 'm',
          subtotal: areaM2,
          wastePct: 5,
          note: '面積 ${areaM2.toStringAsFixed(2)}㎡',
        );
      }
    }

    // 鉄板
    final ironSheets = q['iron_plate_sheets'];
    if (ironSheets != null && ironSheets > 0) {
      final w = (q['iron_plate_width_mm'] ?? m.ironPlateWidthMm).round();
      final len = (q['iron_plate_length_mm'] ?? m.ironPlateLengthMm).round();
      final run = q['iron_plate_run_mm'] ?? 0;
      final seg = (q['iron_plate_segments'] ?? m.ironPlateSegments).round();
      add(
        name: '鉄板',
        spec: '幅${w}×長${len}',
        lw: '$len',
        qty: ironSheets,
        unit: '枚',
        wastePct: 5,
        note: [
          if (run > 0) '延長 ${(run / 1000).toStringAsFixed(2)}m',
          if (seg >= 2) '${seg}段',
        ].join('／'),
      );
    }

    // 開口補強材
    final reinforceBars = q['reinforce_bars'];
    if (reinforceBars != null && reinforceBars > 0) {
      final w = (q['reinforce_width_mm'] ??
              (m.reinforceWidthMm > 0 ? m.reinforceWidthMm : m.studWidthMm))
          .round();
      final len = (q['reinforce_length_mm'] ??
              (m.reinforceLengthMm > 0
                  ? m.reinforceLengthMm
                  : (m.studLengthMm > 0 ? m.studLengthMm : 3000)))
          .round();
      add(
        name: '補強材',
        spec: '${w}形',
        lw: '$len',
        lengthMm: len.toDouble(),
        qty: reinforceBars,
        unit: '本',
        wastePct: 3,
        note: '開口補強',
      );
    }
    final openingRunnerM = q['opening_runner_m'];
    if (openingRunnerM != null && openingRunnerM > 0) {
      final w = m.runnerWidthMm.round();
      final stock = m.runnerLengthMm > 0 ? m.runnerLengthMm : 4000.0;
      final pcs = (openingRunnerM * 1000 / stock).ceilToDouble();
      add(
        name: '開口ランナー',
        spec: '${w}形',
        lw: stock.toStringAsFixed(0),
        lengthMm: stock,
        qty: pcs,
        unit: '本',
        subtotal: openingRunnerM,
        note: '開口補強',
      );
    }

    // ボードビスは注文書・積算に含めない
    if (q.containsKey('cross_m')) {
      add(
        name: 'クロス（壁紙）',
        spec: '幅0.9m想定',
        qty: q['cross_m']!,
        unit: 'm',
        subtotal: q['cross_m']!,
        wastePct: waste,
      );
    }
    return lines;
  }

  static List<EstimateLine> fromCeiling({
    required CeilingRegion ceiling,
    required String Function() idGen,
  }) {
    final q = ceiling.quantities;
    final m = ceiling.method;
    final lines = <EstimateLine>[];
    final areaM2 = q['ceiling_area_m2'] ?? 0.0;

    void add({
      required String name,
      required String spec,
      required double qty,
      required String unit,
      String lw = '',
      double lengthMm = 0,
      double? subtotal,
      double wastePct = 5,
    }) {
      if (qty <= 0) return;
      final sub = subtotal ??
          (lengthMm > 0 ? (lengthMm / 1000.0) * qty : qty);
      lines.add(EstimateLine(
        id: idGen(),
        name: name,
        spec: spec,
        lw: lw,
        lengthMm: lengthMm,
        qty: qty,
        unit: unit,
        subtotal: sub,
        wastePercent: wastePct,
        note: '',
        wallHeightMm: 0,
      ));
    }

    if (q.containsKey('m_bar_m')) {
      add(
        name: '天井 Mバー（野縁）',
        spec: '${m.noenSpacingMm.round()}ピッチ',
        qty: double.parse(q['m_bar_m']!.toStringAsFixed(2)),
        unit: 'm',
        subtotal: q['m_bar_m'],
      );
    }
    if (q.containsKey('cw_bar_m')) {
      add(
        name: '天井 CWバー（野縁受け）',
        spec: '${m.noenuKeSpacingMm.round()}ピッチ',
        qty: double.parse(q['cw_bar_m']!.toStringAsFixed(2)),
        unit: 'm',
        subtotal: q['cw_bar_m'],
      );
    }
    if (q.containsKey('hanger_count')) {
      add(
        name: '吊りボルト',
        spec: '約900mm格子',
        qty: q['hanger_count']!,
        unit: '本',
        wastePct: 3,
      );
    }
    if (q.containsKey('board_sheets')) {
      final layers = (q['board_layers'] ?? m.layers.count).round();
      add(
        name: '石膏ボード（天井）',
        spec: '${m.boardSize.label}・${layers}層',
        qty: q['board_sheets']!,
        unit: '枚',
      );
    }
    if (areaM2 > 0) {
      add(
        name: '天井面積',
        spec: '',
        qty: double.parse(areaM2.toStringAsFixed(2)),
        unit: 'm²',
        subtotal: areaM2,
        wastePct: 0,
      );
    }
    return lines;
  }

  /// 測定内の壁・天井から試算行を生成し、名称＋寸法で合算する
  /// [onlyEstimateReady] が true のとき、積算確定済みの壁のみ（天井は積算済みをすべて）
  static List<EstimateLine> fromMeasurement({
    required Measurement measurement,
    required String Function() idGen,
    bool onlyEstimateReady = true,
    bool includeCeilings = true,
  }) {
    final lines = <EstimateLine>[];
    for (var i = 0; i < measurement.walls.length; i++) {
      final w = measurement.walls[i];
      if (onlyEstimateReady && !w.estimateReady) continue;
      lines.addAll(
        fromWall(wall: w, idGen: idGen, lineNumber: i + 1),
      );
    }
    if (includeCeilings) {
      for (final c in measurement.ceilings) {
        lines.addAll(fromCeiling(ceiling: c, idGen: idGen));
      }
    }
    return mergeByNameAndSize(lines, idGen: idGen);
  }

  /// 壁マウス／天井マウスに応じた表示ラベル
  static String areaLabelFor({
    required bool hasWalls,
    required bool hasCeilings,
  }) {
    if (hasWalls && hasCeilings) return '壁/天井';
    if (hasCeilings) return '天井';
    return '壁';
  }

  /// LGS 平米（壁・天井の下地面積）とボード平米（層数×面を乗算）
  /// ＋ロックフェルト延長・グラスウール面積
  static ({
    double lgsM2,
    double boardM2,
    double rockFeltM,
    double glassWoolM2,
  }) areasFromMeasurement(
    Measurement measurement, {
    bool onlyEstimateReady = true,
  }) {
    var lgs = 0.0;
    var board = 0.0;
    var rockFelt = 0.0;
    var gw = 0.0;
    for (final w in measurement.walls) {
      if (onlyEstimateReady && !w.estimateReady) continue;
      // 鉄板のみ線（LGSオフ）は LGS／ボード平米に加算しない
      if (!w.method.useLgs) continue;
      final a = w.quantities['wall_area_m2'] ?? 0.0;
      if (a > 0) {
        lgs += a;
        if (w.method.useBoard) {
          final layersA = BoardSpecParse.layers(w.method.boardStackA);
          final nA = layersA.isEmpty
              ? math.max(1, w.method.layers.count)
              : layersA.length;
          board += a * nA;
          if (w.method.bothSides) {
            final layersB = BoardSpecParse.layers(w.method.boardStackB);
            final nB = layersB.isEmpty ? nA : layersB.length;
            board += a * nB;
          }
        }
      }
      rockFelt += w.quantities['rock_felt_m'] ?? 0.0;
      gw += w.quantities['glass_wool_m2'] ?? 0.0;
    }
    for (final c in measurement.ceilings) {
      final a = c.quantities['ceiling_area_m2'] ?? 0.0;
      if (a <= 0) continue;
      lgs += a;
      final n = math.max(1, c.method.layers.count);
      board += a * n;
    }
    return (
      lgsM2: lgs,
      boardM2: board,
      rockFeltM: rockFelt,
      glassWoolM2: gw,
    );
  }

  /// LGS のみ表示キーワード
  static const _lgsKeywords = [
    'ランナースペーサー',
    'チャンネルバ',
    '吊りボルト',
    '野縁受け',
    'ランナー',
    'スタッド',
    '振れ止め',
    'スペーサー',
    'ボルト',
    '全ネジ',
    'チャンネル',
    'シングル',
    'ダブル',
    'クリップ',
    'ナット',
    'ハンガー',
    'Cバー',
    'Cチャン',
    '野縁',
    'Mバー',
    'ジョイント',
    'Gブレス',
    '鐵板',
    '鉄板',
    '補強材',
    'バー',
    'コの字',
  ];

  /// ボードのみ表示キーワード（先に判定する）
  static const _boardKeywords = [
    'サウンドカット',
    'サクビボンド',
    'トラボンド',
    'GLボンド',
    'シリコーン系',
    '両面テープ',
    'ロックフェルト',
    'ロックウール',
    'グラスウール',
    'ジプトーン',
    'ソーラトン',
    'ハイパー',
    'スーパー',
    'タイガー',
    'コンパネ',
    'メラミン',
    'セラール',
    'ケイカル',
    '接着剤',
    'ボード',
    '強化',
    '石膏',
    '不燃',
    '吸音',
    '耐水',
    'キューブ',
    '化粧',
    'ベニヤ',
    'パネル',
    '岩綿',
    '速乾',
    'フェルト',
    'ボンド',
    'のり',
    'GB',
    'Z',
  ];

  static bool _containsKeyword(String text, String key) {
    if (key == 'Z') {
      return RegExp(r'(^|[^A-Za-z])Z([^A-Za-z]|$)', caseSensitive: false)
          .hasMatch(text);
    }
    if (key == 'GB') {
      return RegExp(r'(^|[^A-Za-z])GB([^A-Za-z]|$)', caseSensitive: false)
          .hasMatch(text);
    }
    return text.contains(key);
  }

  static bool _nameHas(String name, List<String> keys) {
    for (final k in keys) {
      if (_containsKeyword(name, k)) return true;
    }
    return false;
  }

  /// ボードキーワード優先。鉄板など LGS キーワードは単位「枚」より先に判定
  static EstimateSheetKind classifyKind(EstimateLine line) {
    final n = line.name.trim();

    // 1) ボード（名称キーワード）
    if (_nameHas(n, _boardKeywords)) return EstimateSheetKind.board;
    if (n.contains('クロス') || n.contains('壁紙') || n.contains('面積')) {
      return EstimateSheetKind.board;
    }

    // 2) LGS（鉄板は単位が「枚」でもこちら）
    if (_nameHas(n, _lgsKeywords)) return EstimateSheetKind.lgs;
    if (line.unit == '本' || line.unit == '個') return EstimateSheetKind.lgs;

    // 3) 石膏ボードなど単位「枚」、箱・m はボード寄り
    if (line.unit == '枚') return EstimateSheetKind.board;
    return EstimateSheetKind.board;
  }

  static bool isLgsLine(EstimateLine line) =>
      classifyKind(line) == EstimateSheetKind.lgs;

  static bool isBoardLine(EstimateLine line) =>
      classifyKind(line) == EstimateSheetKind.board;

  static bool _hasAnyKeyword(String text, List<String> keys) =>
      _nameHas(text, keys);

  static List<EstimateLine> filterByKind(
    List<EstimateLine> lines,
    EstimateSheetKind kind,
  ) {
    final out = <EstimateLine>[];
    for (final e in lines) {
      final k = classifyKind(e);
      if (k != kind) continue;
      out.add(
        EstimateLine(
          id: e.id,
          name: e.name,
          spec: e.spec,
          lw: e.lw,
          lengthMm: e.lengthMm,
          qty: e.qty,
          unit: e.unit,
          subtotal: e.subtotal,
          wastePercent: e.wastePercent,
          note: e.note,
          wallHeightMm: e.wallHeightMm,
          wallLineNumber: e.wallLineNumber,
          wallLineColorArgb: e.wallLineColorArgb,
        ),
      );
    }
    return out;
  }

  /// 同じ名称・同じ寸法・同じ壁高さ・同じ線番号の数量・小計を合算
  static List<EstimateLine> mergeByNameAndSize(
    List<EstimateLine> lines, {
    required String Function() idGen,
  }) {
    final map = <String, EstimateLine>{};
    final order = <String>[];
    for (final line in lines) {
      final hKey = line.wallHeightMm > 0
          ? line.wallHeightMm.toStringAsFixed(0)
          : '';
      final key =
          '${line.name}\u0001${line.spec}\u0001${line.lw}\u0001${line.unit}\u0001$hKey\u0001${line.wallLineNumber}';
      final existing = map[key];
      if (existing == null) {
        map[key] = EstimateLine(
          id: idGen(),
          name: line.name,
          spec: line.spec,
          lw: line.lw,
          lengthMm: line.lengthMm,
          qty: line.qty,
          unit: line.unit,
          subtotal: line.subtotal,
          wastePercent: line.wastePercent,
          note: line.note,
          wallHeightMm: line.wallHeightMm,
          wallLineNumber: line.wallLineNumber,
          wallLineColorArgb: line.wallLineColorArgb,
        );
        order.add(key);
      } else {
        existing.qty += line.qty;
        existing.subtotal += line.subtotal;
        if (existing.wastePercent < line.wastePercent) {
          existing.wastePercent = line.wastePercent;
        }
        if (line.note.isNotEmpty &&
            existing.note.isNotEmpty &&
            !existing.note.contains(line.note)) {
          existing.note = '${existing.note} / ${line.note}';
        } else if (existing.note.isEmpty && line.note.isNotEmpty) {
          existing.note = line.note;
        }
      }
    }
    final result = order.map((k) => map[k]!).toList();
    result.sort((a, b) {
      final ln = a.wallLineNumber.compareTo(b.wallLineNumber);
      if (ln != 0) return ln;
      final h = a.wallHeightMm.compareTo(b.wallHeightMm);
      if (h != 0) return h;
      final n = a.name.compareTo(b.name);
      if (n != 0) return n;
      final l = a.lw.compareTo(b.lw);
      if (l != 0) return l;
      return a.spec.compareTo(b.spec);
    });
    return result;
  }

  /// 注文書用：品名・サイズ・仕様が同一なら1行にまとめ、合計を加算
  static List<EstimateLine> mergeForOrderDocument(
    List<EstimateLine> lines, {
    required String Function() idGen,
  }) {
    String sizeOf(EstimateLine e) {
      if (e.lw.trim().isNotEmpty) return e.lw.trim();
      if (e.lengthMm > 0) {
        return e.lengthMm == e.lengthMm.roundToDouble()
            ? e.lengthMm.toStringAsFixed(0)
            : e.lengthMm.toStringAsFixed(1);
      }
      return '';
    }

    int totalOf(EstimateLine e) {
      final v = e.qty * (1 + e.wastePercent / 100.0);
      if (v <= 0) return 0;
      return v.ceil();
    }

    final map = <String, EstimateLine>{};
    final order = <String>[];
    final totals = <String, int>{};

    for (final line in lines) {
      final size = sizeOf(line);
      final key = '${line.name.trim()}\u0001$size\u0001${line.spec.trim()}';
      final t = totalOf(line);
      final existing = map[key];
      if (existing == null) {
        map[key] = EstimateLine(
          id: idGen(),
          name: line.name.trim(),
          spec: line.spec.trim(),
          lw: size,
          lengthMm: line.lengthMm,
          qty: line.qty,
          unit: line.unit,
          subtotal: line.subtotal,
          wastePercent: 0,
          note: line.note,
        );
        totals[key] = t;
        order.add(key);
      } else {
        existing.qty += line.qty;
        existing.subtotal += line.subtotal;
        totals[key] = (totals[key] ?? 0) + t;
        if (line.note.isNotEmpty &&
            existing.note.isNotEmpty &&
            !existing.note.contains(line.note)) {
          existing.note = '${existing.note} / ${line.note}';
        } else if (existing.note.isEmpty && line.note.isNotEmpty) {
          existing.note = line.note;
        }
        if (existing.unit.isEmpty && line.unit.isNotEmpty) {
          existing.unit = line.unit;
        }
      }
    }

    return order.map((k) {
      final e = map[k]!;
      // ロス込み合計を qty に焼き込み（注文書にロス率欄なし）
      final baked = (totals[k] ?? 0).toDouble();
      e.qty = baked;
      e.subtotal = baked;
      e.wastePercent = 0;
      return e;
    }).toList();
  }

  static int _nearestStock(double heightMm) {
    const stocks = [
      1000, 2000, 2500, 2700, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 8000,
      10000, 12000, 15000,
    ];
    var best = stocks.first;
    var bestDiff = (heightMm - best).abs();
    for (final s in stocks) {
      if (s < heightMm) continue;
      final d = s - heightMm;
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    if (best < heightMm) best = stocks.last;
    return best.clamp(1000, 15000);
  }
}
