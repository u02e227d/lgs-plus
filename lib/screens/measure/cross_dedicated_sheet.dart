import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../services/cross_dedicated_calc.dart';
import '../../services/estimate_builder.dart';
import '../../services/saved_name_catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';
import '../../widgets/lockable_picker.dart';
import '../../widgets/saved_name_picker.dart';
import 'estimate_table_screen.dart';

/// クロス専用ページ（壁・天井共通）
class CrossDedicatedSheet extends StatefulWidget {
  const CrossDedicatedSheet({
    super.key,
    required this.areaM2,
    this.initial = const CrossDedicatedConfig(),
    this.title = '',
    this.showWallFaces = false,
    this.onSavePersist,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
  });

  final double areaM2;
  final CrossDedicatedConfig initial;
  final String title;
  /// 壁のとき単面／両面を表示
  final bool showWallFaces;
  final Future<void> Function(EstimateSaveResult result)? onSavePersist;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;

  @override
  State<CrossDedicatedSheet> createState() => _CrossDedicatedSheetState();
}

class _CrossDedicatedSheetState extends State<CrossDedicatedSheet> {
  static const _tapePresets = [45.0, 90.0];

  late String _crossName;
  late TextEditingController _crossUnit;
  late String _pasteName;
  late String _pateName;
  late double _widthM;
  late bool _bothSides;
  late String _fiberName;
  late double _tapeLen;
  late bool _tapeCustom;
  late TextEditingController _tapeLenCtrl;
  var _idSeq = 0;
  final _faceKey = GlobalKey<_WallFaceSwitchState>();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _crossName = i.crossName;
    _crossUnit = TextEditingController(
      text: i.crossUnit.trim().isEmpty ? 'm' : i.crossUnit,
    );
    _pasteName = i.pasteName;
    _pateName = i.pateName.isEmpty
        ? CrossDedicatedCalc.defaultPateName
        : i.pateName;
    _widthM = i.crossWidthM > 0 ? i.crossWidthM : CrossDedicatedCalc.crossWidthM;
    _bothSides = i.bothSides;
    _fiberName = i.fiberTapeName;
    final tl = i.fiberTapeLengthM > 0 ? i.fiberTapeLengthM : 45.0;
    _tapeCustom = !_tapePresets.contains(tl);
    _tapeLen = tl;
    _tapeLenCtrl = TextEditingController(
      text: tl == tl.roundToDouble()
          ? tl.round().toString()
          : tl.toString(),
    );
  }

  @override
  void dispose() {
    _crossUnit.dispose();
    _tapeLenCtrl.dispose();
    super.dispose();
  }

  double get _baseArea => widget.areaM2 > 0 ? widget.areaM2 : 0;

  double get _area {
    final factor = widget.showWallFaces && _bothSides ? 2.0 : 1.0;
    return _baseArea * factor;
  }

  double get _resolvedTapeLen {
    if (_tapeCustom) {
      return double.tryParse(_tapeLenCtrl.text.trim()) ?? _tapeLen;
    }
    return _tapeLen;
  }

  double get _crossQty =>
      CrossDedicatedCalc.crossMeters(_area, widthM: _widthM);

  double get _pasteQty => CrossDedicatedCalc.pasteKg(_crossQty);

  PateQtyResult get _pate =>
      CrossDedicatedCalc.pateQty(_pateName, _area);

  double get _fiberQty =>
      CrossDedicatedCalc.fiberTapeCount(_area, _resolvedTapeLen);

  CrossDedicatedConfig _build({bool enable = false}) => CrossDedicatedConfig(
        enabled: enable || widget.initial.enabled,
        crossName: _crossName.trim(),
        crossUnit: _crossUnit.text.trim().isEmpty ? 'm' : _crossUnit.text.trim(),
        pasteName: _pasteName.trim(),
        pateName: _pateName.trim(),
        crossWidthM: _widthM,
        bothSides: widget.showWallFaces ? _bothSides : false,
        fiberTapeName: _fiberName.trim(),
        fiberTapeLengthM: _resolvedTapeLen > 0 ? _resolvedTapeLen : 45,
      );

  Future<void> _openEstimate() async {
    final config = _build(enable: true);
    final lines = EstimateBuilder.fromCrossDedicated(
      config: config,
      areaM2: _area,
      idGen: () => 'cross-${_idSeq++}',
    );
    if (lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Ms.of(context).checkAreaName)),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: Ms.of(context).estimateCross,
          initialLines: lines,
          projectName: widget.projectName,
          siteAddress: widget.siteAddress,
          sitePhone: widget.sitePhone,
          siteContact: widget.siteContact,
          areaLabel: 'クロス',
          areaM2: _area > 0 ? _area : null,
          initialFilter: EstimateSheetKind.cross,
          lockFilter: true,
          onSavePersist: widget.onSavePersist,
        ),
      ),
    );
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(config);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pate = _pate;
    final tapeIdx = _tapeCustom
        ? _tapePresets.length
        : _tapePresets.indexOf(_tapeLen).clamp(0, _tapePresets.length - 1);
    final tapeLabels = [
      for (final t in _tapePresets) '${t.round()}m',
      Ms.of(context).customInput,
    ];
    final ms = Ms.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: S.of(context).close,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        title: Text(widget.title.isEmpty ? ms.crossDedicated : widget.title),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(_build()),
            child: Text(
              ms.back,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showWallFaces)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: _WallFaceSwitch(
                  key: _faceKey,
                  bothSides: _bothSides,
                  baseAreaM2: _baseArea,
                  onChanged: (v) {
                    if (!mounted) return;
                    setState(() => _bothSides = v);
                  },
                ),
              ),
            Expanded(
              child: KeyboardDoneScope(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
              if (!widget.showWallFaces) ...[
              Text(
                ms.measuredArea,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  '${_area.toStringAsFixed(2)} ㎡',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              ],
            const SizedBox(height: 20),
            _section(ms.crossName),
            SavedNamePicker(
              label: ms.nameCode,
              prefsKey: SavedNameCatalog.crossNames,
              value: _crossName,
              onChanged: (v) => setState(() => _crossName = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _crossUnit,
                    textInputAction: DoneKeyboard.action,
                    onSubmitted: DoneKeyboard.onSubmitted,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.unit,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.qty,
                    ),
                    child: Text(
                      _crossQty.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(ms.paste),
            SavedNamePicker(
              label: ms.itemName,
              prefsKey: SavedNameCatalog.pasteNames,
              value: _pasteName,
              onChanged: (v) => setState(() => _pasteName = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.unit,
                    ),
                    child: const Text('kg',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.pasteQty,
                    ),
                    child: Text(
                      _pasteQty.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(ms.underPate),
            SavedNamePicker(
              label: ms.underPateName,
              prefsKey: SavedNameCatalog.pateNames,
              value: _pateName,
              presets: CrossDedicatedCalc.patePresetNames,
              onChanged: (v) => setState(() => _pateName = v),
              height: 140,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.unitKg,
                    ),
                    child: const Text('kg',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.needKg,
                    ),
                    child: Text(
                      pate.kgNeeded.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _section(ms.fiberTape),
            SavedNamePicker(
              label: ms.itemName,
              prefsKey: SavedNameCatalog.fiberTapeNames,
              value: _fiberName,
              onChanged: (v) => setState(() => _fiberName = v),
            ),
            const SizedBox(height: 8),
            LockableCupertinoPicker(
              label: ms.tapeLenM,
              labels: tapeLabels,
              selectedIndex: tapeIdx,
              height: 100,
              onSelected: (i) {
                setState(() {
                  if (i >= _tapePresets.length) {
                    _tapeCustom = true;
                  } else {
                    _tapeCustom = false;
                    _tapeLen = _tapePresets[i];
                    _tapeLenCtrl.text = _tapeLen.round().toString();
                  }
                });
              },
            ),
            if (_tapeCustom) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _tapeLenCtrl,
                keyboardType: DoneKeyboard.decimal,
                inputFormatters: DoneKeyboard.decimalFormatters,
                textInputAction: DoneKeyboard.action,
                onSubmitted: DoneKeyboard.onSubmitted,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  labelText: ms.tapeLenDirect,
                  suffixText: 'm',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.unit,
                    ),
                    child: Text(ms.pcs,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: ms.qtyCeil,
                    ),
                    child: Text(
                      _fiberQty.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openEstimate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BD6),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                ms.toEstimate,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(
                const CrossDedicatedConfig(enabled: false),
              ),
              child: Text(
                ms.clearAndBack,
                style: const TextStyle(color: AppTheme.steel),
              ),
            ),
            ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      );
}

/// 単面／両面。自身の State で色を切り替える（親の再ビルドで見た目が戻らない）
class _WallFaceSwitch extends StatefulWidget {
  const _WallFaceSwitch({
    super.key,
    required this.bothSides,
    required this.baseAreaM2,
    required this.onChanged,
  });

  final bool bothSides;
  final double baseAreaM2;
  final ValueChanged<bool> onChanged;

  @override
  State<_WallFaceSwitch> createState() => _WallFaceSwitchState();
}

class _WallFaceSwitchState extends State<_WallFaceSwitch> {
  late bool _both;

  @override
  void initState() {
    super.initState();
    _both = widget.bothSides;
  }

  void _tap(bool both) {
    setState(() => _both = both);
    widget.onChanged(both);
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.baseAreaM2 * (_both ? 2.0 : 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _btn(false, Ms.of(context).singleFaceWall),
            const SizedBox(width: 10),
            _btn(true, Ms.of(context).bothFaceWall),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          Ms.of(context).measuredArea,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${area.toStringAsFixed(2)} ㎡',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              if (_both)
                Text(
                  Ms.of(context).bothFaceNote(
                    widget.baseAreaM2.toStringAsFixed(2),
                  ),
                  style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(bool both, String label) {
    final on = _both == both;
    return Expanded(
      child: Material(
        color: on ? AppTheme.navy : const Color(0xFFE8EEF6),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _tap(both),
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: on ? Colors.white : AppTheme.navy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
