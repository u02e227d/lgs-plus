import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lockable_picker.dart';
import 'cross_dedicated_sheet.dart';

enum CeilingParamsAction { apply, delete, estimate }

class CeilingParamsResult {
  CeilingParamsResult({
    required this.method,
    required this.action,
  });
  final CeilingMethod method;
  final CeilingParamsAction action;
}

/// 天井工法選択（SQ/在来・施工仕様・ピッチ・90°・削除・試算表）
class CeilingParamsSheet extends StatefulWidget {
  const CeilingParamsSheet({
    super.key,
    this.initialMethod,
    this.ceilingNumber = 1,
    this.areaM2,
    this.onLiveUpdate,
    this.onCrossEstimateSave,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
  });

  final CeilingMethod? initialMethod;
  final int ceilingNumber;
  final double? areaM2;
  final void Function(CeilingMethod method)? onLiveUpdate;
  final Future<void> Function(EstimateSaveResult result)? onCrossEstimateSave;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;

  @override
  State<CeilingParamsSheet> createState() => _CeilingParamsSheetState();
}

class _CeilingParamsSheetState extends State<CeilingParamsSheet> {
  static const _pitches36 = [227.0, 303.0, 364.0];
  static const _sqStudPitches = [227.0, 303.0, 455.0];
  /// 在来の施工仕様。先頭＝既定の 3×6（ピッカー初期値が 0 でも 3×6 のまま）
  static const _zairaiPanels = [
    CeilingPanelSpec.panel3x6,
    CeilingPanelSpec.panel3x3,
    CeilingPanelSpec.panel15x3,
  ];

