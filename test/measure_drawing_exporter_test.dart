import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/measure_drawing_exporter.dart';

void main() {
  test('未測定は書き出し対象にしない', () {
    final empty = Measurement(
      id: 'm1',
      projectId: 'p',
      drawingId: 'd',
      name: '空',
    );
    expect(MeasureDrawingExporter.hasContent(empty), isFalse);
  });

  test('壁・天井があれば書き出し対象', () {
    final wall = Measurement(
      id: 'm2',
      projectId: 'p',
      drawingId: 'd',
      name: '壁',
      walls: [
        WallSegment(
          id: 'w1',
          points: const [Point2(0, 0), Point2(100, 0)],
          heightMm: 2700,
          method: const WallMethod(),
          quantities: const {},
        ),
      ],
    );
    expect(MeasureDrawingExporter.hasContent(wall), isTrue);

    final ceil = Measurement(
      id: 'm3',
      projectId: 'p',
      drawingId: 'd',
      name: '天井',
      ceilings: [
        CeilingRegion(
          id: 'c1',
          points: const [Point2(0, 0), Point2(10, 0), Point2(10, 10)],
          method: const CeilingMethod(),
          quantities: const {},
        ),
      ],
    );
    expect(MeasureDrawingExporter.hasContent(ceil), isTrue);
  });
}
