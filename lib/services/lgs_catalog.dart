/// 日本建築現場向け LGS 間仕切工法カタログ（JIS A 6517 / 公共建築工事標準仕様書）
library;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// スタッド形（壁厚の目安）
enum LgsForm {
  form20, // 軽量・部分間仕切
  form25, // 薄壁・下地補助
  form38, // ランナー／軽間仕切
  form40, // 改修・軽間仕切
  form45, // 改修・軽間仕切で多用
  form50, // WS-50 / 高さ〜2.7m / 片面張り向け
  form65, // WS-65 / 〜4.0m 最普及
  form75, // WS-75
  form90, // WS-90 / 〜4.5m
  form100, // WS-100 / 〜5.0m
}

extension LgsFormX on LgsForm {
  String get label {
    switch (this) {
      case LgsForm.form20:
        return '20形';
      case LgsForm.form25:
        return '25形';
      case LgsForm.form38:
        return '38形';
      case LgsForm.form40:
        return '40形';
      case LgsForm.form45:
        return '45形';
      case LgsForm.form50:
        return '50形';
      case LgsForm.form65:
        return '65形';
      case LgsForm.form75:
        return '75形';
      case LgsForm.form90:
        return '90形';
      case LgsForm.form100:
        return '100形';
    }
  }

  /// スタッド幅 A (mm)
  double get studWidthMm {
    switch (this) {
      case LgsForm.form20:
        return 20;
      case LgsForm.form25:
        return 25;
      case LgsForm.form38:
        return 38;
      case LgsForm.form40:
        return 40;
      case LgsForm.form45:
        return 45;
      case LgsForm.form50:
        return 50;
      case LgsForm.form65:
        return 65;
      case LgsForm.form75:
        return 75;
      case LgsForm.form90:
        return 90;
      case LgsForm.form100:
        return 100;
    }
  }

  /// スタッドフランジ B (mm)
  double get studFlangeMm {
    switch (this) {
      case LgsForm.form20:
      case LgsForm.form25:
        return 35;
      case LgsForm.form38:
      case LgsForm.form40:
      case LgsForm.form45:
        return 40;
      default:
        return 45;
    }
  }

  /// ランナー記号・内法幅
  String get runnerCode => 'WR-${studWidthMm.toInt()}';

  double get runnerInnerMm => studWidthMm + 2; // 例: 65→67

  String get studCode => 'WS-${studWidthMm.toInt()}';

  /// 適用高さ目安 (mm)
  double get maxHeightMm {
    switch (this) {
      case LgsForm.form20:
      case LgsForm.form25:
        return 2400;
      case LgsForm.form38:
      case LgsForm.form40:
      case LgsForm.form45:
        return 2700;
      case LgsForm.form50:
        return 2700;
      case LgsForm.form65:
      case LgsForm.form75:
        return 4000;
      case LgsForm.form90:
        return 4500;
      case LgsForm.form100:
        return 5000;
    }
  }

  /// 振れ止め（Cチャン）記号
  String get fureDomeCode {
    switch (this) {
      case LgsForm.form20:
      case LgsForm.form25:
      case LgsForm.form38:
      case LgsForm.form40:
      case LgsForm.form45:
      case LgsForm.form50:
        return 'WB-19';
      case LgsForm.form65:
      case LgsForm.form75:
      case LgsForm.form90:
      case LgsForm.form100:
        return 'WB-25';
    }
  }

  LgsType toLegacyType() =>
      this == LgsForm.form100 ? LgsType.type100 : LgsType.type65;

  static LgsForm fromLegacy(LgsType t) =>
      t == LgsType.type100 ? LgsForm.form100 : LgsForm.form65;

  static LgsForm fromStudWidth(double mm) {
    const forms = LgsForm.values;
    LgsForm best = LgsForm.form65;
    var bestDiff = double.infinity;
    for (final f in forms) {
      final d = (f.studWidthMm - mm).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = f;
      }
    }
    return best;
  }
}

/// 石膏ボード種類（厚み＋品種）
enum GypsumBoardKind {
  pb9_5,
  pb12_5,
  pb15,
  reinforced12_5,
  waterproof12_5,
  fire12_5,
}

