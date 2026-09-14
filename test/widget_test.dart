import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/services/calc_engine.dart';
import 'package:lgs_plus/models/models.dart';

void main() {
  test('壁算量：Stud本数と面積', () {
    // 4500mm 壁 @450 → stud = 11
    final qty = CalcEngine.calcWall(
      a: const Point2(0, 0),
      b: const Point2(4500, 0),
      heightMm: 2700,
      scalePxPerMm: 1,
      method: const WallMethod(
        useLgs: true,
        pitch: LgsPitch.p450,
        useBoard: true,
        useCross: false,
      ),
    );
    expect(qty['wall_length_mm'], 4500);
    expect(qty['wall_area_m2'], closeTo(12.15, 0.01));
    expect(qty['stud_count'], 11);
    expect(qty['runner_m'], 9);
  });

  test('壁面積は開口を控除する', () {
    final opening = WallOpening(
      id: 'o1',
      a: const Point2(1000, 0),
      b: const Point2(1900, 0),
      highlightArgb: 0xFFE53935,
      widthMm: 900,
      heightMm: 2100,
    );
    final qty = CalcEngine.calcWall(
      a: const Point2(0, 0),
      b: const Point2(4500, 0),
      heightMm: 2700,
      scalePxPerMm: 1,
      method: const WallMethod(
        useLgs: true,
        pitch: LgsPitch.p450,
        useBoard: false,
        useCross: false,
      ),
      openings: [opening],
    );
    // 総 12.15 − 開口 1.89 = 10.26
    expect(qty['wall_gross_area_m2'], closeTo(12.15, 0.01));
    expect(qty['opening_area_m2'], closeTo(1.89, 0.01));
    expect(qty['wall_net_area_m2'], closeTo(10.26, 0.01));
    expect(qty['wall_area_m2'], closeTo(10.26, 0.01));
  });

  test('曲がり角ではLGSを3本計上', () {
    // L字：3000 + 3000、角1つ
    final qty = CalcEngine.calcWall(
      points: const [
        Point2(0, 0),
        Point2(3000, 0),
        Point2(3000, 3000),
      ],
      heightMm: 2700,
      scalePxPerMm: 1,
      method: const WallMethod(
        useLgs: true,
        pitch: LgsPitch.p450,
        useBoard: false,
        useCross: false,
      ),
    );
    expect(qty['corner_count'], 1);
    expect(qty['corner_studs'], 3);
    // 各区間 floor(3000/450)+1=7、合計14、角調整 -1+2 → 15
    expect(qty['stud_count'], 15);
  });

  test('天井面積（正方形）', () {
    final pts = [
      const Point2(0, 0),
      const Point2(3640, 0),
      const Point2(3640, 3640),
      const Point2(0, 3640),
    ];
    final qty = CalcEngine.calcCeiling(
      points: pts,
      scalePxPerMm: 1,
      method: const CeilingMethod(),
    );
    expect(qty['ceiling_area_m2'], closeTo(13.2496, 0.01));
  });
}
