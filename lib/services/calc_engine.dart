import 'dart:math' as math;

import '../models/models.dart';
import 'board_spec_parse.dart';
import 'ceiling_layout.dart';
import 'opening_reinforce.dart';

/// LGS / ボード / クロス自動積算エンジン
class CalcEngine {
  /// 2×6 / 3×6 / 3×7 / 3×8 / 3×9
  static (double wMm, double hMm) boardMm(BoardSize size) => size.mmSize;

  /// コの字スタッド1本あたりのスペーサー個数
  /// 両端各1個＋中間は間隔600mm以下
  static int studSpacerCountPerStud(double lengthMm) {
    if (lengthMm <= 0) return 0;
    return (lengthMm / 600.0).ceil() + 1;
  }

  static double distPx(Point2 a, Point2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// ピクセル長 → mm
  static double pxToMm(double px, double scalePxPerMm) {
    if (scalePxPerMm <= 0) return 0;
    return px / scalePxPerMm;
  }

  /// 2線分の交差（端点共有以外）。交差ありなら交点、なければ null
  static Point2? segmentIntersection(
    Point2 a1,
    Point2 a2,
    Point2 b1,
    Point2 b2, {
    double eps = 1e-6,
  }) {
    final dxa = a2.x - a1.x;
    final dya = a2.y - a1.y;
    final dxb = b2.x - b1.x;
    final dyb = b2.y - b1.y;
    final den = dxa * dyb - dya * dxb;
    if (den.abs() < eps) return null; // 平行
    final t = ((b1.x - a1.x) * dyb - (b1.y - a1.y) * dxb) / den;
    final u = ((b1.x - a1.x) * dya - (b1.y - a1.y) * dxa) / den;
    if (t < -eps || t > 1 + eps || u < -eps || u > 1 + eps) return null;
    // 両方ほぼ端点のみの共有はチェーン接続扱い（別処理）→ ここでは許容
    return Point2(a1.x + t * dxa, a1.y + t * dya);
  }

  /// 点 P が線分 AB の内分点付近か（端点除外）
  static bool pointOnSegmentInterior(
    Point2 p,
    Point2 a,
    Point2 b, {
    double tolPx = 3.0,
  }) {
    final abx = b.x - a.x;
    final aby = b.y - a.y;
    final len2 = abx * abx + aby * aby;
    if (len2 < 1e-8) return false;
    final t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2;
    if (t <= 0.02 || t >= 0.98) return false;
    final projX = a.x + t * abx;
    final projY = a.y + t * aby;
    final dx = p.x - projX;
    final dy = p.y - projY;
    return dx * dx + dy * dy <= tolPx * tolPx;
  }

  /// 別チェーン同士の交差・T字接合の個数（近接重複は1つにまとめる）
  static int countChainJunctions(List<List<Point2>> chains, {double mergePx = 4}) {
    if (chains.length < 2) return 0;
    final hits = <Point2>[];

    void addHit(Point2 p) {
      for (final h in hits) {
        final dx = h.x - p.x;
        final dy = h.y - p.y;
        if (dx * dx + dy * dy <= mergePx * mergePx) return;
      }
      hits.add(p);
    }

    // 線分交差
    for (var ci = 0; ci < chains.length; ci++) {
      final ca = chains[ci];
      for (var i = 0; i < ca.length - 1; i++) {
        for (var cj = ci + 1; cj < chains.length; cj++) {
          final cb = chains[cj];
          for (var j = 0; j < cb.length - 1; j++) {
            final hit = segmentIntersection(ca[i], ca[i + 1], cb[j], cb[j + 1]);
            if (hit != null) addHit(hit);
          }
        }
      }
    }

    // T字：一方の端点が他チェーン線分の内側
    for (var ci = 0; ci < chains.length; ci++) {
      final ca = chains[ci];
      if (ca.isEmpty) continue;
      for (final end in [ca.first, ca.last]) {
        for (var cj = 0; cj < chains.length; cj++) {
          if (ci == cj) continue;
          final cb = chains[cj];
          for (var j = 0; j < cb.length - 1; j++) {
            if (pointOnSegmentInterior(end, cb[j], cb[j + 1])) {
              addHit(end);
            }
          }
        }
      }
    }

    return hits.length;
  }

  /// 壁算量（折れ線対応。曲がり角では LGS Stud を3本計上）
  static Map<String, double> calcWall({
    Point2? a,
    Point2? b,
    List<Point2>? points,
    List<int>? chainStarts,
    required double heightMm,
    required double scalePxPerMm,
    required WallMethod method,
    List<WallOpening> openings = const [],
    double? ironPlateRunMm,
  }) {
    final pts = points ??
        (a != null && b != null ? [a, b] : <Point2>[]);
    if (pts.length < 2) {
      return {
        'wall_length_mm': 0,
        'wall_height_mm': heightMm,
        'wall_area_m2': 0,
      };
    }

    final starts = [...(chainStarts ?? const [0])]..sort();
    if (starts.isEmpty || starts.first != 0) starts.insert(0, 0);
    final chains = <List<Point2>>[];
    for (var i = 0; i < starts.length; i++) {
      final from = starts[i].clamp(0, pts.length);
      final to = i + 1 < starts.length
          ? starts[i + 1].clamp(0, pts.length)
          : pts.length;
      if (to - from >= 2) chains.add(pts.sublist(from, to));
    }
    if (chains.isEmpty) chains.add(pts);

    var lengthMm = 0.0;
    var cornerCount = 0;
    var studCount = 0; // スタッド幅の本数
    var runnerWidthStudCount = 0; // ランナー幅スタッド（端・折点）
    final pitch = method.pitchMm;
    final needsRunnerSpacer = method.useLgs &&
        method.studProfile != 'square' &&
        method.studWidthMm < method.runnerWidthMm;

    for (final chain in chains) {
      for (var i = 0; i < chain.length - 1; i++) {
        lengthMm += pxToMm(distPx(chain[i], chain[i + 1]), scalePxPerMm);
      }
      final cCorners = math.max(0, chain.length - 2);
      cornerCount += cCorners;
      if (method.useLgs) {
        // 区間ごとにピッチ割付（両端含む）→ 折点の二重計上を補正
        for (var i = 0; i < chain.length - 1; i++) {
          final segMm = pxToMm(distPx(chain[i], chain[i + 1]), scalePxPerMm);
          studCount += math.max(2, (segMm / pitch).floor() + 1);
        }
        studCount -= cCorners; // 折点はいったん1本

        if (needsRunnerSpacer) {
          // ランナー幅＞スタッド幅：折点の細スタッドは2本
          studCount += cCorners; // 1→2
          // 線の両端＋折点にランナー幅スタッドを各1本
          runnerWidthStudCount += chain.length;
        } else {
          // 通常：折点は3本
          studCount += cCorners * 2; // 1→3
        }
      }
    }

    // 多線の交差・T字：各接合部にスタッド3本
    final junctions = method.useLgs ? countChainJunctions(chains) : 0;
    if (junctions > 0) {
      studCount += junctions * 3;
    }

    final areaM2 = (lengthMm / 1000.0) * (heightMm / 1000.0);
    var openingAreaM2 = 0.0;
    for (final o in openings) {
      if (o.widthMm > 0 && o.heightMm > 0) {
        openingAreaM2 += o.areaM2;
      }
    }
    final netAreaM2 =
        (areaM2 - openingAreaM2).clamp(0.0, double.infinity);
    // 鉄板のみ等（LGSオフ）は LGS 壁面積に含めない
    final lgsAreaM2 = method.useLgs ? netAreaM2 : 0.0;
    final out = <String, double>{
      'wall_length_mm': lengthMm,
      'wall_height_mm': heightMm,
      'wall_area_m2': lgsAreaM2,
      'wall_gross_area_m2': areaM2,
      'wall_net_area_m2': netAreaM2,
      'opening_area_m2': openingAreaM2,
      'corner_count': cornerCount.toDouble(),
      if (junctions > 0) 'junction_count': junctions.toDouble(),
    };

    if (method.useLgs) {
      final runnerMm = lengthMm * 2; // 天地
      final totalStuds = studCount + runnerWidthStudCount;
      out['stud_count'] = studCount.toDouble();
      out['runner_mm'] = runnerMm;
      out['runner_m'] = runnerMm / 1000.0;
      out['stud_width_mm'] = method.studWidthMm;
      out['runner_width_mm'] = method.runnerWidthMm;
      out['lgs_type'] = method.studWidthMm;
      out['pitch_mm'] = pitch;
      if (method.runnerLengthMm > 0) {
        out['runner_length_mm'] = method.runnerLengthMm;
      }
      if (method.studLengthMm > 0) {
        out['stud_length_mm'] = method.studLengthMm;
      }

      if (runnerWidthStudCount > 0) {
        out['runner_width_stud_count'] = runnerWidthStudCount.toDouble();
      }

      // コの字スタッド：各本にスペーサー（両端＋間隔600mm以下）
      if (method.studProfile != 'square' && totalStuds > 0) {
        final studLen = method.studLengthMm > 0 ? method.studLengthMm : heightMm;
        final perStud = studSpacerCountPerStud(studLen);
        if (perStud > 0) {
          out['stud_spacer_count'] = (totalStuds * perStud).toDouble();
          out['stud_spacer_per_stud'] = perStud.toDouble();
          out['stud_spacer_pitch_mm'] = 600;
        }
      }

      // スタッド幅 < ランナー幅 かつ スペーサーON → ランナースペーサー（細スタッド×2）
      if (needsRunnerSpacer && method.useSpacer) {
        out['runner_spacer_count'] = (studCount * 2).toDouble();
        out['runner_spacer_mm'] = method.runnerSpacerMm;
        out['spacer_count'] = out['runner_spacer_count']!;
        out['use_runner_spacer'] = 1;
      }

      // 折点＋交差の細スタッド計上（表示用）
      out['corner_studs'] = needsRunnerSpacer
          ? (cornerCount * 2 + junctions * 3).toDouble()
          : (cornerCount * 3 + junctions * 3).toDouble();
      if (junctions > 0) {
        out['junction_studs'] = (junctions * 3).toDouble();
      }

      if (method.useFureDome && method.studProfile != 'square') {
        final rows = math.max(1, (heightMm / 1200).floor());
        out['furedome_m'] = (rows * lengthMm) / 1000.0;
        out['furedome_width_mm'] = method.fureDomeWidthMm;
        if (method.fureDomeLengthMm > 0) {
          out['furedome_length_mm'] = method.fureDomeLengthMm;
        }
      }
    }

    if (method.useBoard) {
      var layersA = BoardSpecParse.layers(method.boardStackA);
      var layersB = method.bothSides
          ? BoardSpecParse.layers(method.boardStackB)
          : <double>[];
      if (layersA.isEmpty) {
        final n = method.layers.count;
        layersA = List.filled(n, method.effectiveBoardAMm);
      }
      if (method.bothSides && layersB.isEmpty) {
        final n = method.layers.count;
        layersB = List.filled(n, method.effectiveBoardBMm);
      }

      void countByThickness(List<double> layers, List<BoardSize> sizes) {
        for (var i = 0; i < layers.length; i++) {
          final th = layers[i];
          final size = i < sizes.length ? sizes[i] : sizes.first;
          final (bw, bh) = boardMm(size);
          final boardAreaM2 = (bw / 1000.0) * (bh / 1000.0);
          final per =
              boardAreaM2 > 0 ? (netAreaM2 / boardAreaM2).ceilToDouble() : 0.0;
          final key =
              'board_sheets_${th == th.roundToDouble() ? th.toStringAsFixed(0) : th.toStringAsFixed(1)}';
          out[key] = (out[key] ?? 0) + per;
        }
      }

      final sizesA = method.resolvedLayerSizesA(layersA.length);
      final sizesB = method.resolvedLayerSizesB(layersB.length);

      double sheetsForLayers(List<double> layers, List<BoardSize> sizes) {
        var total = 0.0;
        for (var i = 0; i < layers.length; i++) {
          final size = i < sizes.length ? sizes[i] : method.boardSize;
          final (bw, bh) = boardMm(size);
          final boardAreaM2 = (bw / 1000.0) * (bh / 1000.0);
          total +=
              boardAreaM2 > 0 ? (netAreaM2 / boardAreaM2).ceilToDouble() : 0.0;
        }
        return total;
      }

      final sheetsA = sheetsForLayers(layersA, sizesA);
      final sheetsB =
          method.bothSides ? sheetsForLayers(layersB, sizesB) : 0.0;
      final sheets = sheetsA + sheetsB;
      out['board_sheets'] = sheets;
      out['board_sheets_a'] = sheetsA;
      out['board_sheets_b'] = sheetsB;
      out['board_layers'] = (layersA.length + layersB.length).toDouble();
      out['board_layer_count_a'] = layersA.length.toDouble();
      out['board_layer_count_b'] = layersB.length.toDouble();
      out['board_thickness_mm'] = method.boardThicknessMm;
      out['board_thickness_a_mm'] = method.effectiveBoardAMm;
      out['board_thickness_b_mm'] = method.effectiveBoardBMm;
      out['board_sides'] = 1.0 + (method.bothSides ? 1.0 : 0.0);
      out['screw_boxes'] = math.max(1, (sheets * 50 / 1000).ceil()).toDouble();
      out['finished_thickness_mm'] =
          method.studWidthMm + method.effectiveBoardAMm + method.effectiveBoardBMm;

      countByThickness(layersA, sizesA);
      if (method.bothSides) countByThickness(layersB, sizesB);
    }

    if (method.useKeikal && method.keikalThicknessMm > 0) {
      final (kw, kh) = boardMm(method.keikalBoardSize);
      final boardAreaM2 = (kw / 1000.0) * (kh / 1000.0);
      final sheets =
          boardAreaM2 > 0 ? (netAreaM2 / boardAreaM2).ceilToDouble() : 0.0;
      final sides = method.bothSides ? 2.0 : 1.0;
      out['keikal_sheets'] = sheets * sides;
      out['keikal_thickness_mm'] = method.keikalThicknessMm;
    }

    // ロックフェルト：壁長×2（天地）＋壁高×2（両端）
    if (method.useRockFelt) {
      final periMm = lengthMm * 2 + heightMm * 2;
      final periM = periMm / 1000.0;
      final pcs = periM.ceilToDouble(); // 1本＝1000mm
      final boxes = (pcs / 100).ceilToDouble(); // 1箱＝100本
      out['rock_felt_m'] = periM;
      out['rock_felt_pcs'] = pcs;
      out['rock_felt_boxes'] = boxes;
      out['rock_felt_width_mm'] = method.rockFeltWidthMm;
    }

    // タイガーUタイト：総延長＝ロックフェルト延長
    if (method.useTigerUtight) {
      final meters = out['rock_felt_m'] ??
          ((lengthMm * 2 + heightMm * 2) / 1000.0);
      final is720 = method.tigerUtightType == '720';
      final perBoxM = is720 ? 180.0 : 150.0; // 720:15本×12m / 320:30本×5m
      final boxes = meters > 0 ? (meters / perBoxM).ceilToDouble() : 0.0;
      out['tiger_utight_m'] = meters;
      out['tiger_utight_boxes'] = boxes < 1 && meters > 0 ? 1.0 : boxes;
      out['tiger_utight_type'] = is720 ? 720.0 : 320.0;
    }

    // グラスウール：LGS 平米＝壁面積、発注 m＝㎡÷0.91
    if (method.useGlassWool) {
      out['glass_wool_m2'] = (out['glass_wool_m2'] ?? 0) + netAreaM2;
      out['glass_wool_k'] = method.glassWoolK.toDouble();
      out['glass_wool_order_m'] =
          netAreaM2 > 0 ? netAreaM2 / 0.91 : 0.0;
    }

    // 鉄板：T線の全長（×段数）÷定尺。壁の画線長は使わない
    final ironMm = ironPlateRunMm ?? 0;
    if (method.useIronPlate && method.ironPlateLengthMm > 0 && ironMm > 0) {
      final seg = method.ironPlateSegmentCount;
      final runMm = ironMm * seg;
      final sheets = (runMm / method.ironPlateLengthMm).ceilToDouble();
      out['iron_plate_sheets'] = sheets < 1 ? 1.0 : sheets;
      out['iron_plate_width_mm'] = method.ironPlateWidthMm;
      out['iron_plate_length_mm'] = method.ironPlateLengthMm;
      out['iron_plate_run_mm'] = runMm;
      out['iron_plate_measure_mm'] = ironMm;
      out['iron_plate_segments'] = seg.toDouble();
    }

    // 開口補強
    if (openings.isNotEmpty) {
      final stock = method.reinforceLengthMm > 0
          ? method.reinforceLengthMm
          : (method.studLengthMm > 0 ? method.studLengthMm : heightMm);
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
      if (reinforceBars > 0 || method.useReinforceMaterial) {
        out['reinforce_bars'] = reinforceBars.toDouble();
        out['reinforce_width_mm'] = method.reinforceWidthMm > 0
            ? method.reinforceWidthMm
            : method.studWidthMm;
        out['reinforce_length_mm'] = stock;
      }
      if (openingRunnerMm > 0) {
        out['opening_runner_mm'] = openingRunnerMm;
        out['opening_runner_m'] = openingRunnerMm / 1000.0;
      }

      // アングルピース：図形線本数×2（オプションON時）
      if (method.useAnglePiece) {
        var anglePcs = 0;
        for (final o in openings) {
          final pattern = OpeningReinforcePatternX.parse(o.patternName);
          anglePcs += OpeningReinforceCalc.anglePieces(
            pattern: pattern,
            magusaSegments: o.magusaSegments,
          );
        }
        if (anglePcs > 0) {
          out['angle_piece_count'] = anglePcs.toDouble();
          out['angle_piece_mm'] =
              method.anglePieceMm > 0 ? method.anglePieceMm : 50;
        }
      }
    }

    // グラスウール等（壁面積 m²）— ボード有無に関わらず（芯材入力の互換）
    for (final extra in BoardSpecParse.namedExtras(method.lgsCoreSpec)) {
      final isGw = extra.contains('グラスウール') ||
          extra.toUpperCase().contains('GW') ||
          extra.contains('グラス');
      if (isGw) {
        if (!method.useGlassWool) {
          out['glass_wool_m2'] = (out['glass_wool_m2'] ?? 0) + netAreaM2;
        }
      } else {
        final key = 'fill_${extra}_m2';
        out[key] = (out[key] ?? 0) + netAreaM2;
      }
    }

    if (method.useCross || method.crossDedicated.enabled) {
      final width = method.crossDedicated.enabled
          ? (method.crossDedicated.crossWidthM > 0
              ? method.crossDedicated.crossWidthM
              : 0.9)
          : (method.crossWidthM <= 0 ? 0.9 : method.crossWidthM);
      final waste = method.crossDedicated.enabled
          ? 1.0
          : (1.0 + method.crossWasteRate);
      final meters = (netAreaM2 / width) * waste;
      out['cross_m'] = meters;
    }

    return out;
  }

  /// 多角形面積（shoelace）→ mm²（スケール適用後）
  static double polygonAreaMm2(List<Point2> pts, double scalePxPerMm) {
    if (pts.length < 3 || scalePxPerMm <= 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = pts[(i + 1) % pts.length];
      sum += p.x * q.y - q.x * p.y;
    }
    final areaPx2 = sum.abs() / 2.0;
    final mmPerPx = 1.0 / scalePxPerMm;
    return areaPx2 * mmPerPx * mmPerPx;
  }

  static Map<String, double> calcCeiling({
    required List<Point2> points,
    required double scalePxPerMm,
    required CeilingMethod method,
  }) {
    final areaMm2 = polygonAreaMm2(points, scalePxPerMm);
    final areaM2 = areaMm2 / 1e6;
    final tsubo = areaM2 / 3.305785;
    final jo = areaM2 / 1.62;

    var periPx = 0.0;
    for (var i = 0; i < points.length; i++) {
      periPx += distPx(points[i], points[(i + 1) % points.length]);
    }
    final periMm = pxToMm(periPx, scalePxPerMm);

    final layout = CeilingLayoutEngine.layout(
      points: points,
      scalePxPerMm: scalePxPerMm,
      method: method,
    );

    final (bw, bh) = boardMm(method.boardSize);
    final boardArea = (bw / 1000.0) * (bh / 1000.0);
    final finishLayers = method.finishBoardLayers;
    double sheets;
    int layerCount;
    if (finishLayers.isNotEmpty) {
      layerCount = finishLayers.length;
      sheets = 0;
      for (final layer in finishLayers) {
        final a = (layer.widthMm / 1000.0) * (layer.heightMm / 1000.0);
        if (a > 0) sheets += (areaM2 / a).ceilToDouble();
      }
    } else {
      layerCount = method.layers.count;
      sheets = boardArea > 0
          ? (areaM2 * layerCount / boardArea).ceilToDouble()
          : 0.0;
    }

    return {
      'ceiling_area_m2': areaM2,
      'ceiling_area_tsubo': tsubo,
      'ceiling_area_jo': jo,
      'perimeter_mm': periMm,
      'w_bar_m': layout.wBarLengthM,
      'single_bar_m': layout.singleBarLengthM,
      'uke_bar_m': layout.ukeBarLengthM,
      'square_stud_m': layout.squareStudLengthM,
      // 互換キー
      'm_bar_m': layout.singleBarLengthM,
      'cw_bar_m': layout.ukeBarLengthM,
      'hanger_count': layout.boltCount.toDouble(),
      'bolt_count': layout.boltCount.toDouble(),
      'nut_count': (method.nutCountOverride ?? (layout.boltCount * 2)).toDouble(),
      'hanger_piece_count':
          (method.hangerCountOverride ?? layout.boltCount).toDouble(),
      'uke_channel_width_mm': method.ukeChannelWidthMm,
      'uke_channel_length_mm': method.ukeChannelLengthMm,
      'uke_channel_count': CeilingLayoutEngine.countUkeChannelPieces(
        ukeLengthsMm: [
          for (final b in layout.ukeBars)
            b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.ukeChannelLengthMm,
      ).toDouble(),
      'channel_joint_count': CeilingLayoutEngine.countSpliceJoints(
        lengthsMm: [
          for (final b in layout.ukeBars) b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.ukeChannelLengthMm,
      ).toDouble(),
      'w_bar_count': CeilingLayoutEngine.countUkeChannelPieces(
        ukeLengthsMm: [
          for (final b in layout.noenBars)
            if (b.isW && !b.isUke) b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.wBarLengthMm,
      ).toDouble(),
      'single_bar_count': CeilingLayoutEngine.countUkeChannelPieces(
        ukeLengthsMm: [
          for (final b in layout.noenBars)
            if (!b.isW && !b.isUke) b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.singleBarLengthMm,
      ).toDouble(),
      'w_bar_joint_count': CeilingLayoutEngine.countSpliceJoints(
        lengthsMm: [
          for (final b in layout.noenBars)
            if (b.isW && !b.isUke) b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.wBarLengthMm,
      ).toDouble(),
      'single_bar_joint_count': CeilingLayoutEngine.countSpliceJoints(
        lengthsMm: [
          for (final b in layout.noenBars)
            if (!b.isW && !b.isUke) b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.singleBarLengthMm,
      ).toDouble(),
      'w_clip_count': () {
        final wBars = [
          for (final b in layout.noenBars)
            if (b.isW && !b.isUke) b,
        ];
        return CeilingLayoutEngine.countBarCrossings(wBars, layout.ukeBars)
            .toDouble();
      }(),
      'single_clip_count': () {
        final sBars = [
          for (final b in layout.noenBars)
            if (!b.isW && !b.isUke) b,
        ];
        return CeilingLayoutEngine.countBarCrossings(sBars, layout.ukeBars)
            .toDouble();
      }(),
      'mikiri_count': method.mikiriEnabled && method.mikiriLengthMm > 0
          ? (periMm / method.mikiriLengthMm).ceilToDouble()
          : 0.0,
      'sq_stud_type': double.tryParse(method.sqStudType) ?? 0,
      'sq_stud_length_mm': method.sqStudLengthMm,
      'sq_stud_count': CeilingLayoutEngine.countUkeChannelPieces(
        ukeLengthsMm: [
          for (final b in layout.squareStudBars)
            b.lengthPx / scalePxPerMm,
        ],
        stockLengthMm: method.sqStudLengthMm,
      ).toDouble(),
      'clip_uke_label': method.clipUkeLabel == 'C19'
          ? 19
          : method.clipUkeLabel == 'C25'
              ? 25
              : 38,
      'clip_type': double.tryParse(method.clipType) ?? 0,
      'clip_count': layout.squareStudUkeContactCount.toDouble(),
      'runner_width_mm': method.runnerWidthMm,
      'runner_length_mm': method.runnerLengthMm,
      'runner_edge_mm': CeilingLayoutEngine.runnerPerpEdgeLengthMm(
        points: points,
        scalePxPerMm: scalePxPerMm,
        method: method,
        squareStudBars: layout.squareStudBars,
      ),
      'runner_count': CeilingLayoutEngine.countRunnerPieces(
        edgeTotalMm: CeilingLayoutEngine.runnerPerpEdgeLengthMm(
          points: points,
          scalePxPerMm: scalePxPerMm,
          method: method,
          squareStudBars: layout.squareStudBars,
        ),
        stockLengthMm: method.runnerLengthMm,
      ).toDouble(),
      'hanger_bolt_w38': method.hangerBoltWidthLabel == 'W1/2' ? 0.5 : 0.375,
      'hanger_uke_width_mm': method.hangerUkeWidthMm,
      'hanger_fixture_height_mm': method.hangerFixtureHeightMm,
      'bolt_width_label': method.boltWidthLabel == 'W1/2' ? 0.5 : 0.375,
      'bolt_length_mm': method.boltLengthMm,
      'board_sheets': sheets,
      'board_layers': layerCount.toDouble(),
      'screw_boxes': math.max(1, (sheets * 50 / 1000).ceil()).toDouble(),
    };
  }

  static (double, double) _bbox(List<Point2> pts) {
    var minX = pts.first.x, maxX = pts.first.x;
    var minY = pts.first.y, maxY = pts.first.y;
    for (final p in pts) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return (maxX - minX, maxY - minY);
  }

  /// 測定セッションから注文明細を集約
  static List<OrderLine> aggregateOrderLines(
    List<Measurement> measurements, {
    required String Function() idGen,
  }) {
    final bag = <String, (String unit, double qty)>{};

    void add(String name, String unit, double qty) {
      if (qty <= 0) return;
      final cur = bag[name];
      if (cur == null) {
        bag[name] = (unit, qty);
      } else {
        bag[name] = (unit, cur.$2 + qty);
      }
    }

    for (final m in measurements) {
      for (final wall in m.walls) {
        final q = wall.quantities;
        if (q.containsKey('stud_count')) {
          final width = (q['stud_width_mm'] ?? q['lgs_type'] ?? 65).round();
          add('LGS スタッド ${width}形', '本', q['stud_count']!);
        }
        final rwStuds = q['runner_width_stud_count'];
        if (rwStuds != null && rwStuds > 0) {
          final rw = (q['runner_width_mm'] ?? 65).round();
          add('LGS スタッド ${rw}形（端・折点）', '本', rwStuds);
        }
        final studSp = q['stud_spacer_count'];
        if (studSp != null && studSp > 0) {
          add('スペーサー', '個', studSp);
        }
        if (q.containsKey('runner_m')) {
          final width = (q['stud_width_mm'] ?? q['lgs_type'] ?? 65).round();
          add('LGS ランナー ${width}形（天地）', 'm', q['runner_m']!);
        }
        final spacerQty =
            q['runner_spacer_count'] ?? q['spacer_count'];
        if (spacerQty != null && spacerQty > 0) {
          final spMm = (q['runner_spacer_mm'] ?? 10).round();
          add('ランナースペーサー ${spMm}mm', '個', spacerQty);
        }
        if (q.containsKey('furedome_m')) {
          final fdMm = (q['furedome_width_mm'] ?? 19).round();
          add('振れ止め WB-${fdMm}', 'm', q['furedome_m']!);
        }
        // 厚さ別に石膏ボードを加算（9.5 / 12.5 を分けて）
        var boardSplit = false;
        for (final e in q.entries) {
          if (e.key.startsWith('board_sheets_') &&
              e.key != 'board_sheets_a' &&
              e.key != 'board_sheets_b') {
            final th = e.key.replaceFirst('board_sheets_', '');
            add('石膏ボード ${th}mm', '枚', e.value);
            boardSplit = true;
          }
        }
        if (!boardSplit && q.containsKey('board_sheets')) {
          final th = (q['board_thickness_mm'] ?? 12.5);
          final thLabel = th == th.roundToDouble()
              ? th.toStringAsFixed(0)
              : th.toStringAsFixed(1);
          add('石膏ボード ${thLabel}mm', '枚', q['board_sheets']!);
        }
        if (q.containsKey('glass_wool_m2')) {
          add('グラスウール', 'm²', q['glass_wool_m2']!);
        }
        for (final e in q.entries) {
          if (e.key.startsWith('fill_') && e.key.endsWith('_m2')) {
            final name = e.key
                .substring('fill_'.length, e.key.length - '_m2'.length);
            add(name, 'm²', e.value);
          }
        }
        if (q.containsKey('cross_m')) {
          add('クロス（壁紙）', 'm', q['cross_m']!);
        }
      }
      for (final c in m.ceilings) {
        final q = c.quantities;
        if ((q['w_bar_m'] ?? 0) > 0) {
          add('Wバー（野縁）', 'm', q['w_bar_m']!);
        }
        if ((q['single_bar_m'] ?? 0) > 0) {
          add('シングルバー（野縁）', 'm', q['single_bar_m']!);
        } else if ((q['m_bar_m'] ?? 0) > 0) {
          add('Mバー（野縁）', 'm', q['m_bar_m']!);
        }
        if ((q['uke_bar_m'] ?? q['cw_bar_m'] ?? 0) > 0) {
          add('野縁受け', 'm', (q['uke_bar_m'] ?? q['cw_bar_m'])!);
        }
        if (q.containsKey('hanger_count')) {
          add('全ネジボルト', '本', q['hanger_count']!);
        }
        if (q.containsKey('board_sheets')) {
          final layers = (q['board_layers'] ?? 1).round();
          add('石膏ボード（${layers}層）', '枚', q['board_sheets']!);
        }
      }
    }

    return bag.entries
        .map(
          (e) => OrderLine(
            id: idGen(),
            name: e.key,
            unit: e.value.$1,
            qty: double.parse(e.value.$2.toStringAsFixed(2)),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
