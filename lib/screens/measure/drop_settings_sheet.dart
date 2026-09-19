import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../services/drop_calc.dart';
import '../../services/estimate_builder.dart';
import '../../services/lgs_catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';
import '../../widgets/lockable_picker.dart';
import 'estimate_table_screen.dart';

const _kBoardNameCustom = 'カスタム入力';
const _kBoardNames = [
  _kBoardNameCustom,
  'ケイカルVカット',
  'ケイカル平',
  'タイガーボード',
  'タイガー防水ボード',
  'タイガー不燃防水ボード',
  'ソーラトン平板',
  'ソーラトン・スカット',
  'ソーラトン キューブ',
  'ソーラトンライト・ワイド',
  'ダイケトン',
  'タイガージプトーン・ライト',
  'タイガースクエアート',
  'タイガーマーブルトーン・ライト',
  'タイガーハイクリンジプトーン・ライト',
  'タイガーハイクリンマーブルトーン・ライト',
  'タイガーステラート・ライト',
  '防カビジプトーン',
  'タイガージプトーン・ウルトラライト',
  'タイガースクエアトーン・Dプラス',
  '不燃ニュータイガートーン',
];

const _kBoardSizeOpts = <(String label, double wMm, double hMm)>[
  ('300mm×600mm', 300, 600),
  ('455mm×910mm', 455, 910),
  ('3×3', 910, 910),
  ('2×6', 606, 1820),
  ('3×6', 910, 1820),
  ('3×8', 910, 2420),
  ('3×9', 910, 2730),
];

const _kBoardThicknesses = [
  4.0,
  5.0,
  6.0,
  8.0,
  9.0,
  9.5,
  10.0,
  12.0,
  12.5,
  15.0,
  21.0,
];

enum DropSettingsAction { save, estimate, delete }

class DropSettingsResult {
  DropSettingsResult({
    required this.action,
    required this.lengthMm,
    required this.widthMm,
    required this.heightMm,
    required this.method,
    this.turnWidths = const [],
  });
  final DropSettingsAction action;
  final double lengthMm;
  final double widthMm;
  final double heightMm;
  final List<DropTurnWidth> turnWidths;
  final DropMethod method;
}

/// 下り設定（寸法・工法・形状）
class DropSettingsSheet extends StatefulWidget {
  const DropSettingsSheet({
    super.key,
    required this.initialLengthMm,
    required this.initialWidthMm,
    this.initialHeightMm = 300,
    this.initialTurnWidths = const [],
    this.initialPoints = const [],
    this.scalePxPerMm = 0,
    this.initialMethod = const DropMethod(),
    this.allowDelete = false,
    this.groupNumber = 1,
    this.onEstimatePersist,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
  });

  final double initialLengthMm;
  final double initialWidthMm;
  final double initialHeightMm;
  final List<DropTurnWidth> initialTurnWidths;
  final List<Point2> initialPoints;
  final double scalePxPerMm;
  final DropMethod initialMethod;
  final bool allowDelete;
  final int groupNumber;
  final Future<void> Function(EstimateSaveResult result)? onEstimatePersist;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;

  @override
  State<DropSettingsSheet> createState() => _DropSettingsSheetState();
}

class _DropSettingsSheetState extends State<DropSettingsSheet> {
  static const _studTypes = ['4020', '4025', '4040', '4045', '6545'];
  static const _pitches = [303.0, 455.0];
  static const _runnerHeights = [20.0, 25.0];
  static const _barHeights = [19.0, 25.0];
  static const _ukeWidths = [19.0, 25.0, 38.0, 40.0];
  static const _clipUkeWidths = [19.0, 25.0, 38.0, 40.0];
  static const _stockPresets = [3000.0, 4000.0, 5000.0];

