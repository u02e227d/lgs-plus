import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/cross_dedicated_calc.dart';

void main() {
  test('GLパテ 25㎡ → 理論約1.47kg、発注1袋', () {
    final r = CrossDedicatedCalc.pateQty('GLパテ', 25);
    expect(r.kgNeeded, closeTo(25 / 170 * 10, 0.01));
    expect(r.packs, 1);
    expect(r.orderKg, 10);
    expect(r.packUnit, '袋');
  });

  test('Uトップパテ 25㎡（3mm）→ 理論約31.25kg、発注4袋', () {
    final r = CrossDedicatedCalc.pateQty('Uトップパテ', 25);
    expect(r.kgNeeded, closeTo(25 / 8 * 20, 0.01));
    expect(r.packs, 4);
    expect(r.orderKg, 80);
  });

  test('default is GLパテ', () {
    expect(CrossDedicatedCalc.defaultPateName, 'GLパテ');
  });

  test('両面は面積×2', () {
    const cfg = CrossDedicatedConfig(bothSides: true);
    expect(cfg.effectiveAreaM2(12.5), 25);
  });

  test('ファイバーテープ 25㎡×0.9÷45 → 1個', () {
    expect(CrossDedicatedCalc.fiberTapeCount(25, 45), 1);
    expect(CrossDedicatedCalc.fiberTapeCount(60, 45), 2); // 54/45=1.2→2
  });
}
