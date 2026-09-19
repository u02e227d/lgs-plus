import '../models/models.dart';
import 'board_stack.dart';
import 'lgs_catalog.dart';

/// 手動入力／線スキャンから仕上壁厚・LGS・石膏ボード構成を分解
class WallThicknessBreakdown {
  final double finishedThicknessMm;
  final double centerToOuterAMm;
  final double centerToOuterBMm;
  final LgsForm form;
  final BoardStackSpec stackA;
  final BoardStackSpec stackB;
  final WallSides sides;
  final double errorMm;
  final String summaryJa;
  final LgsMethodPreset nearestPreset;

  const WallThicknessBreakdown({
    required this.finishedThicknessMm,
    required this.centerToOuterAMm,
    required this.centerToOuterBMm,
    required this.form,
    required this.stackA,
    required this.stackB,
    required this.sides,
    required this.errorMm,
    required this.summaryJa,
    required this.nearestPreset,
  });

  BoardThickness get boardA => stackA.primaryThickness;
  BoardThickness get boardB => stackB.primaryThickness;
  BoardLayers get layersA => stackA.asLayersEnum;
  BoardLayers get layersB => stackB.asLayersEnum;

  double get studMm => form.studWidthMm;
  double get boardATotalMm => stackA.totalMm;
  double get boardBTotalMm =>
      sides == WallSides.both ? stackB.totalMm : 0;
}

class WallThicknessAnalyzer {
  WallThicknessAnalyzer._();

  static WallThicknessBreakdown analyze({
    double? centerToOuterAMm,
    double? centerToOuterBMm,
    double? finishedThicknessMm,
    BoardStackSpec? hintStackA,
    BoardStackSpec? hintStackB,
  }) {
    double a;
    double b;
    double finished;

    if (finishedThicknessMm != null && finishedThicknessMm > 0) {
      finished = finishedThicknessMm;
      if (centerToOuterAMm != null &&
          centerToOuterAMm > 0 &&
          centerToOuterBMm != null &&
          centerToOuterBMm > 0) {
        a = centerToOuterAMm;
        b = centerToOuterBMm;
        final sum = a + b;
        if (sum > 0 && (sum - finished).abs() > 1) {
          a = finished * (a / sum);
          b = finished * (b / sum);
        }
      } else if (centerToOuterAMm != null && centerToOuterAMm > 0) {
        a = centerToOuterAMm.clamp(1, finished - 1);
        b = finished - a;
      } else {
        a = finished / 2;
        b = finished / 2;
      }
    } else {
      a = centerToOuterAMm ?? 0;
      b = centerToOuterBMm ?? a;
      if (a <= 0 && b <= 0) {
        return analyze(finishedThicknessMm: 90);
      }
      if (a <= 0) a = b;
      if (b <= 0) b = a;
      finished = a + b;
    }

    return _searchBest(
      finished,
      a,
      b,
      hintStackA: hintStackA,
      hintStackB: hintStackB,
    );
  }

  /// 図面線スキャン結果を優先して分解
  static WallThicknessBreakdown analyzeFromStacks({
    required BoardStackSpec stackA,
    BoardStackSpec? stackB,
    required LgsForm form,
    double? finishedMm,
  }) {
    final sb = stackB ?? stackA;
    final sides =
        stackB == null ? WallSides.single : WallSides.both;
    // 仕上壁厚 = ランナー幅 + ボード（スタッド幅・内法ではない）
    final runnerW = form.studWidthMm;
    final finished = finishedMm ??
        (runnerW + stackA.totalMm + (sides == WallSides.both ? sb.totalMm : 0));
    final offsetA = runnerW / 2 + stackA.totalMm;
    final offsetB = sides == WallSides.both
        ? runnerW / 2 + sb.totalMm
        : runnerW / 2;
    final preset = _nearestPreset(form, stackA, sides);
    final summary = StringBuffer()
      ..writeln(
        '仕上壁厚 ${finished.toStringAsFixed(0)}mm '
        '（芯→A ${offsetA.toStringAsFixed(0)} / 芯→B ${offsetB.toStringAsFixed(0)}）',
      )
      ..writeln(
        '→ LGS ${form.label}（${form.studCode} ${form.studWidthMm.toStringAsFixed(0)}mm）',
      )
      ..writeln('→ 面A 石膏ボード ${stackA.label}')
      ..write(
        sides == WallSides.both
            ? '→ 面B 石膏ボード ${sb.label}'
            : '→ 片面張り',
      );
    return WallThicknessBreakdown(
      finishedThicknessMm: finished,
      centerToOuterAMm: offsetA,
      centerToOuterBMm: offsetB,
      form: form,
      stackA: stackA,
      stackB: sb,
      sides: sides,
      errorMm: 0,
      summaryJa: summary.toString(),
      nearestPreset: preset,
    );
  }

