import 'package:flutter_test/flutter_test.dart';

import 'package:lgs_plus/models/models.dart';

void main() {
  test('現場名・図面・比例尺の toMap/fromMap が保持される', () {
    final project = SiteProject(
      id: 'p1',
      name: 'テスト現場A',
      address: '東京都',
      contactName: '担当',
      phone: '03-0000-0000',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    final p2 = SiteProject.fromMap(project.toMap());
    expect(p2.name, 'テスト現場A');
    expect(p2.address, '東京都');
    expect(p2.id, 'p1');

    final drawing = DrawingFile(
      id: 'd1',
      projectId: 'p1',
      localPath: '/tmp/plan.pdf',
      fileName: 'plan.pdf',
      kind: 'pdf',
      scalePxPerMm: null,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 6),
    );
    final dSaved = drawing.copyWith(scalePxPerMm: 2.5);
    final d2 = DrawingFile.fromMap(dSaved.toMap());
    expect(d2.fileName, 'plan.pdf');
    expect(d2.localPath, '/tmp/plan.pdf');
    expect(d2.projectId, 'p1');
    expect(d2.scalePxPerMm, 2.5);

    final map = dSaved.toMap();
    expect(map['scale_px_per_mm'], 2.5);
    expect(map['file_name'], 'plan.pdf');
    expect(project.toMap()['name'], 'テスト現場A');
  });
}
