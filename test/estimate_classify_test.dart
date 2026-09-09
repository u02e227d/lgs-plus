import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/estimate_builder.dart';

EstimateLine line(String name, {String unit = '本', String spec = ''}) =>
    EstimateLine(
      id: '1',
      name: name,
      spec: spec,
      qty: 1,
      unit: unit,
      subtotal: 1,
    );

void main() {
  test('user-reported split', () {
    final all = [
      line('LGS ランナー'),
      line('コの字スタッド'),
      line('グラスウール', unit: 'm'),
      line('ランナースペーサー', unit: '個'),
      line('ロックフェルト', unit: '箱'),
      line('普通ボード', unit: '枚'),
      line('スペーサー', unit: '個'),
      line('タイガーUタイト', unit: '箱'),
    ];
    final board = EstimateBuilder.filterByKind(all, EstimateSheetKind.board);
    final lgs = EstimateBuilder.filterByKind(all, EstimateSheetKind.lgs);

    expect(board.map((e) => e.name).toSet(), {
      'グラスウール',
      'ロックフェルト',
      '普通ボード',
      'タイガーUタイト',
    });
    expect(lgs.map((e) => e.name).toSet(), {
      'LGS ランナー',
      'コの字スタッド',
      'ランナースペーサー',
      'スペーサー',
    });
    expect(board.length + lgs.length, all.length);
  });
}
