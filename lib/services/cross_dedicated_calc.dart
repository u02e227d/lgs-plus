/// クロス専用：パテ施工面積・包装から数量を算出
class PatePackSpec {
  const PatePackSpec({
    required this.name,
    required this.packKg,
    required this.coverageM2,
    required this.packUnit,
    this.note = '',
  });

  final String name;
  final double packKg;
  final double coverageM2; // 1包装あたり施工面積
  final String packUnit; // 袋 / 缶 / 箱
  final String note;
}

class PateQtyResult {
  const PateQtyResult({
    required this.kgNeeded,
    required this.packs,
    required this.orderKg,
    required this.packUnit,
    required this.packKg,
    required this.coverageM2,
  });

  /// 理論必要量 (kg)＝面積÷施工面積×包装kg（切上げ前）
  final double kgNeeded;
  /// 発注包装数（切上げ）
  final double packs;
  /// 発注換算の総kg＝包装数×包装kg
  final double orderKg;
  final String packUnit;
  final double packKg;
  final double coverageM2;

  /// 画面「必要量」＝理論kg
  double get kg => kgNeeded;
}

class CrossDedicatedCalc {
  CrossDedicatedCalc._();

  static const crossWidthM = 0.9;
  static const pasteMetersPerKg = 10.0; // 10m = 1kg

  /// メーカー目安（クロス下地は薄塗り前提）
  static const pateSpecs = <PatePackSpec>[
    PatePackSpec(
      name: 'GLパテ',
      packKg: 10,
      coverageM2: 170,
      packUnit: '袋',
      note: '10kg袋／約170㎡（16kg箱は約270㎡）・クロス下地の標準',
    ),
    PatePackSpec(
      name: 'UPパテ',
      packKg: 10,
      coverageM2: 150,
      packUnit: '袋',
      note: '10kg袋／約150㎡',
    ),
    PatePackSpec(
      name: 'Fトップパテ',
      packKg: 10,
      coverageM2: 150,
      packUnit: '袋',
      note: '10kg袋／約150㎡',
    ),
    PatePackSpec(
      name: 'タイガーパテ',
      packKg: 16,
      coverageM2: 300,
      packUnit: '箱',
      note: '16kg箱／約300㎡（4kg袋≈75㎡）',
    ),
    PatePackSpec(
      name: 'タイガーハイクリンパテ SP',
      packKg: 10,
      coverageM2: 150,
      packUnit: '袋',
      note: '10kg袋／約150㎡',
    ),
    PatePackSpec(
      name: 'SPパテ',
      packKg: 20,
      coverageM2: 150,
      packUnit: 'ケース',
      note: '乾燥型上塗り・概算150㎡/20kg',
    ),
    PatePackSpec(
      name: 'タイガージョイントセメント（粉末）',
      packKg: 10,
      coverageM2: 135,
      packUnit: '袋',
      note: '10kg袋／約120〜150㎡（中間135㎡）',
    ),
    PatePackSpec(
      name: 'タイガージョイントセメント（ペースト）',
      packKg: 20,
      coverageM2: 160,
      packUnit: '缶',
      note: '20kg缶／約160㎡',
    ),
    PatePackSpec(
      name: 'ライトパテ（ペースト）',
      packKg: 16,
      coverageM2: 160,
      packUnit: '缶',
      note: '16kg缶／約160㎡',
    ),
    PatePackSpec(
      name: 'Uトップパテ',
      packKg: 20,
      coverageM2: 8, // 3mm薄塗り（5mmは約5㎡→厚塗り用途）
      packUnit: '袋',
      note: '20kg袋／約8㎡(3mm薄塗)。5mm厚塗りは約5㎡/袋（せっこうプラスター）',
    ),
    PatePackSpec(
      name: 'Uライト',
      packKg: 7,
      coverageM2: 80,
      packUnit: '袋',
      note: '軽量下塗り・メーカー要領書準拠（概算80㎡/7kg）',
    ),
    PatePackSpec(
      name: 'Fライト',
      packKg: 7,
      coverageM2: 80,
      packUnit: '袋',
      note: '上塗り軽量・概算80㎡/7kg',
    ),
  ];

  static List<String> get patePresetNames => [
        for (final s in pateSpecs) s.name,
      ];

  static const defaultPateName = 'GLパテ';

  static PatePackSpec? specOf(String name) {
    final n = name.trim();
    for (final s in pateSpecs) {
      if (s.name == n) return s;
    }
    if (n.contains('ユートップ') || n == 'Uトップ') {
      return pateSpecs.firstWhere((e) => e.name == 'Uトップパテ');
    }
    return null;
  }

  /// カスタムは GLパテ相当で概算
  static PatePackSpec resolveSpec(String name) {
    return specOf(name) ??
        const PatePackSpec(
          name: 'パテ',
          packKg: 10,
          coverageM2: 150,
          packUnit: '袋',
          note: 'カスタム概算（10kg／150㎡）',
        );
  }

  static double crossMeters(double areaM2, {double widthM = crossWidthM}) {
    final w = widthM > 0 ? widthM : crossWidthM;
    if (areaM2 <= 0 || w <= 0) return 0;
    return areaM2 / w;
  }

  static double pasteKg(double crossMeters) {
    if (crossMeters <= 0) return 0;
    return crossMeters / pasteMetersPerKg;
  }

  /// ファイバーテープ本数。
  /// 必要延長＝面積㎡ × 0.9m、÷定尺長さで切上げ。
  static double fiberTapeCount(double areaM2, double tapeLengthM) {
    if (areaM2 <= 0 || tapeLengthM <= 0) return 0;
    return ((areaM2 * 0.9) / tapeLengthM).ceilToDouble();
  }

  /// ① 理論kg＝面積÷施工㎡×包装kg
  /// ② 発注包装＝ceil(面積÷施工㎡)（袋・缶へ切上げ）
  static PateQtyResult pateQty(String name, double areaM2) {
    final s = resolveSpec(name);
    if (areaM2 <= 0 || s.coverageM2 <= 0 || s.packKg <= 0) {
      return PateQtyResult(
        kgNeeded: 0,
        packs: 0,
        orderKg: 0,
        packUnit: s.packUnit,
        packKg: s.packKg,
        coverageM2: s.coverageM2,
      );
    }
    final kgNeeded = areaM2 / s.coverageM2 * s.packKg;
    final packs = (areaM2 / s.coverageM2).ceilToDouble();
    return PateQtyResult(
      kgNeeded: kgNeeded,
      packs: packs,
      orderKg: packs * s.packKg,
      packUnit: s.packUnit,
      packKg: s.packKg,
      coverageM2: s.coverageM2,
    );
  }
}