extension GypsumBoardKindX on GypsumBoardKind {
  double get thicknessMm {
    switch (this) {
      case GypsumBoardKind.pb9_5:
        return 9.5;
      case GypsumBoardKind.pb12_5:
      case GypsumBoardKind.reinforced12_5:
      case GypsumBoardKind.waterproof12_5:
      case GypsumBoardKind.fire12_5:
        return 12.5;
      case GypsumBoardKind.pb15:
        return 15;
    }
  }

  String get label {
    switch (this) {
      case GypsumBoardKind.pb9_5:
        return '普通PB 9.5mm';
      case GypsumBoardKind.pb12_5:
        return '普通PB 12.5mm';
      case GypsumBoardKind.pb15:
        return '普通PB 15mm';
      case GypsumBoardKind.reinforced12_5:
        return '強化石膏ボード 12.5mm';
      case GypsumBoardKind.waterproof12_5:
        return '耐水石膏ボード 12.5mm';
      case GypsumBoardKind.fire12_5:
        return '耐火石膏ボード 12.5mm';
    }
  }

  BoardThickness get asBoardThickness {
    if (thicknessMm <= 10) return BoardThickness.t9_5;
    if (thicknessMm >= 14) return BoardThickness.t15;
    return BoardThickness.t12_5;
  }

  static GypsumBoardKind fromThickness(double mm) {
    if (mm <= 10) return GypsumBoardKind.pb9_5;
    if (mm >= 14) return GypsumBoardKind.pb15;
    return GypsumBoardKind.pb12_5;
  }
}

/// 壁厚→蛍光ペンハイライト色（視認しやすい半透明系）
class ThicknessHighlight {
  ThicknessHighlight._();

  static Color colorForMm(double? thicknessMm) {
    if (thicknessMm == null || thicknessMm <= 0) {
      return const Color(0xCC0B1F3A);
    }
    // 高彩度蛍光ペン（半透明でも視認しやすい）
    if (thicknessMm < 55) return const Color(0xE6FFEB3B); // 黄
    if (thicknessMm < 75) return const Color(0xE6FF4081); // ピンク
    if (thicknessMm < 95) return const Color(0xE600E676); // 緑
    if (thicknessMm < 115) return const Color(0xE6FF9100); // オレンジ
    if (thicknessMm < 140) return const Color(0xE600B0FF); // 水色
    return const Color(0xE6E040FB); // 紫
  }

  static String labelForMm(double? thicknessMm) {
    if (thicknessMm == null) return '未検出';
    return '壁厚 約 ${thicknessMm.toStringAsFixed(0)}mm';
  }
}

enum StudProfile { channel, square } // コの字 / 角スタッド

enum BoardThickness {
  t9_5, // 9.5mm
  t12_5, // 12.5mm 最普及
  t15, // 15mm
  t21, // 21mm
}

extension BoardThicknessX on BoardThickness {
  double get mm {
    switch (this) {
      case BoardThickness.t9_5:
        return 9.5;
      case BoardThickness.t12_5:
        return 12.5;
      case BoardThickness.t15:
        return 15;
      case BoardThickness.t21:
        return 21;
    }
  }

  String get label {
    switch (this) {
      case BoardThickness.t9_5:
        return '9.5mm';
      case BoardThickness.t12_5:
        return '12.5mm';
      case BoardThickness.t15:
        return '15mm';
      case BoardThickness.t21:
        return '21mm';
    }
  }
}

enum WallSides { single, both } // 片面 / 両面張り

/// 現場で選ぶ標準工法プリセット
class LgsMethodPreset {
  final String id;
  final String name;
  final String description;
  final LgsForm form;
  final StudProfile profile;
  final LgsPitch pitch;
  final BoardSize boardSize;
  final BoardThickness boardThickness;
  final BoardLayers layers;
  final WallSides sides;
  final bool useSpacer;
  final bool useFureDome;
  final bool useCross;