  static WallThicknessBreakdown _searchBest(
    double finished,
    double offsetA,
    double offsetB, {
    BoardStackSpec? hintStackA,
    BoardStackSpec? hintStackB,
  }) {
    WallThicknessBreakdown? best;
    var bestScore = double.infinity;
    final stacks = [
      ...BoardStackSpec.common,
      if (hintStackA != null) hintStackA,
      if (hintStackB != null) hintStackB,
    ];

    for (final form in LgsForm.values) {
      for (final sa in stacks) {
        for (final sb in stacks) {
          for (final sides in WallSides.values) {
            final boardA = sa.totalMm;
            final boardB = sides == WallSides.both ? sb.totalMm : 0.0;
            // 仕上壁厚 = ランナー幅 + ボード（スタッド幅ではない）
            final runnerW = form.studWidthMm;
            final pred = runnerW + boardA + boardB;
            final err = (pred - finished).abs();
            final predA = runnerW / 2 + boardA;
            final predB = sides == WallSides.both
                ? runnerW / 2 + boardB
                : runnerW / 2;
            final errOff =
                (predA - offsetA).abs() + (predB - offsetB).abs();
            var score = err * 2.0 + errOff * 0.5;
            var bias = 0.0;
            if (sa.label == '12.5mm') bias -= 0.6;
            if (sides == WallSides.both && sa.label == sb.label) bias -= 0.3;
            // 非対称ヒント一致を強く優遇
            if (hintStackA != null && sa.label == hintStackA.label) {
              bias -= 2.0;
            }
            if (hintStackB != null &&
                sides == WallSides.both &&
                sb.label == hintStackB.label) {
              bias -= 2.0;
            }
            // 12.5+9.5 のような混層は現場であり得るので過度に罰しない
            if (sa.layersMm.length >= 2 &&
                sa.layersMm.toSet().length > 1) {
              bias -= 0.2;
            }
            if (form == LgsForm.form65) bias -= 0.3;

            final s = score + bias;
            if (s < bestScore) {
              bestScore = s;
              final useB = sides == WallSides.both ? sb : sa;
              final preset = _nearestPreset(form, sa, sides);
              final summary = StringBuffer()
                ..writeln(
                  '仕上壁厚 ${finished.toStringAsFixed(0)}mm '
                  '（芯→A ${offsetA.toStringAsFixed(0)} / 芯→B ${offsetB.toStringAsFixed(0)}）',
                )
                ..writeln(
                  '→ LGS ${form.label}（${form.studCode} ${form.studWidthMm.toStringAsFixed(0)}mm）',
                )
                ..writeln('→ 面A 石膏ボード ${sa.label}')
                ..writeln(
                  sides == WallSides.both
                      ? '→ 面B 石膏ボード ${useB.label}'
                      : '→ 片面張り',
                )
                ..write(
                  '検算 ${pred.toStringAsFixed(1)}mm（誤差 ${err.toStringAsFixed(1)}mm）',
                );
              best = WallThicknessBreakdown(
                finishedThicknessMm: finished,
                centerToOuterAMm: offsetA,
                centerToOuterBMm: offsetB,
                form: form,
                stackA: sa,
                stackB: useB,
                sides: sides,
                errorMm: err,
                summaryJa: summary.toString(),
                nearestPreset: preset,
              );
            }
          }
        }
      }
    }
    return best!;
  }

  static LgsMethodPreset _nearestPreset(
    LgsForm form,
    BoardStackSpec stack,
    WallSides sides,
  ) {
    final board = stack.primaryThickness;
    final layers = stack.asLayersEnum;
    for (final p in LgsCatalog.presets) {
      if (p.form == form &&
          p.boardThickness == board &&
          p.layers == layers &&
          p.sides == sides) {
        return p;
      }
    }
    return LgsMethodPreset(
      id: 'derived_${form.name}_${stack.label}',
      name: '解析（${form.label} / ${stack.label}）',
      description: '線幅・寸法・手動入力から自動分解（混層対応）',
      form: form,
      pitch: stack.layersMm.length >= 2 ? LgsPitch.p455 : LgsPitch.p303,
      boardThickness: board,
      layers: layers,
      sides: sides,
    );
  }
}