  late CeilingSystemKind _system;
  late CeilingPanelSpec _panel;
  late double _pitch36;
  late double _sqStudPitch;
  late bool _rotated90;
  late bool _showLayout;
  late CrossDedicatedConfig _crossDedicated;
  bool _ignorePanelPick = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMethod ?? const CeilingMethod();
    _system = m.systemKind;
    _panel = m.panelSpec;
    _pitch36 = _pitches36.contains(m.noenSpacingMm)
        ? m.noenSpacingMm
        : 303;
    _sqStudPitch = _sqStudPitches.contains(m.sqStudPitchMm)
        ? m.sqStudPitchMm
        : 303;
    _rotated90 = m.rotated90;
    _showLayout = m.showLayout;
    _crossDedicated = m.crossDedicated;
  }

  CeilingMethod _buildMethod() {
    final pitch = _panel == CeilingPanelSpec.panel3x6
        ? _pitch36
        : (_panel == CeilingPanelSpec.panel15x3 ? 227.5 : 303.0);
    final base = widget.initialMethod ?? const CeilingMethod();
    return base.copyWith(
      systemKind: _system,
      panelSpec: _panel,
      noenSpacingMm: pitch,
      sqStudPitchMm: _sqStudPitch,
      noenuKeSpacingMm: 910,
      boardSize: _panel.boardSize,
      // ボード層数は材料設定の finishBoardLayers で管理
      layers: base.finishBoardLayers.length > 1
          ? BoardLayersX.fromCount(base.finishBoardLayers.length)
          : base.layers,
      rotated90: _rotated90,
      showLayout: _showLayout,
      crossDedicated: _crossDedicated,
    );
  }

  Future<void> _openCrossDedicated() async {
    final result = await Navigator.of(context).push<CrossDedicatedConfig>(
      MaterialPageRoute(
        builder: (_) => CrossDedicatedSheet(
          areaM2: widget.areaM2 ?? 0,
          initial: _crossDedicated,
          title: Ms.of(context).crossDedicatedCeil,
          onSavePersist: widget.onCrossEstimateSave,
          projectName: widget.projectName,
          siteAddress: widget.siteAddress,
          sitePhone: widget.sitePhone,
          siteContact: widget.siteContact,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _crossDedicated = result);
    _emitLive();
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

  void _emitLive() {
    widget.onLiveUpdate?.call(_buildMethod());
  }

  void _pop(CeilingParamsAction action) {
    Navigator.pop(
      context,
      CeilingParamsResult(method: _buildMethod(), action: action),
    );
  }

  String get _circled {
    final n = widget.ceilingNumber;
    if (n >= 1 && n <= 20) {
      return String.fromCharCode(0x245F + n);
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final area = widget.areaM2;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
                      '$_circled ${Ms.of(context).ceilMethodTitle}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _crossDedicatedButton(),
                ],
              ),
              if (area != null && area > 0) ...[
                const SizedBox(height: 4),
                Text(
                  Ms.of(context).areaM2(area.toStringAsFixed(2)),
                  style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              Text(Ms.of(context).wallMethod, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in CeilingSystemKind.values)
                    ChoiceChip(
                      label: Text(k == CeilingSystemKind.sq
                          ? Ms.of(context).sqMethod
                          : Ms.of(context).zairaiMethod),
                      selected: _system == k,
                      onSelected: (_) {
                        setState(() {
                          _system = k;
                          if (k == CeilingSystemKind.zairai) {
                            _panel = CeilingPanelSpec.panel3x6;
                            _ignorePanelPick = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _ignorePanelPick = false;
                            });
                          }
                        });
                        _emitLive();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_system == CeilingSystemKind.sq) ...[
                LockableCupertinoPicker(
                  label: Ms.of(context).studPitch,
                  labels: [
                    for (final v in _sqStudPitches) '${v.round()}mm',
                  ],
                  selectedIndex: _sqStudPitches
                      .indexOf(_sqStudPitch)
                      .clamp(0, _sqStudPitches.length - 1),
                  height: 120,
                  onSelected: (i) {
                    setState(() => _sqStudPitch = _sqStudPitches[i]);
                    _emitLive();
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_system == CeilingSystemKind.zairai) ...[
                LockableCupertinoPicker(
                  key: const ValueKey('zairai-panel-spec'),
                  label: Ms.of(context).ceilSpec,
                  labels: [for (final p in _zairaiPanels) p.label],
                  selectedIndex:
                      _zairaiPanels.indexOf(_panel).clamp(0, _zairaiPanels.length - 1),
                  height: 120,
                  liveUpdate: false,
                  onSelected: (i) {
                    if (_ignorePanelPick) return;
                    final next = _zairaiPanels[i];
                    if (next == _panel) return;
                    setState(() => _panel = next);
                    _emitLive();
                  },
                ),
                if (_panel.needsPitchSelect) ...[
                  const SizedBox(height: 8),
                  Text(Ms.of(context).noenPitch,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final v in _pitches36)
                        ChoiceChip(
                          label: Text('${v.round()}mm'),
                          selected: _pitch36 == v,
                          onSelected: (_) {
                            setState(() => _pitch36 = v);
                            _emitLive();
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
              Text(
                _system == CeilingSystemKind.sq
                    ? Ms.of(context).sqHint
                    : (_panel == CeilingPanelSpec.panel15x3
                        ? Ms.of(context).zairai15x3
                        : _panel == CeilingPanelSpec.panel3x3
                            ? Ms.of(context).zairai3x3
                            : Ms.of(context).zairai36('${_pitch36.round()}mm')),
                style: const TextStyle(fontSize: 12, color: AppTheme.steel),
              ),
              if (_system == CeilingSystemKind.zairai)
                Text(
                  Ms.of(context).zairaiBoltNote,
                  style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _rotated90 = !_rotated90;
                    _showLayout = true;
                  });
                  _emitLive();
                },
                icon: const Icon(Icons.rotate_90_degrees_ccw, size: 18),
                label: Text(_rotated90
                    ? Ms.of(context).rotate90Done
                    : Ms.of(context).rotate90),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() => _showLayout = true);
                  _pop(CeilingParamsAction.apply);
                },
                child: Text(Ms.of(context).applyToDrawing),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                ),
                onPressed: () {
                  setState(() => _showLayout = true);
                  _pop(CeilingParamsAction.estimate);
                },
                child: Text(Ms.of(context).goMaterialPage),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                onPressed: () => _pop(CeilingParamsAction.delete),
                child: Text(Ms.of(context).deleteThisArea),
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
    );
  }
}
