import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';

enum WallMaterialAction { methodSelect, delete }

class WallMaterialResult {
  WallMaterialResult({
    required this.method,
    required this.action,
    required this.heightMm,
  });
  final WallMethod method;
  final WallMaterialAction action;
  final double heightMm;
}

/// 材料寸法設定（壁高 / B面ボード / LGS / A面ボード）
class WallMaterialSheet extends StatefulWidget {
  const WallMaterialSheet({
    super.key,
    this.initialMethod,
    this.initialHeightMm,
    this.wallNumber = 1,
    this.measuredLengthMm,
  });

  final WallMethod? initialMethod;
  final double? initialHeightMm;
  final int wallNumber;
  /// 画線の測定延長 (mm)
  final double? measuredLengthMm;

  @override
  State<WallMaterialSheet> createState() => _WallMaterialSheetState();
}

class _WallMaterialSheetState extends State<WallMaterialSheet> {
  static const boardMms = [
    3.0, 4.0, 5.0, 6.0, 8.0, 9.0, 9.5, 10.0, 12.0, 12.5, 15.0, 21.0,
  ];
  static const lgsMms = [
    20.0, 25.0, 40.0, 45.0, 50.0, 65.0, 75.0, 90.0, 100.0,
  ];

  late List<double> _boardB;
  late List<double> _boardA;
  late double _runner;
  late double _stud;
  late bool _useIronPlate;
  /// null＝なし、2〜7＝段数
  int? _ironPlateSegments;
  late final TextEditingController _height;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMethod;
    _boardB = _parseStack(m?.boardStackB) ?? [];
    _boardA = _parseStack(m?.boardStackA) ?? [];
    _stud = m?.studWidthMm ?? 45;
    if (!lgsMms.contains(_stud)) {
      _stud = _nearest(lgsMms, _stud);
    }
    _runner = m?.runnerWidthMm ?? _stud;
    if (!lgsMms.contains(_runner)) {
      _runner = _nearest(lgsMms, _runner);
    }
    _useIronPlate = m?.useIronPlate ?? false;
    final seg = m?.ironPlateSegments ?? 0;
    _ironPlateSegments = (seg >= 2 && seg <= 7) ? seg : null;
    final h = widget.initialHeightMm ?? 2700;
    _height = TextEditingController(
      text: h == h.roundToDouble()
          ? h.toStringAsFixed(0)
          : h.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  List<double>? _parseStack(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final out = <double>[];
    for (final p in raw.replaceAll('＋', '+').split('+')) {
      final v = double.tryParse(p.trim());
      if (v != null && v > 0) out.add(v);
    }
    return out.isEmpty ? null : out;
  }

  double _nearest(List<double> opts, double v) {
    var best = opts.first;
    var d = (v - best).abs();
    for (final o in opts) {
      final dd = (o - v).abs();
      if (dd < d) {
        d = dd;
        best = o;
      }
    }
    return best;
  }

  String _stackOf(List<double> layers) {
    if (layers.isEmpty) return '';
    return layers
        .map((e) =>
            e == e.roundToDouble() ? e.toStringAsFixed(0) : e.toStringAsFixed(1))
        .join('+');
  }

  String _mmLabel(double mm) =>
      mm == mm.roundToDouble() ? '${mm.toStringAsFixed(0)}mm' : '${mm}mm';

  String get _measuredLengthLabel {
    final mm = widget.measuredLengthMm ?? 0;
    if (mm <= 0) return '—';
    if (mm >= 1000) {
      final m = mm / 1000.0;
      return m == m.roundToDouble()
          ? '${m.toStringAsFixed(0)} m'
          : '${m.toStringAsFixed(2)} m';
    }
    return mm == mm.roundToDouble()
        ? '${mm.toStringAsFixed(0)} mm'
        : '${mm.toStringAsFixed(1)} mm';
  }

  void _setIronPlate(bool on) {
    setState(() {
      _useIronPlate = on;
      if (on) {
        // 鉄板ON → A/B面ボード・LGS をオフ
        _boardA = [];
        _boardB = [];
      } else {
        _ironPlateSegments = null;
      }
    });
  }

  double? get _parsedHeight {
    final h = double.tryParse(_height.text.trim());
    if (h == null || h <= 0) return null;
    return h;
  }

  bool get _needsSpacer => !_useIronPlate && _stud < _runner;

  WallMethod _buildMethod() => _buildMethodFor(_parsedHeight ?? 2700);

  WallMethod _buildMethodFor(double h) {
    final base = widget.initialMethod ?? const WallMethod();
    if (_useIronPlate) {
      return base.copyWith(
        useLgs: false,
        useBoard: false,
        useBoardFaceA: false,
        useBoardFaceB: false,
        bothSides: false,
        boardStackA: '',
        boardStackB: '',
        boardLayerSizesA: const [],
        boardLayerSizesB: const [],
        studLengthMm: h,
        useSpacer: false,
        useFureDome: false,
        useRockFelt: false,
        useTigerUtight: false,
        useGlassWool: false,
        useCross: false,
        useIronPlate: true,
        ironPlateSegments: _ironPlateSegments ?? 0,
        ironPlateWidthMm: base.ironPlateWidthMm > 0 ? base.ironPlateWidthMm : 300,
        ironPlateLengthMm:
            base.ironPlateLengthMm > 0 ? base.ironPlateLengthMm : 1820,
      );
    }

    final stackA = _stackOf(_boardA);
    final stackB = _stackOf(_boardB);
    final totalA = _boardA.fold(0.0, (s, e) => s + e);
    final totalB = _boardB.fold(0.0, (s, e) => s + e);
    final studCode = _stud == _stud.roundToDouble()
        ? _stud.toStringAsFixed(0)
        : _stud.toStringAsFixed(1);
    final sizesA = [
      for (final th in _boardA)
        (th - 21).abs() < 0.05 ? BoardSize.size26 : BoardSize.size36,
    ];
    final sizesB = [
      for (final th in _boardB)
        (th - 21).abs() < 0.05 ? BoardSize.size26 : BoardSize.size36,
    ];
    final needSp = _needsSpacer;
    return base.copyWith(
      useLgs: true,
      useBoard: _boardA.isNotEmpty || _boardB.isNotEmpty,
      useBoardFaceA: _boardA.isNotEmpty,
      useBoardFaceB: _boardB.isNotEmpty,
      bothSides: _boardB.isNotEmpty,
      runnerWidthMm: _runner,
      lgsFormCode: studCode,
      lgsCoreSpec: '$studCode+',
      studLengthMm: h,
      boardStackA: stackA.isEmpty ? '' : '$stackA+',
      boardStackB: stackB.isEmpty ? '' : '$stackB+',
      boardThicknessMm: _boardA.isNotEmpty ? _boardA.first : 12.5,
      boardThicknessAMm: totalA > 0 ? totalA : null,
      boardThicknessBMm: totalB > 0 ? totalB : null,
      boardKindA: '普通PB',
      boardKindB: '普通PB',
      layers: BoardLayersX.fromCount(
        _boardA.isEmpty ? 1 : _boardA.length,
      ),
      useSpacer: needSp,
      useFureDome: !needSp,
      useRockFelt: needSp ? true : base.useRockFelt,
      useTigerUtight: needSp ? true : base.useTigerUtight,
      useIronPlate: false,
      ironPlateSegments: 0,
      boardSize: sizesA.isNotEmpty ? sizesA.first : BoardSize.size36,
      boardSizeB: sizesB.isNotEmpty ? sizesB.first : BoardSize.size36,
      boardLayerSizesA: sizesA,
      boardLayerSizesB: sizesB,
    );
  }

  bool get _ready {
    if (_parsedHeight == null) return false;
    if (_useIronPlate) return true;
    return _runner > 0 && _stud > 0;
  }

  WallMaterialResult? _result(WallMaterialAction action) {
    final h = _parsedHeight;
    if (h == null) return null;
    return WallMaterialResult(
      method: _buildMethodFor(h),
      action: action,
      heightMm: h,
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      );

  Widget _thicknessRow({
    required List<double> layers,
    required ValueChanged<List<double>> onChanged,
  }) {
    // なし（空）または各層の厚さ
    if (layers.isEmpty) {
      return DropdownButton<double?>(
        value: null,
        hint: const Text('なし'),
        items: [
          const DropdownMenuItem<double?>(
            value: null,
            child: Text('なし'),
          ),
          for (final mm in boardMms)
            DropdownMenuItem<double?>(
              value: mm,
              child: Text(_mmLabel(mm)),
            ),
        ],
        onChanged: (v) {
          if (v == null) {
            onChanged([]);
          } else {
            onChanged([v]);
          }
        },
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < layers.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            DropdownButton<double?>(
              value: layers[i],
              items: [
                const DropdownMenuItem<double?>(
                  value: null,
                  child: Text('なし'),
                ),
                for (final mm in boardMms)
                  DropdownMenuItem<double?>(
                    value: mm,
                    child: Text(_mmLabel(mm)),
                  ),
              ],
              onChanged: (v) {
                if (v == null) {
                  // なし → 全層クリア
                  onChanged([]);
                  return;
                }
                final next = [...layers];
                next[i] = v;
                onChanged(next);
              },
            ),
            if (i == layers.length - 1) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: '層を追加',
                onPressed: () => onChanged([...layers, layers.last]),
                icon: const Icon(Icons.add_circle, color: AppTheme.navy),
              ),
            ],
            if (layers.length > 1 && i == layers.length - 1)
              IconButton(
                tooltip: '層を削除',
                onPressed: () =>
                    onChanged(layers.sublist(0, layers.length - 1)),
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.danger),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '材料寸法設定  #${widget.wallNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('壁高さ'),
              TextField(
                controller: _height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '壁高さ (mm)',
                  hintText: '例: 2700',
                  suffixText: 'mm',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '鉄板',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  if (_useIronPlate) ...[
                    Text(
                      _measuredLengthLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '×',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DropdownButton<int?>(
                      value: _ironPlateSegments,
                      hint: const Text('無', style: TextStyle(fontSize: 13)),
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('無'),
                        ),
                        for (var n = 2; n <= 7; n++)
                          DropdownMenuItem<int?>(
                            value: n,
                            child: Text('$n段'),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _ironPlateSegments = v),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Checkbox(
                    value: _useIronPlate,
                    onChanged: (v) => _setIronPlate(v ?? false),
                  ),
                ],
              ),
              if (_useIronPlate)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '鉄板ON：A面・B面ボードとLGSをオフ。工法は鉄板のみ積算',
                    style: TextStyle(fontSize: 11, color: AppTheme.steel),
                  ),
                ),
              const SizedBox(height: 8),
              IgnorePointer(
                ignoring: _useIronPlate,
                child: Opacity(
                  opacity: _useIronPlate ? 0.35 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('B面ボード'),
                      _thicknessRow(
                        layers: _boardB,
                        onChanged: (v) => setState(() => _boardB = v),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('LGS'),
                      if (_useIronPlate)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'なし（オフ）',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.steel,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ランナー幅',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  DropdownButton<double>(
                                    isExpanded: true,
                                    value: _runner,
                                    items: [
                                      for (final mm in lgsMms)
                                        DropdownMenuItem(
                                          value: mm,
                                          child: Text(_mmLabel(mm)),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _runner = v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('スタッド',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  DropdownButton<double>(
                                    isExpanded: true,
                                    value: _stud,
                                    items: [
                                      for (final mm in lgsMms)
                                        DropdownMenuItem(
                                          value: mm,
                                          child: Text(_mmLabel(mm)),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _stud = v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      _sectionTitle('A面ボード'),
                      _thicknessRow(
                        layers: _boardA,
                        onChanged: (v) => setState(() => _boardA = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: !_ready
                    ? null
                    : () {
                        final r = _result(WallMaterialAction.methodSelect);
                        if (r != null) Navigator.pop(context, r);
                      },
                child: const Text('工法選択 → 試算表'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    WallMaterialResult(
                      method: _buildMethod(),
                      action: WallMaterialAction.delete,
                      heightMm: _parsedHeight ??
                          widget.initialHeightMm ??
                          2700,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                ),
                child: const Text('この線を削除'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル',
                    style: TextStyle(color: AppTheme.steel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
