import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';
import '../../widgets/lockable_picker.dart';
import 'cross_dedicated_sheet.dart';

enum WallMaterialAction { methodSelect, delete, openCross }

class WallMaterialResult {
  WallMaterialResult({
    required this.method,
    required this.action,
    required this.heightMm,
    this.measuredLengthMm = 0,
  });
  final WallMethod method;
  final WallMaterialAction action;
  final double heightMm;
  /// 基本設定に出した画線長さ（材料選択へそのまま渡す）
  final double measuredLengthMm;
}

/// 材料寸法設定（壁高 / B面ボード / LGS / A面ボード）
class WallMaterialSheet extends StatefulWidget {
  const WallMaterialSheet({
    super.key,
    this.initialMethod,
    this.initialHeightMm,
    this.wallNumber = 1,
    this.measuredLengthMm,
    this.measuredOpeningAreaM2,
    this.ironPlateMeasured = false,
    this.onCrossEstimateSave,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
  });

  final WallMethod? initialMethod;
  final double? initialHeightMm;
  final int wallNumber;
  /// 画線の測定延長 (mm)
  final double? measuredLengthMm;
  /// 紐付け済み開口の合計面積 (㎡)
  final double? measuredOpeningAreaM2;
  /// 鉄板専用で測った線
  final bool ironPlateMeasured;
  final Future<void> Function(EstimateSaveResult result)? onCrossEstimateSave;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;

  @override
  State<WallMaterialSheet> createState() => _WallMaterialSheetState();
}

class _WallMaterialSheetState extends State<WallMaterialSheet> {
  static const boardMms = [
    3.0, 4.0, 5.0, 6.0, 8.0, 9.0, 9.5, 10.0, 12.0, 12.5, 15.0, 21.0,
  ];
  static const lgsMms = [
    20.0, 25.0, 38.0, 40.0, 45.0, 50.0, 65.0, 75.0, 90.0, 100.0,
  ];

  late List<double> _boardB;
  late List<double> _boardA;
  late double _runner;
  late double _stud;
  late final TextEditingController _height;
  late CrossDedicatedConfig _crossDedicated;

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
    _crossDedicated = m?.crossDedicated ?? const CrossDedicatedConfig();
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

  double? get _parsedHeight {
    final h = double.tryParse(_height.text.trim());
    if (h == null || h <= 0) return null;
    return h;
  }

  bool get _needsSpacer => _stud < _runner;

  WallMethod _buildMethod() => _buildMethodFor(_parsedHeight ?? 2700);

