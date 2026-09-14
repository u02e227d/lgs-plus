import 'dart:math' as math;

import '../models/models.dart';
import 'board_spec_parse.dart';
import 'calc_engine.dart';
import 'cross_dedicated_calc.dart';
import 'opening_reinforce.dart';

/// 積算結果から試算表／注文書行を生成
class EstimateBuilder {
  EstimateBuilder._();

  static void _addExtraSized(
    void Function({
      required String name,
      required String spec,
      required double qty,
      required String unit,
      String lw,
      double lengthMm,
    }) add,
    List<ExtraSizedItem> extras, {
    required bool ceiling,
    String? kind,
    Set<String> skipKinds = const {},
  }) {
    for (final extra in extras) {
      if (extra.qty <= 0 || extra.kind.isEmpty) continue;
      if (kind != null && extra.kind != kind) continue;
      if (skipKinds.contains(extra.kind)) continue;
      add(
        name: extra.estimateName(ceiling: ceiling),
        spec: extra.estimateSpec(ceiling: ceiling),
        qty: extra.qty,
        unit: extra.unit,
        lw: extra.estimateLw(),
        lengthMm: extra.lengthMm,
      );
    }
  }

  static List<EstimateLine> fromWall({
    required WallSegment wall,
    required String Function() idGen,
    int lineNumber = 0,
    List<WallOpening> openings = const [],
  }) {
    final m = wall.method;
    // 開口がある場合は補強材本数・正味面積を現行ルールで再計算
    final q = Map<String, double>.from(wall.quantities);
    final lengthMm = q['wall_length_mm'] ?? 0.0;
    final heightMm = q['wall_height_mm'] ?? wall.heightMm;
    if (lengthMm > 0 && heightMm > 0) {
      final gross = (lengthMm / 1000.0) * (heightMm / 1000.0);
      var openingArea = 0.0;
      for (final o in openings) {
        if (o.widthMm > 0 && o.heightMm > 0) openingArea += o.areaM2;
      }
      final net = (gross - openingArea).clamp(0.0, double.infinity);
      q['wall_gross_area_m2'] = gross;
      q['opening_area_m2'] = openingArea;
      q['wall_net_area_m2'] = net;
      if (m.useLgs) q['wall_area_m2'] = net;
    }
    if (openings.isNotEmpty) {
      final stock = m.reinforceLengthMm > 0
          ? m.reinforceLengthMm
          : (m.studLengthMm > 0 ? m.studLengthMm : wall.heightMm);
      final reinforceList = [
        for (final o in openings)
          if (o.material == OpeningMaterialKind.reinforce) o,
      ];
      final reinforceBars = OpeningReinforceCalc.reinforceBarsForOpenings(
        openings: reinforceList,
        stockLengthMm: stock,
      );
      var openingRunnerMm = 0.0;
      for (final o in openings) {
        final pattern = OpeningReinforcePatternX.parse(o.patternName);
        if (o.material != OpeningMaterialKind.reinforce) {
          openingRunnerMm += OpeningReinforceCalc.runnerMm(
            pattern: pattern,
            magusaSegments: o.magusaSegments,
            openingWidthMm: o.widthMm,
            openingHeightMm: o.heightMm,
          );
        }
      }
      if (reinforceBars > 0) {
        q['reinforce_bars'] = reinforceBars.toDouble();
        q['reinforce_width_mm'] = m.reinforceWidthMm > 0
            ? m.reinforceWidthMm
            : m.studWidthMm;
        q['reinforce_length_mm'] = stock;
      } else {
        q.remove('reinforce_bars');
      }
      if (openingRunnerMm > 0) {
        q['opening_runner_mm'] = openingRunnerMm;
        q['opening_runner_m'] = openingRunnerMm / 1000.0;
      }
      if (m.useAnglePiece) {
        var anglePcs = 0;
        for (final o in openings) {
          final pattern = OpeningReinforcePatternX.parse(o.patternName);
          anglePcs += OpeningReinforceCalc.anglePieces(
            pattern: pattern,
            magusaSegments: o.magusaSegments,
          );
        }
        if (anglePcs > 0) {
          q['angle_piece_count'] = anglePcs.toDouble();
          q['angle_piece_mm'] =
              m.anglePieceMm > 0 ? m.anglePieceMm : 50;
        } else {
          q.remove('angle_piece_count');
        }
      }
    }
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
        name: catalogItemName(name),
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
        areaKind: 'wall',
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
    _addExtraSized(add, m.extraSizedItems, kind: 'stud', ceiling: false);
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
        name: 'ランナー',
        spec: '${w}形 天地',
        lw: stock.toStringAsFixed(0),
        lengthMm: stock,
        qty: pcs,
        unit: '本',
        subtotal: runM,
        note: '延長 ${runM.toStringAsFixed(2)}m',
      );
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'runner', ceiling: false);
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
    _addExtraSized(add, m.extraSizedItems, kind: 'fure_dome', ceiling: false);

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
        // 枚数を合算してから箱／坪に換算（切上げ）
        final bag = <String, (String th, String lw, double qty, double w, double h)>{};
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
          bag[key] = (
            thKey,
            size.label,
            (cur?.$3 ?? 0) + sheets,
            bw,
            bh,
          );
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
          final packed = packBoardSheets(
            e.$3,
            widthMm: e.$4,
            heightMm: e.$5,
            thicknessMm: double.tryParse(e.$1) ?? 0,
            lw: e.$2,
          );
          add(
            name: lineName,
            spec: '${e.$1}mm',
            lw: e.$2,
            qty: packed.qty,
            unit: packed.unit,
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
      final (kw, kh) = CalcEngine.boardMm(m.keikalBoardSize);
      final packed = packBoardSheets(
        q['keikal_sheets']!,
        widthMm: kw,
        heightMm: kh,
        thicknessMm: th,
        lw: m.keikalBoardSize.label,
      );
      add(
        name: 'ケイカル',
        spec: '${thLabel}mm',
        lw: m.keikalBoardSize.label,
        qty: packed.qty,
        unit: packed.unit,
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
      final seg = (q['iron_plate_segments'] ?? m.ironPlateSegmentCount).round();
      add(
        name: '鉄板',
        spec: '幅${w}×長${len}',
        lw: '$len',
        qty: ironSheets,
        unit: '枚',
        wastePct: 5,
        note: [
          if (run > 0) '延長 ${(run / 1000).toStringAsFixed(2)}m',
          if (seg >= 1) '${seg}段',
        ].join('／'),
      );
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'iron', ceiling: false);

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
        wastePct: 0,
        note: '開口補強（横は合計長さ÷定尺で割付）',
      );
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'reinforce', ceiling: false);
    final anglePcs = q['angle_piece_count'];
    if (anglePcs != null && anglePcs > 0) {
      final mm = (q['angle_piece_mm'] ?? m.anglePieceMm).round();
      add(
        name: 'アングルピース',
        spec: '${mm}mm',
        qty: anglePcs,
        unit: '個',
        wastePct: 0,
        note: '開口図形の線本数×2',
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

    // ボードビス・クロスは自動計上しない（その他／クロス専用で入力）

    for (final item in m.otherItemsBeforeGlassWool) {
      if (item.quantity <= 0) continue;
      final name = item.name.trim().isEmpty ? 'その他' : item.name.trim();
      final unit = item.unit.trim().isEmpty ? '式' : item.unit.trim();
      add(
        name: name,
        spec: 'その他',
        qty: item.quantity,
        unit: unit,
        wastePct: 0,
      );
    }
    for (final item in m.otherItemsAfterUtight) {
      if (item.quantity <= 0) continue;
      final name = item.name.trim().isEmpty ? 'その他（ボード）' : item.name.trim();
      final unit = item.unit.trim().isEmpty ? '式' : item.unit.trim();
      add(
        name: name,
        spec: 'ボード関連',
        qty: item.quantity,
        unit: unit,
        wastePct: 0,
      );
    }
    _addExtraSized(
      add,
      m.extraSizedItems,
      ceiling: false,
      skipKinds: const {
        'stud',
        'runner',
        'fure_dome',
        'iron',
        'reinforce',
      },
    );
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
        name: catalogItemName(name),
        spec: spec,
        lw: lw,
        lengthMm: lengthMm,
        qty: qty,
        unit: unit,
        subtotal: sub,
        wastePercent: wastePct,
        note: '',
        wallHeightMm: 0,
        wallLineNumber: ceiling.groupNumber,
        areaKind: 'ceiling',
      ));
    }

    if ((q['w_bar_m'] ?? 0) > 0) {
      final wCount = q['w_bar_count'] ?? 0;
      if (wCount > 0) {
        add(
          name: 'Wバー',
          spec: '高${m.wBarHeightMm.round()}mm',
          qty: wCount,
          unit: '本',
          lengthMm: m.wBarLengthMm,
          lw: '${m.wBarLengthMm.round()}',
        );
      } else {
        add(
          name: 'Wバー（野縁）',
          spec: '${m.systemKind.label}・${m.panelSpec.label}',
          qty: double.parse(q['w_bar_m']!.toStringAsFixed(2)),
          unit: 'm',
          subtotal: q['w_bar_m'],
        );
      }
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'w_bar', ceiling: true);
    if ((q['single_bar_m'] ?? 0) > 0) {
      final sCount = q['single_bar_count'] ?? 0;
      if (sCount > 0) {
        add(
          name: 'シングルバー',
          spec: '高${m.singleBarHeightMm.round()}mm',
          qty: sCount,
          unit: '本',
          lengthMm: m.singleBarLengthMm,
          lw: '${m.singleBarLengthMm.round()}',
        );
      } else if (q.containsKey('m_bar_m') && (q['m_bar_m'] ?? 0) > 0) {
        add(
          name: 'Mバー（野縁）',
          spec: '${m.noenSpacingMm.round()}ピッチ',
          qty: double.parse(q['m_bar_m']!.toStringAsFixed(2)),
          unit: 'm',
          subtotal: q['m_bar_m'],
        );
      } else {
        add(
          name: 'シングルバー（野縁）',
          spec: m.panelSpec == CeilingPanelSpec.panel3x6
              ? '${m.noenSpacingMm.round()}ピッチ'
              : m.panelSpec.label,
          qty: double.parse(q['single_bar_m']!.toStringAsFixed(2)),
          unit: 'm',
          subtotal: q['single_bar_m'],
        );
      }
    } else if (q.containsKey('m_bar_m') && (q['m_bar_m'] ?? 0) > 0) {
      add(
        name: 'Mバー（野縁）',
        spec: '${m.noenSpacingMm.round()}ピッチ',
        qty: double.parse(q['m_bar_m']!.toStringAsFixed(2)),
        unit: 'm',
        subtotal: q['m_bar_m'],
      );
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'single_bar', ceiling: true);
    if ((q['square_stud_m'] ?? 0) > 0 || (q['sq_stud_count'] ?? 0) > 0) {
      final sqCount = q['sq_stud_count'] ?? 0;
      if (sqCount > 0) {
        add(
          name: 'SQ角スタッド',
          spec: m.sqStudType,
          qty: sqCount,
          unit: '本',
          lengthMm: m.sqStudLengthMm,
          lw: '${m.sqStudLengthMm.round()}',
        );
      } else {
        add(
          name: '角スタッド',
          spec: 'SQ・${m.sqStudType}',
          qty: double.parse(q['square_stud_m']!.toStringAsFixed(2)),
          unit: 'm',
          subtotal: q['square_stud_m'],
        );
      }
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'sq_stud', ceiling: true);
    final clipCount = q['clip_count'] ?? 0;
    if (clipCount > 0) {
      add(
        name: '角スタクリップ',
        spec: '${m.clipUkeLabel}・タイプ${m.clipType}',
        qty: clipCount,
        unit: '個',
        wastePct: 3,
      );
    }
    final runnerCount = q['runner_count'] ?? 0;
    if (runnerCount > 0) {
      add(
        name: 'ランナー',
        spec: '幅${m.runnerWidthMm.round()}mm',
        qty: runnerCount,
        unit: '本',
        lengthMm: m.runnerLengthMm,
        lw: '${m.runnerLengthMm.round()}',
      );
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'runner', ceiling: true);
    if ((q['uke_bar_m'] ?? q['cw_bar_m'] ?? 0) > 0) {
      final uke = q['uke_bar_m'] ?? q['cw_bar_m']!;
      final chCount = q['uke_channel_count'] ?? 0;
      final chW = (q['uke_channel_width_mm'] ?? m.ukeChannelWidthMm).round();
      final chL = (q['uke_channel_length_mm'] ?? m.ukeChannelLengthMm).round();
      if (chCount > 0) {
        add(
          name: '野縁受け（チャンネル）',
          spec: '幅${chW}mm × ${chL}mm',
          qty: chCount,
          unit: '本',
          lengthMm: chL.toDouble(),
          lw: '$chL',
        );
      } else {
        add(
          name: '野縁受け',
          spec: m.systemKind == CeilingSystemKind.sq
              ? '角スタッド>2200補強・十字1本'
              : '全ネジ格子≤900',
          qty: double.parse(uke.toStringAsFixed(2)),
          unit: 'm',
          subtotal: uke,
        );
      }
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'channel', ceiling: true);
    final channelJoints = q['channel_joint_count'] ?? 0;
    if (channelJoints > 0) {
      add(
        name: 'チャンネルジョイント',
        spec: '幅${m.channelJointWidthMm.round()}mm',
        qty: channelJoints,
        unit: '個',
        wastePct: 3,
      );
    }
    final wClips = q['w_clip_count'] ?? 0;
    if (wClips > 0) {
      add(
        name: 'Wクリップ',
        spec: '野縁受け幅${m.wClipUkeWidthMm.round()}mm',
        qty: wClips,
        unit: '個',
        wastePct: 3,
      );
    }
    final sClips = q['single_clip_count'] ?? 0;
    if (sClips > 0) {
      add(
        name: 'シングルクリップ',
        spec: '野縁受け幅${m.singleClipUkeWidthMm.round()}mm',
        qty: sClips,
        unit: '個',
        wastePct: 3,
      );
    }
    final wJoints = q['w_bar_joint_count'] ?? 0;
    if (wJoints > 0) {
      add(
        name: 'Wバージョイント',
        spec: '高${m.wBarJointHeightMm.round()}mm',
        qty: wJoints,
        unit: '個',
        wastePct: 3,
      );
    }
    final sJoints = q['single_bar_joint_count'] ?? 0;
    if (sJoints > 0) {
      add(
        name: 'シングルバージョイント',
        spec: '高${m.singleBarJointHeightMm.round()}mm',
        qty: sJoints,
        unit: '個',
        wastePct: 3,
      );
    }
    final boltCount = q['bolt_count'] ?? q['hanger_count'] ?? 0;
    if (boltCount > 0) {
      add(
        name: '全ネジボルト',
        spec: '${m.boltWidthLabel} × ${m.boltLengthMm.round()}mm',
        qty: boltCount,
        unit: '本',
        lengthMm: m.boltLengthMm,
        lw: '${m.boltLengthMm.round()}',
        wastePct: 3,
      );
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'bolt', ceiling: true);
    final nutCount = q['nut_count'] ?? (boltCount * 2);
    if (nutCount > 0) {
      add(
        name: 'ナット',
        spec: m.boltWidthLabel,
        qty: nutCount,
        unit: '個',
        wastePct: 3,
      );
    }
    final hangerPieces = q['hanger_piece_count'] ?? boltCount;
    if (hangerPieces > 0) {
      add(
        name: 'ハンガー',
        spec: '${m.hangerBoltWidthLabel}・'
            '野縁受け${m.hangerUkeWidthMm.round()}mm・'
            '金具高${m.hangerFixtureHeightMm.round()}mm',
        qty: hangerPieces,
        unit: '個',
        wastePct: 3,
      );
    }

    _addExtraSized(
      add,
      m.extraSizedItems,
      ceiling: true,
      skipKinds: const {
        'w_bar',
        'single_bar',
        'channel',
        'runner',
        'sq_stud',
        'bolt',
        'mikiri',
      },
    );

    // —— 材料設定その他 ——
    for (final item in m.otherItems) {
      if (item.name.trim().isEmpty && item.quantity <= 0) continue;
      final name = item.name.trim().isEmpty ? 'その他' : item.name.trim();
      final unit = item.unit.trim().isEmpty ? '式' : item.unit.trim();
      if (item.quantity <= 0) continue;
      add(
        name: name,
        spec: 'その他',
        qty: item.quantity,
        unit: unit,
        wastePct: 0,
      );
    }

    // —— 仕上げボード各層 ——
    if (m.finishBoardLayers.isNotEmpty && areaM2 > 0) {
      for (var i = 0; i < m.finishBoardLayers.length; i++) {
        final layer = m.finishBoardLayers[i];
        final boardArea =
            (layer.widthMm / 1000.0) * (layer.heightMm / 1000.0);
        if (boardArea <= 0) continue;
        final sheets = (areaM2 / boardArea).ceilToDouble();
        final packed = packBoardSheets(
          sheets,
          widthMm: layer.widthMm,
          heightMm: layer.heightMm,
          thicknessMm: layer.thicknessMm,
        );
        final name = layer.name.trim().isEmpty
            ? 'ボード（第${i + 1}層）'
            : layer.name.trim();
        final th = layer.thicknessMm == layer.thicknessMm.roundToDouble()
            ? '${layer.thicknessMm.round()}mm'
            : '${layer.thicknessMm}mm';
        final lw = boardSizeLabel(layer.widthMm, layer.heightMm);
        add(
          name: name,
          spec: '第${i + 1}層・$th',
          qty: packed.qty,
          unit: packed.unit,
          lw: lw,
        );
      }
    } else if (q.containsKey('board_sheets')) {
      final layers = (q['board_layers'] ?? m.layers.count).round();
      // 施工仕様から寸法を推定（1.5×3＝455×910）
      final (pw, ph) = switch (m.panelSpec) {
        CeilingPanelSpec.panel15x3 => (455.0, 910.0),
        CeilingPanelSpec.panel3x3 => (910.0, 910.0),
        CeilingPanelSpec.panel3x6 => (910.0, 1820.0),
      };
      final packed = packBoardSheets(
        q['board_sheets']!,
        widthMm: pw,
        heightMm: ph,
        thicknessMm: m.finishBoardThicknessMm,
        lw: boardSizeLabel(pw, ph),
      );
      add(
        name: '石膏ボード',
        spec: '${m.panelSpec.label}・${layers}層',
        qty: packed.qty,
        unit: packed.unit,
        lw: boardSizeLabel(pw, ph),
      );
    }

    // —— 見切り ——
    if (m.mikiriEnabled) {
      final peri = q['perimeter_mm'] ?? 0.0;
      final len = m.mikiriLengthMm > 0 ? m.mikiriLengthMm : 2000.0;
      final count = peri > 0 && len > 0 ? (peri / len).ceilToDouble() : 0.0;
      if (count > 0) {
        final name =
            m.mikiriName.trim().isEmpty ? '見切り' : m.mikiriName.trim();
        add(
          name: name,
          spec: '見切り・定尺${len.round()}mm',
          qty: count,
          unit: '本',
          lengthMm: len,
          lw: '${len.round()}',
          wastePct: 5,
        );
      }
    }
    _addExtraSized(add, m.extraSizedItems, kind: 'mikiri', ceiling: true);

    // —— その他（ボード） ——
    for (final item in m.boardOtherItems) {
      if (item.name.trim().isEmpty && item.quantity <= 0) continue;
      if (item.quantity <= 0) continue;
      final name =
          item.name.trim().isEmpty ? 'その他（ボード）' : item.name.trim();
      final unit = item.unit.trim().isEmpty ? '式' : item.unit.trim();
      add(
        name: name,
        spec: 'ボード関連',
        qty: item.quantity,
        unit: unit,
        wastePct: 0,
      );
    }

    return lines;
  }

  /// クロス専用試算表の行を生成
  static List<EstimateLine> fromCrossDedicated({
    required CrossDedicatedConfig config,
    required double areaM2,
    required String Function() idGen,
  }) {
    final lines = <EstimateLine>[];
    if (!config.enabled || areaM2 <= 0) return lines;

    void add({
      required String name,
      required String spec,
      required double qty,
      required String unit,
      double? subtotal,
      double wastePct = 0,
      String note = '',
    }) {
      if (qty <= 0) return;
      lines.add(EstimateLine(
        id: idGen(),
        name: catalogItemName(name),
        spec: spec,
        qty: qty,
        unit: unit,
        subtotal: subtotal ?? qty,
        wastePercent: wastePct,
        note: note,
        areaKind: 'cross',
      ));
    }

    final width = config.crossWidthM > 0 ? config.crossWidthM : 0.9;
    final crossM = areaM2 / width;
    final crossName =
        config.crossName.trim().isEmpty ? 'クロス（壁紙）' : config.crossName.trim();
    final crossUnit =
        config.crossUnit.trim().isEmpty ? 'm' : config.crossUnit.trim();
    add(
      name: crossName,
      spec: '幅${width.toStringAsFixed(2)}m',
      qty: double.parse(crossM.toStringAsFixed(2)),
      unit: crossUnit,
      subtotal: crossM,
      note: 'cross',
    );
    final pasteKg = crossM / 10.0;
    if (pasteKg > 0) {
      final pasteName = config.pasteName.trim().isEmpty
          ? 'クロス糊'
          : config.pasteName.trim();
      add(
        name: pasteName,
        spec: '10m=1kg',
        qty: double.parse(pasteKg.toStringAsFixed(2)),
        unit: 'kg',
        note: 'cross',
      );
    }
    if (config.pateName.trim().isNotEmpty) {
      final pate = CrossDedicatedCalc.pateQty(config.pateName, areaM2);
      if (pate.packs > 0) {
        add(
          name: config.pateName.trim(),
          spec: '${pate.packKg.toStringAsFixed(0)}kg／'
              '約${pate.coverageM2.toStringAsFixed(0)}㎡',
          qty: pate.packs,
          unit: pate.packUnit,
          note: 'cross',
        );
      }
    }
    final tapeLen = config.fiberTapeLengthM;
    final tapeQty =
        CrossDedicatedCalc.fiberTapeCount(areaM2, tapeLen);
    if (tapeQty > 0 &&
        (config.fiberTapeName.trim().isNotEmpty || tapeLen > 0)) {
      final tapeName = config.fiberTapeName.trim().isEmpty
          ? 'ファイバーテープ'
          : config.fiberTapeName.trim();
      add(
        name: tapeName,
        spec: '定尺${tapeLen == tapeLen.roundToDouble() ? tapeLen.round() : tapeLen}m',
        qty: tapeQty,
        unit: '個',
        note: 'cross',
      );
    }
    return lines;
  }

  /// 下り専用試算表の行を生成
  static List<EstimateLine> fromDrop({
    required DropRegion drop,
    required String Function() idGen,
  }) {
    final q = drop.quantities;
    final m = drop.method;
    final lines = <EstimateLine>[];
    final shape = m.shape.label;

    void add({
      required String name,
      required String spec,
      required double qty,
      required String unit,
      String lw = '',
      double lengthMm = 0,
    }) {
      if (qty <= 0) return;
      lines.add(EstimateLine(
        id: idGen(),
        name: catalogItemName(name),
        spec: spec,
        lw: lw,
        lengthMm: lengthMm,
        qty: qty,
        unit: unit,
        subtotal: qty,
        wastePercent: 0,
        note: 'drop|$shape',
        wallLineNumber: drop.groupNumber,
        wallLineColorArgb: drop.highlightArgb,
        areaKind: 'drop',
      ));
    }

    if (m.system == CeilingSystemKind.sq) {
      final runN = q['runner_count'] ?? 0;
      if (runN > 0) {
        final stock = q['runner_length_mm'] ?? m.runnerLengthMm;
        add(
          name: 'ランナー',
          spec: '${shape}・${m.runnerWidthMm.round()}形',
          qty: runN,
          unit: '本',
          lengthMm: stock,
          lw: stock.round().toString(),
        );
      }
      final studN = q['stud_count'] ?? 0;
      if (studN > 0) {
        final stock = q['stud_length_mm'] ?? m.studLengthMm;
        add(
          name: 'スタッド',
          spec: '${shape}・${m.studType} @${m.pitchMm.round()}',
          qty: studN,
          unit: '本',
          lengthMm: stock,
          lw: stock.round().toString(),
        );
      }
    } else {
      final runN = q['runner_count'] ?? 0;
      if (runN > 0) {
        final stock = q['runner_length_mm'] ?? m.runnerLengthMm;
        add(
          name: 'ランナー',
          spec: '${shape}・幅${m.runnerHeightMm.round()}mm',
          qty: runN,
          unit: '本',
          lengthMm: stock,
          lw: stock.round().toString(),
        );
      }
      final wN = q['w_bar_count'] ?? 0;
      if (wN > 0) {
        final stock = q['w_bar_length_mm'] ?? m.wBarLengthMm;
        add(
          name: 'Wバー',
          spec: '${shape}・高${m.wBarHeightMm.round()}mm',
          qty: wN,
          unit: '本',
          lengthMm: stock,
          lw: stock.round().toString(),
        );
      }
      final sN = q['single_bar_count'] ?? 0;
      if (sN > 0) {
        final stock = q['single_bar_length_mm'] ?? m.singleBarLengthMm;
        add(
          name: 'シングルバー',
          spec: '${shape}・高${m.singleBarHeightMm.round()}mm',
          qty: sN,
          unit: '本',
          lengthMm: stock,
          lw: stock.round().toString(),
        );
      }
      final chN = q['channel_count'] ?? 0;
      if (chN > 0) {
        final stock = q['channel_length_mm'] ?? m.channelLengthMm;
        add(
          name: '野縁受け',
          spec: '${shape}・${m.channelWidthMm.round()}mm',
          qty: chN,
          unit: '本',
          lengthMm: stock,
          lw: stock.round().toString(),
        );
      }
      final wc = q['w_clip_count'] ?? 0;
      if (wc > 0) {
        add(
          name: 'Wクリップ',
          spec: '${shape}・C${m.wClipUkeWidthMm.round()}',
          qty: double.parse(wc.toStringAsFixed(2)),
          unit: '個',
        );
      }
      final sc = q['single_clip_count'] ?? 0;
      if (sc > 0) {
        add(
          name: 'シングルクリップ',
          spec: '${shape}・C${m.singleClipUkeWidthMm.round()}',
          qty: double.parse(sc.toStringAsFixed(2)),
          unit: '個',
        );
      }
    }

    final areaM2 = q['drop_area_m2'] ?? 0;
    if (m.boards.isNotEmpty && areaM2 > 0) {
      for (var i = 0; i < m.boards.length; i++) {
        final layer = m.boards[i];
        final boardArea =
            (layer.widthMm / 1000.0) * (layer.heightMm / 1000.0);
        if (boardArea <= 0) continue;
        final sheets = (areaM2 / boardArea).ceilToDouble();
        final packed = packBoardSheets(
          sheets,
          widthMm: layer.widthMm,
          heightMm: layer.heightMm,
          thicknessMm: layer.thicknessMm,
        );
        final name = layer.name.trim().isEmpty
            ? 'ボード（第${i + 1}層）'
            : layer.name.trim();
        final th = layer.thicknessMm == layer.thicknessMm.roundToDouble()
            ? '${layer.thicknessMm.round()}mm'
            : '${layer.thicknessMm}mm';
        add(
          name: name,
          spec: '第${i + 1}層・$th',
          qty: packed.qty,
          unit: packed.unit,
          lw: boardSizeLabel(layer.widthMm, layer.heightMm),
        );
      }
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
        fromWall(
          wall: w,
          idGen: idGen,
          lineNumber: i + 1,
          openings: measurement.openings
              .where((o) => o.wallId == w.id)
              .toList(),
        ),
      );
    }
    if (includeCeilings) {
      for (final c in measurement.ceilings) {
        lines.addAll(fromCeiling(ceiling: c, idGen: idGen));
      }
    }
    return mergeByNameAndSize(lines, idGen: idGen);
  }

  /// 試算表左上：測定名-天井 / 測定名-壁（工地名は使わない）
  static String placeLabel(String measurementName, String areaKind) {
    final name = measurementName.trim();
    final kind = areaKind.trim();
    if (name.isEmpty) return kind;
    if (kind.isEmpty) return name;
    if (name.endsWith('-$kind') || name.endsWith(kind)) return name;
    return '$name-$kind';
  }

  /// LGS 欄の工法（天井＝SQ/在来、壁＝コの字/角スタッド）
  static String lgsMethodLabel(
    Measurement measurement, {
    required String areaKind,
    bool onlyEstimateReady = true,
    int? ceilingGroupNumber,
  }) {
    if (areaKind == '天井') {
      final kinds = <String>{
        for (final c in measurement.ceilings)
          if (ceilingGroupNumber == null || c.groupNumber == ceilingGroupNumber)
            c.method.systemKind.label,
      };
      return kinds.join('／');
    }
    final kinds = <String>{};
    for (final w in measurement.walls) {
      if (onlyEstimateReady && !w.estimateReady) continue;
      if (!w.method.useLgs) continue;
      kinds.add(_wallLgsMethodLabel(w.method));
    }
    return kinds.join('／');
  }

  static String _wallLgsMethodLabel(WallMethod m) {
    if (m.studProfile == 'square') {
      final code = m.squareStudCode.isNotEmpty ? m.squareStudCode : m.lgsFormCode;
      return code.isEmpty ? '角スタッド' : '角スタッド$code';
    }
    final code = m.lgsFormCode.trim();
    return code.isEmpty ? 'コの字' : 'コの字$code';
  }

  /// ボード面積を品名ごとに分解
  static List<({String name, double m2})> boardAreasByName(
    Measurement measurement, {
    required String areaKind,
    bool onlyEstimateReady = true,
    int? ceilingGroupNumber,
  }) {
    final bag = <String, double>{};
    void add(String name, double m2) {
      if (m2 <= 0) return;
      final n = name.trim().isEmpty ? 'ボード' : name.trim();
      bag[n] = (bag[n] ?? 0) + m2;
    }

    if (areaKind != '天井') {
      for (final w in measurement.walls) {
        if (onlyEstimateReady && !w.estimateReady) continue;
        if (!w.method.useBoard) continue;
        final a = w.quantities['wall_area_m2'] ?? 0.0;
        if (a <= 0) continue;
        final layersA = BoardSpecParse.layers(w.method.boardStackA);
        final nA = layersA.isEmpty
            ? math.max(1, w.method.layers.count)
            : layersA.length;
        add(w.method.boardKindA, a * nA);
        if (w.method.bothSides) {
          final layersB = BoardSpecParse.layers(w.method.boardStackB);
          final nB = layersB.isEmpty ? nA : layersB.length;
          add(w.method.boardKindB, a * nB);
        }
      }
    }
    if (areaKind != '壁') {
      final groupNums = {
        for (final c in measurement.ceilings) c.groupNumber,
      };
      final splitGroups =
          ceilingGroupNumber == null && groupNums.length > 1;
      for (final c in measurement.ceilings) {
        if (ceilingGroupNumber != null &&
            c.groupNumber != ceilingGroupNumber) {
          continue;
        }
        final a = c.quantities['ceiling_area_m2'] ?? 0.0;
        if (a <= 0) continue;
        if (c.method.finishBoardLayers.isNotEmpty) {
          for (final layer in c.method.finishBoardLayers) {
            final size = boardSizeLabel(layer.widthMm, layer.heightMm);
            final base = layer.name.trim().isEmpty ? 'ボード' : layer.name.trim();
            final labeled = size.isEmpty ? base : '$base　$size';
            add(
              splitGroups ? '${c.groupNumber} $labeled' : labeled,
              a,
            );
          }
        } else {
          add(
            splitGroups ? '${c.groupNumber} 石膏ボード' : '石膏ボード',
            a * math.max(1, c.method.layers.count),
          );
        }
      }
    }
    return [
      for (final e in bag.entries) (name: e.key, m2: e.value),
    ];
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
    bool includeWalls = true,
    int? ceilingGroupNumber,
  }) {
    var lgs = 0.0;
    var board = 0.0;
    var rockFelt = 0.0;
    var gw = 0.0;
    for (final w in measurement.walls) {
      if (!includeWalls) continue;
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
      if (ceilingGroupNumber != null &&
          c.groupNumber != ceilingGroupNumber) {
        continue;
      }
      final a = c.quantities['ceiling_area_m2'] ?? 0.0;
      if (a <= 0) continue;
      lgs += a;
      final n = math.max(
        1,
        c.method.finishBoardLayers.isNotEmpty
            ? c.method.finishBoardLayers.length
            : c.method.layers.count,
      );
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
    '全ネジボルト',
    '野縁受け',
    'Wバー',
    'シングルバー',
    '角スタッド',
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
    '高速カッター',
    'カッター刃',
    '鐵板',
    '鉄板',
    '補強材',
    'アングル',
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
    '見切り',
    'ステープル',
    'ビス',
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

  /// 材料選択と同じサイズ表示（3×3 / 455mm×910mm 等）
  static String boardSizeLabel(double widthMm, double heightMm) {
    const opts = <(int w, int h, String label)>[
      (300, 600, '300mm×600mm'),
      (455, 910, '455mm×910mm'),
      (910, 910, '3×3'),
      (606, 1820, '2×6'),
      (910, 1820, '3×6'),
      (910, 2130, '3×7'),
      (910, 2420, '3×8'),
      (910, 2730, '3×9'),
    ];
    final w = widthMm.round();
    final h = heightMm.round();
    for (final o in opts) {
      if ((w == o.$1 && h == o.$2) || (w == o.$2 && h == o.$1)) {
        return o.$3;
      }
    }
    for (final s in BoardSize.values) {
      final (bw, bh) = s.mmSize;
      if ((widthMm - bw).abs() < 1 && (heightMm - bh).abs() < 1) {
        return s.label;
      }
    }
    return '${widthMm.round()}×${heightMm.round()}';
  }

  /// 枚数を発注単位へ換算。サイズと厚みが揃ったときだけ坪／箱。
  /// 3×3・9.5mm → 坪（4枚＝1坪）／455×910・9.5mm → 坪（8枚＝1坪）
  /// 300×600 → 箱（18枚＝1箱）／それ以外は枚
  static ({double qty, String unit}) packBoardSheets(
    double sheets, {
    double widthMm = 0,
    double heightMm = 0,
    double thicknessMm = 0,
    String lw = '',
  }) {
    if (sheets <= 0) return (qty: 0, unit: '枚');
    final dims = <int>{};
    if (widthMm > 0 && heightMm > 0) {
      dims.add(widthMm.round());
      dims.add(heightMm.round());
    }
    final cleaned = lw.replaceAll('mm', '').replaceAll(' ', '').trim();
    if (cleaned == '3×3' || cleaned == '3x3') {
      dims
        ..add(910)
        ..add(910);
    }
    if (cleaned.contains('1.5×3') ||
        cleaned.contains('1.5x3') ||
        (cleaned.contains('455') && cleaned.contains('910'))) {
      dims
        ..add(455)
        ..add(910);
    }
    final m = RegExp(r'(\d+)\s*[×xX]\s*(\d+)').firstMatch(cleaned);
    if (m != null) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      if (a != null && b != null && a >= 100 && b >= 100) {
        dims.add(a);
        dims.add(b);
      }
    }
    final is95 = (thicknessMm - 9.5).abs() < 0.05;
    if (dims.contains(300) && dims.contains(600)) {
      return (qty: (sheets / 18).ceilToDouble(), unit: '箱');
    }
    if (is95 && dims.contains(910) && dims.length == 1) {
      // 3×3 = 910×910
      return (qty: (sheets / 4).ceilToDouble(), unit: '坪');
    }
    if (is95 && dims.contains(455) && dims.contains(910)) {
      return (qty: (sheets / 8).ceilToDouble(), unit: '坪');
    }
    return (qty: sheets, unit: '枚');
  }

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

  /// 入力区分（spec）を最優先。クロス専用は独立区分。
  static EstimateSheetKind classifyKind(EstimateLine line) {
    final n = line.name.trim();
    final s = line.spec.trim();

    // 0) クロス専用。下り行はボード／LGS に分けて注文書で合算する
    if (line.note == 'cross' ||
        line.note.startsWith('cross|') ||
        s.contains('クロス専用')) {
      return EstimateSheetKind.cross;
    }

    // 1) 材料入力の区分
    if (s == 'ボード関連' || s.startsWith('見切り')) {
      return EstimateSheetKind.board;
    }
    if (s == 'その他') {
      // LGS欄のその他でも、名称にボード系キーワードがあればボードへ
      if (_nameHas(n, _boardKeywords)) return EstimateSheetKind.board;
      return EstimateSheetKind.lgs;
    }

    // 2) ボード（名称キーワード）
    if (_nameHas(n, _boardKeywords)) return EstimateSheetKind.board;
    if (n.contains('クロス') ||
        n.contains('壁紙') ||
        n.contains('パテ') ||
        n.contains('糊') ||
        n.contains('ファイバーテープ') ||
        n.contains('ファイバー')) {
      return EstimateSheetKind.cross;
    }
    if (n.contains('面積')) {
      return EstimateSheetKind.board;
    }

    // 3) LGS
    if (_nameHas(n, _lgsKeywords)) return EstimateSheetKind.lgs;
    if (line.unit == '本' || line.unit == '個') return EstimateSheetKind.lgs;

    // 4) 石膏ボードなど
    if (line.unit == '枚' || line.unit == '箱' || line.unit == '坪') {
      return EstimateSheetKind.board;
    }
    return EstimateSheetKind.board;
  }

  static bool isLgsLine(EstimateLine line) =>
      classifyKind(line) == EstimateSheetKind.lgs;

  static bool isBoardLine(EstimateLine line) =>
      classifyKind(line) == EstimateSheetKind.board;

  static bool isCrossLine(EstimateLine line) =>
      classifyKind(line) == EstimateSheetKind.cross;

  static bool isDropLine(EstimateLine line) {
    if (line.areaKind == 'drop') return true;
    if (line.note == 'drop' || line.note.startsWith('drop|')) return true;
    return line.name.startsWith('下り');
  }

  static List<EstimateLine> dropBoardLines(List<EstimateLine> lines) =>
      lines.where((e) => isDropLine(e) && isBoardLine(e)).toList();

  static List<EstimateLine> dropLgsLines(List<EstimateLine> lines) =>
      lines.where((e) => isDropLine(e) && isLgsLine(e)).toList();

  static bool isWallAreaKind(EstimateLine e) {
    final k = resolveAreaKind(e);
    return k != 'ceiling' && k != 'drop' && k != 'cross';
  }

  /// 試算表・注文書の品名。下り／天井／壁／LGS の接頭辞は付けない（合算キーになる）
  static String catalogItemName(String raw) {
    var n = raw.trim();
    // 壁紙など「壁」で始まる品名は残す。下りランナー／天井 ランナーだけ接頭辞を外す
    n = n.replaceFirst(
      RegExp(r'^(下り|天井|壁)(?=[ 　]|ランナー|Wバー|シングル|スタッド|ボード|石膏|コの字)'),
      '',
    );
    n = n.replaceFirst(RegExp(r'^[ 　]+'), '');
    n = n.replaceFirst(RegExp(r'^LGS[ 　・･]*'), '');
    n = n.replaceFirst(RegExp(r'（天井[^）]*）$'), '');
    n = n.replaceFirst(RegExp(r'\(天井[^)]*\)$'), '');
    return n.trim();
  }

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
          areaKind: e.areaKind,
        ),
      );
    }
    return out;
  }

  /// 壁／天井など発生源が違う行を消さずに上書き保存する
  static String resolveAreaKind(EstimateLine e) {
    if (e.areaKind.isNotEmpty) return e.areaKind;
    final n = '${e.name}${e.spec}${e.note}';
    if (n.contains('下り') || e.note.startsWith('drop|')) return 'drop';
    if (n.contains('天井') ||
        n.contains('野縁') ||
        n.contains('Wバー') ||
        n.contains('Mバー') ||
        n.contains('シングルバー') ||
        n.contains('ダブルバー')) {
      return 'ceiling';
    }
    if (n.contains('クロス') || e.note.startsWith('cross')) return 'cross';
    return 'wall';
  }

  static List<EstimateLine> mergePreservingOtherAreas({
    required List<EstimateLine> existing,
    required List<EstimateLine> incoming,
    required String incomingArea,
  }) {
    final kept = existing
        .where((e) => resolveAreaKind(e) != incomingArea)
        .toList();
    for (final e in incoming) {
      if (e.areaKind.isEmpty) e.areaKind = incomingArea;
    }
    return [...kept, ...incoming];
  }

  /// 同じ線番号の行を差し替え、他番号の明細は残す（非統合の天井を上書きしない）
  static List<EstimateLine> mergeReplacingLineNumbers({
    required List<EstimateLine> existing,
    required List<EstimateLine> incoming,
  }) {
    if (incoming.isEmpty) return List<EstimateLine>.from(existing);
    final nums = incoming.map((e) => e.wallLineNumber).toSet();
    final kept =
        existing.where((e) => !nums.contains(e.wallLineNumber)).toList();
    return [...kept, ...incoming];
  }

  /// 下り保存：同じ番号のボード／LGS だけ差し替え、もう一方と他番号は残す
  static List<EstimateLine> mergeReplacingLineNumbersOfKind({
    required List<EstimateLine> existing,
    required List<EstimateLine> incoming,
    required EstimateSheetKind kind,
  }) {
    if (incoming.isEmpty) return List<EstimateLine>.from(existing);
    if (kind == EstimateSheetKind.drop) {
      return mergeReplacingLineNumbers(
        existing: existing,
        incoming: incoming,
      );
    }
    final nums = incoming.map((e) => e.wallLineNumber).toSet();
    final kept = existing.where((e) {
      if (!nums.contains(e.wallLineNumber)) return true;
      return classifyKind(e) != kind;
    }).toList();
    return [...kept, ...incoming];
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
      // 天井：第N層は合算キーに入れない。品名＋寸法（lw）＋厚みだけ
      final specKey = line.spec.replaceFirst(RegExp(r'^第\d+層[・･]'), '');
      final name = catalogItemName(line.name);
      final key =
          '$name\u0001$specKey\u0001${line.lw}\u0001${line.unit}\u0001$hKey\u0001${line.wallLineNumber}\u0001${resolveAreaKind(line)}';
      final existing = map[key];
      if (existing == null) {
        map[key] = EstimateLine(
          id: idGen(),
          name: name,
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
          areaKind: resolveAreaKind(line),
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

    String specKeyOf(EstimateLine e) {
      var s = e.spec.trim();
      s = s.replaceFirst(RegExp(r'^(L型|梁型)?下り[・･]'), '');
      s = s.replaceFirst(RegExp(r'^(L型|梁型)[・･]'), '');
      s = s.replaceFirst(RegExp(r'^第\d+層[・･]'), '');
      return s;
    }

    for (final line in lines) {
      final size = sizeOf(line);
      final name = catalogItemName(line.name);
      final key = '$name\u0001$size\u0001${specKeyOf(line)}';
      final t = totalOf(line);
      final existing = map[key];
      if (existing == null) {
        map[key] = EstimateLine(
          id: idGen(),
          name: name,
          spec: line.spec.trim(),
          lw: size,
          lengthMm: line.lengthMm,
          qty: line.qty,
          unit: line.unit,
          subtotal: line.subtotal,
          wastePercent: 0,
          note: '',
          areaKind: resolveAreaKind(line),
        );
        totals[key] = t;
        order.add(key);
      } else {
        existing.qty += line.qty;
        existing.subtotal += line.subtotal;
        totals[key] = (totals[key] ?? 0) + t;
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
