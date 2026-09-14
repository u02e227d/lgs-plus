import 'package:flutter_test/flutter_test.dart';

import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/opening_reinforce.dart';

void main() {
  test('① 縦2横1・幅850・定尺3000 → 3本', () {
    expect(
      OpeningReinforceCalc.reinforceBars(
        pattern: OpeningReinforcePattern.redH,
        magusaSegments: 1,
        openingWidthMm: 850,
        stockLengthMm: 3000,
      ),
      3,
    );
  });

  test('③ 縦3横2・幅850・定尺2700 → 4本', () {
    expect(
      OpeningReinforceCalc.reinforceBars(
        pattern: OpeningReinforcePattern.redHGreenBlack,
        magusaSegments: 1,
        openingWidthMm: 850,
        stockLengthMm: 2700,
      ),
      4,
    );
  });

  test('④ アングルピース：線5本×2＝10個', () {
    expect(OpeningReinforcePattern.redHGreenBlue.totalLines(1), 5);
    expect(
      OpeningReinforceCalc.anglePieces(
        pattern: OpeningReinforcePattern.redHGreenBlue,
        magusaSegments: 1,
      ),
      10,
    );
  });

  test('開口両端が壁上なら紐付け', () {
    final wall = WallSegment(
      id: 'w1',
      points: const [Point2(0, 0), Point2(4000, 0)],
      heightMm: 2700,
      method: const WallMethod(),
      quantities: const {},
    );
    final opening = WallOpening(
      id: 'o1',
      a: const Point2(1000, 30),
      b: const Point2(1900, 30),
      highlightArgb: 0xFFE53935,
      widthMm: 900,
      heightMm: 2100,
    );
    expect(
      OpeningReinforceCalc.openingNearWall(
        opening: opening,
        wall: wall,
        maxDistPx: 48,
      ),
      isTrue,
    );
  });

  test('まぐさ余り流用：891＋901・定尺2700 → 縦4＋横1＝5本', () {
    // 開口1: 縦2＋まぐさ891（定尺1本・余り1809）
    // 開口2: 縦2＋まぐさ901（余り1809から取得）→ 合計 3+2=5
    final openings = [
      WallOpening(
        id: 'o1',
        a: const Point2(0, 0),
        b: const Point2(891, 0),
        highlightArgb: 0xFFE53935,
        patternName: 'redH',
        widthMm: 891,
        heightMm: 2100,
      ),
      WallOpening(
        id: 'o2',
        a: const Point2(2000, 0),
        b: const Point2(2901, 0),
        highlightArgb: 0xFFE53935,
        patternName: 'redH',
        widthMm: 901,
        heightMm: 2100,
      ),
    ];
    expect(
      OpeningReinforceCalc.reinforceBarsForOpenings(
        openings: openings,
        stockLengthMm: 2700,
      ),
      5,
    );
    // 個別合算だと 3+3=6 になってしまうことの確認
    final alone = openings
        .map(
          (o) => OpeningReinforceCalc.reinforceBars(
            pattern: OpeningReinforcePattern.redH,
            magusaSegments: 1,
            openingWidthMm: o.widthMm,
            stockLengthMm: 2700,
          ),
        )
        .fold<int>(0, (a, b) => a + b);
    expect(alone, 6);
  });
}