  const LgsMethodPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.form,
    this.profile = StudProfile.channel,
    required this.pitch,
    this.boardSize = BoardSize.size36,
    this.boardThickness = BoardThickness.t12_5,
    this.layers = BoardLayers.single,
    this.sides = WallSides.both,
    this.useSpacer = true,
    this.useFureDome = true,
    this.useCross = false,
  });

  /// 仕上がり壁厚概算 = ランナー幅 + ボード×層×面
  double get finishedThicknessMm {
    final board = boardThickness.mm *
        layers.count *
        (sides == WallSides.both ? 2 : 1);
    return form.studWidthMm + board;
  }
}

class LgsCatalog {
  LgsCatalog._();

  /// 公共建築・現場で多用されるピッチ
  static const double pitchSingleBoardMm = 303; // 1枚張り直張り
  static const double pitchDoubleBoardMm = 455; // 下地張り・2枚張り

  static const presets = <LgsMethodPreset>[
    LgsMethodPreset(
      id: 'office_65_1',
      name: '一般間仕切（65形・1枚張り）',
      description: 'WS-65 + WR-65、スタッド@303、PB12.5両面1層。オフィス・店舗の標準。',
      form: LgsForm.form65,
      pitch: LgsPitch.p303,
      layers: BoardLayers.single,
      sides: WallSides.both,
      useFureDome: true,
    ),
    LgsMethodPreset(
      id: 'office_65_2',
      name: '遮音・耐火寄（65形・2枚張り）',
      description: 'WS-65、スタッド@455、PB12.5両面2層。遮音・防火強化。',
      form: LgsForm.form65,
      pitch: LgsPitch.p455,
      layers: BoardLayers.double,
      sides: WallSides.both,
      useFureDome: true,
    ),
    LgsMethodPreset(
      id: 'thin_50',
      name: '薄壁（50形・片面）',
      description: 'WS-50、高さ2.7m以下・片面ボード向け。',
      form: LgsForm.form50,
      pitch: LgsPitch.p303,
      layers: BoardLayers.single,
      sides: WallSides.single,
      useFureDome: true,
    ),
    LgsMethodPreset(
      id: 'tall_100',
      name: '高壁（100形）',
      description: 'WS-100 + WR-100、高さ4.5〜5.0m。吹抜け・倉庫系。',
      form: LgsForm.form100,
      pitch: LgsPitch.p455,
      layers: BoardLayers.single,
      sides: WallSides.both,
      useFureDome: true,
    ),
    LgsMethodPreset(
      id: 'square_65',
      name: '角スタッド65（振れ止め不要）',
      description: '角スタッド65×45。振れ止め省略可。DIY・改修で多用。',
      form: LgsForm.form65,
      profile: StudProfile.square,
      pitch: LgsPitch.p303,
      layers: BoardLayers.single,
      sides: WallSides.both,
      useSpacer: false,
      useFureDome: false,
    ),
    LgsMethodPreset(
      id: 'wet_75',
      name: '水回り寄（75形）',
      description: 'WS-75。配管スペースを確保したい壁。',
      form: LgsForm.form75,
      pitch: LgsPitch.p455,
      boardThickness: BoardThickness.t12_5,
      layers: BoardLayers.single,
      sides: WallSides.both,
    ),
  ];

  static LgsMethodPreset? byId(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 検出／手動入力の壁厚(mm)から推奨プリセット
  static LgsMethodPreset suggestFromThickness(double wallThicknessMm) {
    // WallThicknessAnalyzer と同じ分解ロジックを使う
    // （循環 import を避けるためここは簡易式も残す）
    final studGuess = wallThicknessMm - 25;
    final form = LgsFormX.fromStudWidth(studGuess.clamp(20, 100));
    for (final p in presets) {
      if (p.form == form &&
          p.layers == BoardLayers.single &&
          p.sides == WallSides.both) {
        return p;
      }
    }
    for (final p in presets) {
      if (p.form == form) return p;
    }
    return presets.first;
  }

  /// 定尺長さ候補 (mm)
  static const stockLengthsMm = <int>[
    1000, 2000, 2500, 2700, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 8000,
    10000, 12000, 15000,
  ];
}