  late final TextEditingController _length;
  late final TextEditingController _width;
  late final TextEditingController _height;
  late DropShape _shape;
  late CeilingSystemKind _system;
  late double _runnerWidth;
  late double _runnerLength;
  late String _studType;
  late double _pitch;
  late double _studWidth;
  late double _studLength;
  late double _runnerHeight;
  late double _wBarHeight;
  late double _wBarLength;
  late double _singleBarHeight;
  late double _singleBarLength;
  late double _channelWidth;
  late double _channelLength;
  late double _wClipUkeWidth;
  late double _singleClipUkeWidth;
  final List<_DropBoardLayerState> _boardLayers = [];
  var _mismatchDialogBusy = false;
  var _idSeq = 0;

  List<double> get _lgsWidths => [
        for (final f in LgsForm.values) f.studWidthMm,
      ];

  @override
  void initState() {
    super.initState();
    final m = widget.initialMethod;
    _length = TextEditingController(
      text: widget.initialLengthMm.round().toString(),
    );
    _width = TextEditingController(
      text: widget.initialWidthMm.round().toString(),
    );
    _height = TextEditingController(
      text: widget.initialHeightMm.round().toString(),
    );
    _shape = m.shape;
    _system = m.system;
    _runnerWidth = _nearest(_lgsWidths, m.runnerWidthMm, 45);
    _runnerLength = m.runnerLengthMm > 0 ? m.runnerLengthMm : 4000;
    _studType = _studTypes.contains(m.studType) ? m.studType : '4045';
    _pitch = _pitches.contains(m.pitchMm) ? m.pitchMm : 303;
    _studWidth = _nearest(_lgsWidths, m.studWidthMm, 45);
    _studLength = m.studLengthMm > 0 ? m.studLengthMm : 2800;
    final runnerH = DropMethod.normalizeRunnerHeight(m.runnerHeightMm);
    _runnerHeight =
        _runnerHeights.contains(runnerH) ? runnerH : 20;
    final wBar = DropMethod.normalizeBarHeight(m.wBarHeightMm);
    _wBarHeight = _barHeights.contains(wBar)
        ? wBar
        : DropMethod.barHeightForRunner(_runnerHeight);
    _wBarLength = m.wBarLengthMm > 0 ? m.wBarLengthMm : 4000;
    final sBar = DropMethod.normalizeBarHeight(m.singleBarHeightMm);
    _singleBarHeight = _barHeights.contains(sBar)
        ? sBar
        : DropMethod.barHeightForRunner(_runnerHeight);
    _singleBarLength = m.singleBarLengthMm > 0 ? m.singleBarLengthMm : 4000;
    _channelWidth =
        _ukeWidths.contains(m.channelWidthMm) ? m.channelWidthMm : 38;
    _channelLength = m.channelLengthMm > 0 ? m.channelLengthMm : 4000;
    _wClipUkeWidth = _clipUkeWidths.contains(m.wClipUkeWidthMm)
        ? m.wClipUkeWidthMm
        : 38;
    _singleClipUkeWidth = _clipUkeWidths.contains(m.singleClipUkeWidthMm)
        ? m.singleClipUkeWidthMm
        : 38;
    for (final layer in m.boards) {
      _boardLayers.add(_DropBoardLayerState.fromLayer(layer));
    }
  }