  WallMethod _buildMethodFor(double h) {
    final base = widget.initialMethod ?? const WallMethod();
    final keepIron = widget.ironPlateMeasured || base.useIronPlate;

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
      useIronPlate: keepIron,
      ironPlateSegments: keepIron ? base.ironPlateSegmentCount : 1,
      ironPlateWidthMm: base.ironPlateWidthMm > 0 ? base.ironPlateWidthMm : 300,
      ironPlateLengthMm:
          base.ironPlateLengthMm > 0 ? base.ironPlateLengthMm : 1820,
      boardSize: sizesA.isNotEmpty ? sizesA.first : BoardSize.size36,
      boardSizeB: sizesB.isNotEmpty ? sizesB.first : BoardSize.size36,
      boardLayerSizesA: sizesA,
      boardLayerSizesB: sizesB,
      useCross: _crossDedicated.enabled,
      crossWidthM: _crossDedicated.crossWidthM > 0
          ? _crossDedicated.crossWidthM
          : 0.9,
      crossDedicated: _crossDedicated,
    );
  }

  bool get _ready {
    if (_parsedHeight == null) return false;
    return _runner > 0 && _stud > 0;
  }

  WallMaterialResult? _result(WallMaterialAction action) {
    final h = _parsedHeight;
    if (h == null) return null;
    return WallMaterialResult(
      method: _buildMethodFor(h),
      action: action,
      heightMm: h,
      measuredLengthMm: widget.measuredLengthMm ?? 0,
    );
  }

  Future<void> _openCrossDedicated() async {
    final len = widget.measuredLengthMm ?? 0;
    final h = _parsedHeight ?? widget.initialHeightMm ?? 2700;
    final opening = (widget.measuredOpeningAreaM2 ?? 0).clamp(0.0, double.infinity);
    final gross = (len / 1000.0) * (h / 1000.0);
    final area = (gross - opening).clamp(0.0, double.infinity);
    final config = await Navigator.of(context, rootNavigator: true)
        .push<CrossDedicatedConfig>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CrossDedicatedSheet(
          areaM2: area,
          initial: _crossDedicated,
          title: Ms.of(context).crossDedicatedWall,
          showWallFaces: true,
          onSavePersist: widget.onCrossEstimateSave,
          projectName: widget.projectName,
          siteAddress: widget.siteAddress,
          sitePhone: widget.sitePhone,
          siteContact: widget.siteContact,
        ),
      ),
    );
    if (config == null || !mounted) return;
    setState(() => _crossDedicated = config);
  }

  Future<void> _confirmDeleteLine() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).deleteThisLine),
        content: Text(Ms.of(ctx).deleteThisLineQ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(S.of(ctx).deleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.pop(
      context,
      WallMaterialResult(
        method: _buildMethod(),
        action: WallMaterialAction.delete,
        heightMm: _parsedHeight ?? widget.initialHeightMm ?? 2700,
        measuredLengthMm: widget.measuredLengthMm ?? 0,
      ),
    );
  }

  Widget _crossDedicatedButton() {
    final on = _crossDedicated.enabled;
    return FilledButton(
      onPressed: _openCrossDedicated,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1E6BD6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        on ? Ms.of(context).crossDedicatedOn : Ms.of(context).crossDedicated,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
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
    final labels = <String>[Ms.of(context).none, for (final mm in boardMms) _mmLabel(mm)];
    // なし（空）または各層の厚さ
    if (layers.isEmpty) {
      return LockableCupertinoPicker(
        label: Ms.of(context).thickness,
        labels: labels,
        selectedIndex: 0,
        onSelected: (i) {
          if (i <= 0) {
            onChanged([]);
          } else {
            onChanged([boardMms[i - 1]]);
          }
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < layers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          LockableCupertinoPicker(
            label: Ms.of(context).layerN(i + 1),
            labels: labels,
            selectedIndex: () {
              final j = boardMms.indexOf(layers[i]);
              return j >= 0 ? j + 1 : 0;
            }(),
            onSelected: (sel) {
              if (sel <= 0) {
                onChanged([]);
                return;
              }
              final next = [...layers];
              next[i] = boardMms[sel - 1];
              onChanged(next);
            },
          ),
        ],
        Row(
          children: [
            TextButton.icon(
              onPressed: () => onChanged([...layers, layers.last]),
              icon: const Icon(Icons.add_circle, color: AppTheme.navy),
              label: Text(Ms.of(context).addLayer),
            ),
            if (layers.length > 1)
              TextButton.icon(
                onPressed: () =>
                    onChanged(layers.sublist(0, layers.length - 1)),
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.danger),
                label: Text(Ms.of(context).deleteLayer),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return KeyboardDoneScope(
      child: Padding(
        // 全画面シートでもステータスバー（電波・電池）と被らないように下げる
        padding: EdgeInsets.only(top: topInset + 8),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Ms.of(context).basicSettings,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _crossDedicatedButton(),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle(Ms.of(context).wallHeightShort),
                TextField(
                  controller: _height,
                  keyboardType: DoneKeyboard.decimal,
                  inputFormatters: DoneKeyboard.decimalFormatters,
                  textInputAction: DoneKeyboard.action,
                  onSubmitted: DoneKeyboard.onSubmitted,
                  decoration: InputDecoration(
                    labelText: Ms.of(context).heightMm,
                    hintText: '2700',
                    suffixText: 'mm',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(Ms.of(context).faceB),
                    _thicknessRow(
                      layers: _boardB,
                      onChanged: (v) => setState(() => _boardB = v),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('LGS'),
                    LockableCupertinoPicker(
                      label: Ms.of(context).runnerW,
                      labels: [for (final mm in lgsMms) _mmLabel(mm)],
                      selectedIndex:
                          lgsMms.indexOf(_runner).clamp(0, lgsMms.length - 1),
                      onSelected: (i) => setState(() => _runner = lgsMms[i]),
                    ),
                    const SizedBox(height: 8),
                    LockableCupertinoPicker(
                      label: Ms.of(context).studW,
                      labels: [for (final mm in lgsMms) _mmLabel(mm)],
                      selectedIndex:
                          lgsMms.indexOf(_stud).clamp(0, lgsMms.length - 1),
                      onSelected: (i) => setState(() => _stud = lgsMms[i]),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(Ms.of(context).faceA),
                    _thicknessRow(
                      layers: _boardA,
                      onChanged: (v) => setState(() => _boardA = v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: !_ready
                      ? null
                      : () {
                          final r = _result(WallMaterialAction.methodSelect);
                          if (r != null) Navigator.pop(context, r);
                        },
                  child: Text(Ms.of(context).goMaterialPage),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _confirmDeleteLine,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                  ),
                  child: Text(Ms.of(context).deleteThisLine),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.of(context).cancel,
                      style: const TextStyle(color: AppTheme.steel)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