  double _nearest(List<double> xs, double v, double fallback) {
    if (xs.contains(v)) return v;
    if (xs.isEmpty) return fallback;
    return xs.reduce((a, b) => (a - v).abs() < (b - v).abs() ? a : b);
  }

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    _height.dispose();
    for (final layer in _boardLayers) {
      layer.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmSizeMismatch() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).dimConfirm),
        content: Text(Ms.of(ctx).dimMismatch),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Ms.of(ctx).confirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _pickOrConfirm({
    required double current,
    required double next,
    required double matchTo,
    required void Function() apply,
    bool runnerBarPair = false,
  }) async {
    if (next == current) return;
    final matched = runnerBarPair
        ? DropMethod.runnerMatchesBar(matchTo, next)
        : next == matchTo;
    if (!matched) {
      if (_mismatchDialogBusy) {
        if (mounted) setState(() {});
        return;
      }
      _mismatchDialogBusy = true;
      try {
        final ok = await _confirmSizeMismatch();
        if (!ok || !mounted) {
          setState(() {});
          return;
        }
      } finally {
        _mismatchDialogBusy = false;
      }
    }
    if (!mounted) return;
    setState(apply);
  }

  double get _L => double.tryParse(_length.text.trim()) ?? 0;
  double get _W => double.tryParse(_width.text.trim()) ?? 0;
  double get _H => double.tryParse(_height.text.trim()) ?? 0;

  DropMethod _buildMethod() => DropMethod(
        shape: _shape,
        system: _system,
        runnerWidthMm: _runnerWidth,
        runnerLengthMm: _runnerLength,
        studType: _studType,
        pitchMm: _pitch,
        studWidthMm: _studWidth,
        studLengthMm: _studLength,
        runnerHeightMm: _runnerHeight,
        wBarHeightMm: _wBarHeight,
        wBarLengthMm: _wBarLength,
        singleBarHeightMm: _singleBarHeight,
        singleBarLengthMm: _singleBarLength,
        channelWidthMm: _channelWidth,
        channelLengthMm: _channelLength,
        wClipUkeWidthMm: _wClipUkeWidth,
        singleClipUkeWidthMm: _singleClipUkeWidth,
        boards: [for (final layer in _boardLayers) layer.toLayer()],
      );

  Map<String, double> get _qty => DropCalc.calc(
        lengthMm: _L,
        widthMm: _W,
        heightMm: _H,
        method: _buildMethod(),
        points: widget.initialPoints,
        scalePxPerMm: widget.scalePxPerMm,
        turnWidths: widget.initialTurnWidths,
      );

  void _pop(DropSettingsAction action) {
    if (_L <= 0 || _W <= 0 || _H <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Ms.of(context).enterLWH)),
      );
      return;
    }
    Navigator.pop(
      context,
      DropSettingsResult(
        action: action,
        lengthMm: _L,
        widthMm: _W,
        heightMm: _H,
        turnWidths: widget.initialTurnWidths,
        method: _buildMethod(),
      ),
    );
  }

  Future<void> _openEstimate() async {
    if (_L <= 0 || _W <= 0 || _H <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Ms.of(context).enterLWH)),
      );
      return;
    }
    final method = _buildMethod();
    final qty = DropCalc.calc(
      lengthMm: _L,
      widthMm: _W,
      heightMm: _H,
      method: method,
      points: widget.initialPoints,
      scalePxPerMm: widget.scalePxPerMm,
      turnWidths: widget.initialTurnWidths,
    );
    final drop = DropRegion(
      id: 'preview',
      points: widget.initialPoints,
      lengthMm: _L,
      widthMm: _W,
      heightMm: _H,
      turnWidths: widget.initialTurnWidths,
      method: method,
      quantities: qty,
      groupNumber: widget.groupNumber,
    );
    final lines = EstimateBuilder.fromDrop(
      drop: drop,
      idGen: () => 'drop-${_idSeq++}',
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: Ms.of(context).estimateDrop,
          initialLines: lines,
          projectName: widget.projectName,
          siteAddress: widget.siteAddress,
          sitePhone: widget.sitePhone,
          siteContact: widget.siteContact,
          areaLabel: '下り',
          areaM2: qty['drop_area_m2'],
          dropLengthMm: _L,
          dropWidthMm: _W,
          dropHeightMm: _H,
          dropShapeLabel: method.shape.label,
          dropTurnWidths: widget.initialTurnWidths,
          onSavePersist: widget.onEstimatePersist,
        ),
      ),
    );
    if (mounted) _pop(DropSettingsAction.estimate);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final qty = _qty;
    final area = qty['drop_area_m2'] ?? 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (context, scroll) {
          return KeyboardDoneScope(
            child: Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Ms.of(context).dropSettingsNo(widget.groupNumber),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _length,
                          keyboardType: DoneKeyboard.decimal,
                          inputFormatters: DoneKeyboard.decimalFormatters,
                          textInputAction: DoneKeyboard.action,
                          onSubmitted: DoneKeyboard.onSubmitted,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            isDense: true,
                            labelText: Ms.of(context).dropLen,
                            helperText: Ms.of(context).dropLenHelp,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _width,
                          keyboardType: DoneKeyboard.decimal,
                          inputFormatters: DoneKeyboard.decimalFormatters,
                          textInputAction: DoneKeyboard.action,
                          onSubmitted: DoneKeyboard.onSubmitted,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            isDense: true,
                            labelText: Ms.of(context).widthMm,
                            helperText: Ms.of(context).widthHelp,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _height,
                    keyboardType: DoneKeyboard.decimal,
                    inputFormatters: DoneKeyboard.decimalFormatters,
                    textInputAction: DoneKeyboard.action,
                    onSubmitted: DoneKeyboard.onSubmitted,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: Ms.of(context).heightMm,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_W > 0 || widget.initialTurnWidths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (_W > 0)
                          '${dropWidthCircleLabel(1)} ${_W.round()} mm',
                        for (final t in widget.initialTurnWidths)
                          if (t.widthMm > 0)
                            '${dropWidthCircleLabel(t.turnIndex)} ${t.widthMm.round()} mm',
                      ].join('　'),
                      style: const TextStyle(fontSize: 13, color: AppTheme.steel),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    widget.initialTurnWidths.isNotEmpty
                        ? '面積（各区間の幅＋高さ）×長さ　${area.toStringAsFixed(2)} ㎡'
                        : '面積（幅＋高さ）×長さ　${area.toStringAsFixed(2)} ㎡',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LockableCupertinoPicker(
                    label: Ms.of(context).methodSelect,
                    labels: [
                      Ms.of(context).sqMethod,
                      Ms.of(context).zairaiMethod,
                    ],
                    selectedIndex: _system == CeilingSystemKind.sq ? 0 : 1,
                    height: 88,
                    onSelected: (i) => setState(() {
                      _system = i == 0
                          ? CeilingSystemKind.sq
                          : CeilingSystemKind.zairai;
                    }),
                  ),
                  const SizedBox(height: 8),
                  LockableCupertinoPicker(
                    label: Ms.of(context).dropShape,
                    labels: [for (final s in DropShape.values) Ms.of(context).displayDropShape(s.label)],
                    selectedIndex: DropShape.values.indexOf(_shape),
                    height: 88,
                    onSelected: (i) =>
                        setState(() => _shape = DropShape.values[i]),
                  ),
                  const SizedBox(height: 12),
                  if (_system == CeilingSystemKind.sq) ..._sqWidgets(),
                  if (_system == CeilingSystemKind.zairai) ..._zairaiWidgets(),
                  const SizedBox(height: 12),
                  _qtyPreview(qty),
                  const SizedBox(height: 16),
                  Text(
                    Ms.of(context).board,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_boardLayers.isEmpty)
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => _boardLayers.add(_DropBoardLayerState()),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(Ms.of(context).addLayer),
                    )
                  else
                    for (var i = 0; i < _boardLayers.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _boardLayerSection(i, area),
                    ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _openEstimate,
                    child: Text(Ms.of(context).toEstimate),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _pop(DropSettingsAction.save),
                    child: Text(Ms.of(context).save),
                  ),
                  if (widget.allowDelete) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _pop(DropSettingsAction.delete),
                      child: Text(
                        Ms.of(context).deleteThisDrop,
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      S.of(context).cancel,
                      style: const TextStyle(color: AppTheme.steel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sqWidgets() {
    final widths = _lgsWidths;
    return [
      LockableCupertinoPicker(
        label: Ms.of(context).runnerW,
        labels: [for (final w in widths) '${w.round()}mm'],
        selectedIndex: widths.indexOf(_runnerWidth).clamp(0, widths.length - 1),
        onSelected: (i) => setState(() => _runnerWidth = widths[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).runnerL,
        labels: [for (final s in _stockPresets) '${s.round()}mm'],
        selectedIndex: () {
          final i = _stockPresets.indexOf(_runnerLength);
          return i < 0 ? 1 : i;
        }(),
        onSelected: (i) => setState(() => _runnerLength = _stockPresets[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).studType,
        labels: _studTypes,
        selectedIndex: _studTypes.indexOf(_studType).clamp(0, _studTypes.length - 1),
        onSelected: (i) => setState(() => _studType = _studTypes[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).studPitch,
        labels: [for (final p in _pitches) '${p.round()}mm'],
        selectedIndex: _pitches.indexOf(_pitch).clamp(0, _pitches.length - 1),
        onSelected: (i) => setState(() => _pitch = _pitches[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).studW,
        labels: [for (final w in widths) '${w.round()}mm'],
        selectedIndex: widths.indexOf(_studWidth).clamp(0, widths.length - 1),
        onSelected: (i) => setState(() => _studWidth = widths[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).studLen,
        labels: const ['2700mm', '2800mm', '3000mm', '4000mm'],
        selectedIndex: () {
          const opts = [2700.0, 2800.0, 3000.0, 4000.0];
          final i = opts.indexOf(_studLength);
          return i < 0 ? 1 : i;
        }(),
        onSelected: (i) {
          const opts = [2700.0, 2800.0, 3000.0, 4000.0];
          setState(() => _studLength = opts[i]);
        },
      ),
    ];
  }

  List<Widget> _zairaiWidgets() {
    return [
      LockableCupertinoPicker(
        label: Ms.of(context).runnerW,
        labels: [for (final h in _runnerHeights) '${h.round()}mm'],
        selectedIndex: _runnerHeights
            .indexOf(_runnerHeight)
            .clamp(0, _runnerHeights.length - 1),
        onSelected: (i) => setState(() {
          _runnerHeight = _runnerHeights[i];
          final bar = DropMethod.barHeightForRunner(_runnerHeight);
          _wBarHeight = bar;
          _singleBarHeight = bar;
        }),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).runnerL,
        labels: [for (final s in _stockPresets) '${s.round()}mm'],
        selectedIndex: () {
          final i = _stockPresets.indexOf(_runnerLength);
          return i < 0 ? 1 : i;
        }(),
        onSelected: (i) => setState(() => _runnerLength = _stockPresets[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).wBarH,
        labels: [for (final h in _barHeights) '${h.round()}mm'],
        selectedIndex:
            _barHeights.indexOf(_wBarHeight).clamp(0, _barHeights.length - 1),
        onSelected: (i) => _pickOrConfirm(
          current: _wBarHeight,
          next: _barHeights[i],
          matchTo: _runnerHeight,
          runnerBarPair: true,
          apply: () => _wBarHeight = _barHeights[i],
        ),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).wBarL,
        labels: [for (final s in _stockPresets) '${s.round()}mm'],
        selectedIndex: () {
          final i = _stockPresets.indexOf(_wBarLength);
          return i < 0 ? 1 : i;
        }(),
        onSelected: (i) => setState(() => _wBarLength = _stockPresets[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).sBarH,
        labels: [for (final h in _barHeights) '${h.round()}mm'],
        selectedIndex: _barHeights
            .indexOf(_singleBarHeight)
            .clamp(0, _barHeights.length - 1),
        onSelected: (i) => _pickOrConfirm(
          current: _singleBarHeight,
          next: _barHeights[i],
          matchTo: _runnerHeight,
          runnerBarPair: true,
          apply: () => _singleBarHeight = _barHeights[i],
        ),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).sBarL,
        labels: [for (final s in _stockPresets) '${s.round()}mm'],
        selectedIndex: () {
          final i = _stockPresets.indexOf(_singleBarLength);
          return i < 0 ? 1 : i;
        }(),
        onSelected: (i) => setState(() => _singleBarLength = _stockPresets[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).ukeW,
        labels: [for (final w in _ukeWidths) '${w.round()}mm'],
        selectedIndex:
            _ukeWidths.indexOf(_channelWidth).clamp(0, _ukeWidths.length - 1),
        onSelected: (i) => setState(() {
          _channelWidth = _ukeWidths[i];
          _wClipUkeWidth = _channelWidth;
          _singleClipUkeWidth = _channelWidth;
        }),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).channelL,
        labels: [for (final s in _stockPresets) '${s.round()}mm'],
        selectedIndex: () {
          final i = _stockPresets.indexOf(_channelLength);
          return i < 0 ? 1 : i;
        }(),
        onSelected: (i) => setState(() => _channelLength = _stockPresets[i]),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).wClipUke,
        labels: [for (final w in _clipUkeWidths) '${w.round()}mm'],
        selectedIndex: _clipUkeWidths
            .indexOf(_wClipUkeWidth)
            .clamp(0, _clipUkeWidths.length - 1),
        onSelected: (i) => _pickOrConfirm(
          current: _wClipUkeWidth,
          next: _clipUkeWidths[i],
          matchTo: _channelWidth,
          apply: () => _wClipUkeWidth = _clipUkeWidths[i],
        ),
      ),
      const SizedBox(height: 8),
      LockableCupertinoPicker(
        label: Ms.of(context).sClipUke,
        labels: [for (final w in _clipUkeWidths) '${w.round()}mm'],
        selectedIndex: _clipUkeWidths
            .indexOf(_singleClipUkeWidth)
            .clamp(0, _clipUkeWidths.length - 1),
        onSelected: (i) => _pickOrConfirm(
          current: _singleClipUkeWidth,
          next: _clipUkeWidths[i],
          matchTo: _channelWidth,
          apply: () => _singleClipUkeWidth = _clipUkeWidths[i],
        ),
      ),
    ];
  }

  Widget _qtyPreview(Map<String, double> q) {
    final lines = <String>[];
    void add(String k, String label, String unit) {
      final v = q[k];
      if (v == null || v <= 0) return;
      final t = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(2);
      lines.add('$label　$t $unit');
    }

    add('runner_count', 'ランナー', '本');
    add('stud_count', 'スタッド', '本');
    add('w_bar_count', 'Wバー', '本');
    add('single_bar_count', 'シングルバー', '本');
    add('channel_count', '野縁受け', '本');
    add('w_clip_count', 'Wクリップ', '個');
    add('single_clip_count', 'シングルクリップ', '個');
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        lines.join('\n'),
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _boardLayerSection(int index, double area) {
    final layer = _boardLayers[index];
    final sizeIdx = _kBoardSizeOpts.indexWhere(
      (o) =>
          (o.$2 - layer.widthMm).abs() < 0.5 &&
          (o.$3 - layer.heightMm).abs() < 0.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(Ms.of(context).layerBoard(index + 1))),
            if (index == _boardLayers.length - 1)
              IconButton(
                tooltip: Ms.of(context).addLayer,
                onPressed: () {
                  setState(() {
                    _boardLayers.add(_DropBoardLayerState());
                  });
                },
                icon: const Icon(Icons.add_circle, color: AppTheme.navy),
              ),
            IconButton(
              tooltip: Ms.of(context).deleteLayer,
              onPressed: () {
                setState(() {
                  final removed = _boardLayers.removeAt(index);
                  removed.dispose();
                });
              },
              icon: const Icon(
                Icons.remove_circle_outline,
                color: AppTheme.steel,
              ),
            ),
          ],
        ),
        LockableCupertinoPicker(
          label: Ms.of(context).boardNamePick,
          labels: _kBoardNames,
          selectedIndex: layer.boardNamePickerIndex,
          height: 120,
          onSelected: (i) {
            setState(() {
              if (i == 0) {
                layer.useCustomName = true;
                if (_kBoardNames.contains(layer.nameCtrl.text) ||
                    layer.nameCtrl.text == _kBoardNameCustom) {
                  layer.nameCtrl.clear();
                }
              } else {
                layer.useCustomName = false;
                layer.name = _kBoardNames[i];
                layer.nameCtrl.text = layer.name;
              }
            });
          },
        ),
        if (layer.useCustomName) ...[
          const SizedBox(height: 6),
          TextField(
            controller: layer.nameCtrl,
            textInputAction: DoneKeyboard.action,
            onSubmitted: DoneKeyboard.onSubmitted,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              labelText: Ms.of(context).customName,
            ),
          ),
        ],
        const SizedBox(height: 8),
        LockableCupertinoPicker(
          label: Ms.of(context).size,
          labels: [for (final o in _kBoardSizeOpts) o.$1],
          selectedIndex:
              (sizeIdx < 0 ? 4 : sizeIdx).clamp(0, _kBoardSizeOpts.length - 1),
          height: 110,
          onSelected: (i) {
            setState(() {
              layer.widthMm = _kBoardSizeOpts[i].$2;
              layer.heightMm = _kBoardSizeOpts[i].$3;
            });
          },
        ),
        const SizedBox(height: 8),
        LockableCupertinoPicker(
          label: Ms.of(context).thickness,
          labels: [
            for (final t in _kBoardThicknesses)
              t == t.roundToDouble() ? '${t.round()}mm' : '${t}mm',
          ],
          selectedIndex: _kBoardThicknesses
              .indexOf(layer.thicknessMm)
              .clamp(0, _kBoardThicknesses.length - 1),
          onSelected: (i) =>
              setState(() => layer.thicknessMm = _kBoardThicknesses[i]),
        ),
      ],
    );
  }
}

class _DropBoardLayerState {
  _DropBoardLayerState({
    this.name = 'タイガーボード',
    this.widthMm = 910,
    this.heightMm = 1820,
    this.thicknessMm = 9.5,
    this.useCustomName = false,
    String customName = '',
  }) : nameCtrl = TextEditingController(
          text: useCustomName
              ? customName
              : (name == _kBoardNameCustom ? '' : name),
        );

  factory _DropBoardLayerState.fromLayer(CeilingFinishBoardLayer layer) {
    final presets = _kBoardNames.skip(1).toList();
    final isCustom = layer.name.isEmpty ||
        layer.name == _kBoardNameCustom ||
        !presets.contains(layer.name);
    final sizeIdx = _kBoardSizeOpts.indexWhere(
      (o) =>
          (o.$2 - layer.widthMm).abs() < 0.5 &&
          (o.$3 - layer.heightMm).abs() < 0.5,
    );
    final size = sizeIdx >= 0 ? _kBoardSizeOpts[sizeIdx] : _kBoardSizeOpts[4];
    final thick = _kBoardThicknesses.contains(layer.thicknessMm)
        ? layer.thicknessMm
        : 9.5;
    return _DropBoardLayerState(
      name: isCustom ? _kBoardNameCustom : layer.name,
      widthMm: size.$2,
      heightMm: size.$3,
      thicknessMm: thick,
      useCustomName: isCustom,
      customName: isCustom ? layer.name : layer.name,
    );
  }

  String name;
  double widthMm;
  double heightMm;
  double thicknessMm;
  bool useCustomName;
  final TextEditingController nameCtrl;

  int get boardNamePickerIndex {
    if (useCustomName) return 0;
    final i = _kBoardNames.indexOf(name);
    return i < 0 ? 0 : i;
  }

  void dispose() {
    nameCtrl.dispose();
  }

  CeilingFinishBoardLayer toLayer() => CeilingFinishBoardLayer(
        name: useCustomName
            ? nameCtrl.text.trim()
            : (name == _kBoardNameCustom ? nameCtrl.text.trim() : name),
        widthMm: widthMm,
        heightMm: heightMm,
        thicknessMm: thicknessMm,
      );
}
