import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/calc_engine.dart';
import '../../services/edge_snap_engine.dart';
import '../../services/estimate_builder.dart';
import '../../theme/app_theme.dart';
import '../../widgets/measure_mouse.dart';
import '../../widgets/measure_painters.dart';
import '../../widgets/wall_triad_editor.dart';
import 'ceiling_params_sheet.dart';
import 'estimate_table_screen.dart';
import 'opening_reinforce_sheet.dart';
import 'wall_material_sheet.dart';
import 'wall_params_sheet.dart';
import '../../services/opening_reinforce.dart';

enum CanvasTool { pan, wallPen, ceilingPen, openingReinforce }

/// 壁マウスの画線モード
enum WallDrawMode { single, multi }

/// 測定キャンバス：底図 / 壁線・天井 / マウス
class MeasureCanvasScreen extends StatefulWidget {
  const MeasureCanvasScreen({
    super.key,
    required this.measurementId,
    required this.drawing,
  });

  final String measurementId;
  final DrawingFile drawing;

  @override
  State<MeasureCanvasScreen> createState() => _MeasureCanvasScreenState();
}

class _MeasureCanvasScreenState extends State<MeasureCanvasScreen>
    with SingleTickerProviderStateMixin {
  Measurement? _measurement;
  CanvasTool _tool = CanvasTool.pan;
  WallDrawMode _wallDrawMode = WallDrawMode.single;
  final _snap = EdgeSnapEngine();
  final _transform = TransformationController();
  bool _snapEnabled = true;

  // —— マウス描画 ——
  final List<Offset> _wallPoints = [];
  Offset? _mouseTip; // 吸着後の先端
  bool _touching = false;
  bool _mouseReady = false; // 緑＝点確定／離手で完了可
  bool _startLocked = false; // 起点1.5秒完了後
  double _holdProgress = 0;
  DateTime? _holdSince;
  Offset? _holdAnchorTip;
  Timer? _holdTicker;

  final List<Offset> _ceilingDraft = [];
  final List<Offset> _openingDraft = [];
  bool _openingSetupDone = false;

  String? _selectedWallId;
  String? _continueWallId;
  final List<WallBadgeHit> _badgeHits = [];
  int _drawColorArgb = WallHighlightColors.defaultArgb;
  double _strokeWidth = 8;
  DateTime? _pointerDownAt;
  Offset? _pointerDownPos;
  bool _longPressHandled = false;

  ui.Image? _bgImage;
  Size _imageSize = Size.zero;

  static const _holdNeed = Duration(milliseconds: 1500);
  static const _stillPx = 14.0;

  List<LineSeg> get _snapLines => _snap.lines;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _holdTicker?.cancel();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final state = context.read<AppState>();
    final m = await state.db.getMeasurement(widget.measurementId);
    final bytes = await File(widget.drawing.localPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _bgImage = frame.image;
    _imageSize = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );

    if (!mounted) return;
    setState(() {
      _measurement = m;
      if ((m?.openings.isNotEmpty ?? false)) {
        _openingSetupDone = true;
      }
    });
  }

  double get _k => widget.drawing.scalePxPerMm ?? 1;

  double get _viewScale {
    final s = _transform.value.getMaxScaleOnAxis();
    return s <= 0 ? 1.0 : s;
  }

  Point2 _snapPoint(Offset raw) {
    final p = Point2(raw.dx, raw.dy);
    if (!_snapEnabled) return p;
    return _snap.snap(p);
  }

  Offset _tipFromFinger(Offset finger) {
    final raw = MeasureMousePainter.tipFromFinger(finger, _viewScale);
    final s = _snapPoint(raw);
    return Offset(s.x, s.y);
  }

  Future<void> _persist(Measurement m) async {
    await context.read<AppState>().saveMeasurement(m);
    setState(() => _measurement = m);
  }

  void _clearWallDraft({bool notify = true}) {
    _holdTicker?.cancel();
    void apply() {
      _wallPoints.clear();
      _mouseTip = null;
      _touching = false;
      _mouseReady = false;
      _startLocked = false;
      _holdProgress = 0;
      _holdSince = null;
      _holdAnchorTip = null;
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _startHoldWatch(Offset tip) {
    _holdSince = DateTime.now();
    _holdAnchorTip = tip;
    _holdProgress = 0;
    _mouseReady = false;
    _holdTicker?.cancel();
    _holdTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_touching || _holdSince == null || !mounted) return;
      final elapsed = DateTime.now().difference(_holdSince!);
      final p = (elapsed.inMilliseconds / _holdNeed.inMilliseconds)
          .clamp(0.0, 1.0);
      if (p != _holdProgress) {
        setState(() => _holdProgress = p);
      }
      if (elapsed >= _holdNeed) {
        _onHoldCompleted();
      }
    });
  }

  void _resetHold(Offset tip) {
    _holdSince = DateTime.now();
    _holdAnchorTip = tip;
    _holdProgress = 0;
    if (_mouseReady) {
      setState(() => _mouseReady = false);
    }
  }

  void _onHoldCompleted() {
    _holdTicker?.cancel();
    if (!_touching || _mouseTip == null || !mounted) return;

    if (_tool == CanvasTool.wallPen) {
      final tip = _mouseTip!;
      setState(() {
        _mouseReady = true;
        _holdProgress = 1;
        if (!_startLocked) {
          _startLocked = true;
          if (_wallPoints.isEmpty ||
              (_wallPoints.last - tip).distance >= 8) {
            _wallPoints.add(tip);
          }
        } else {
          // 曲がり／終点候補
          if (_wallPoints.isEmpty ||
              (_wallPoints.last - tip).distance >= 12) {
            _wallPoints.add(tip);
          }
        }
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _wallPoints.length <= 1
                ? '緑：起点確定。マウス先端を次の点へ移動'
                : '緑：点を確定。続けて移動／終点なら離して完了',
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } else if (_tool == CanvasTool.ceilingPen) {
      final tip = _mouseTip!;
      setState(() {
        _mouseReady = true;
        _holdProgress = 1;
        if (_ceilingDraft.isEmpty ||
            (_ceilingDraft.last - tip).distance >= 12) {
          _ceilingDraft.add(tip);
        }
      });
    } else if (_tool == CanvasTool.openingReinforce) {
      final tip = _mouseTip!;
      setState(() {
        _mouseReady = true;
        _holdProgress = 1;
        if (_openingDraft.length < 2 &&
            (_openingDraft.isEmpty ||
                (_openingDraft.last - tip).distance >= 8)) {
          _openingDraft.add(tip);
        }
      });
      if (_openingDraft.length == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('1点目確定。開口のもう一端へ移動して確定'),
            duration: Duration(milliseconds: 1400),
          ),
        );
      }
    }
  }

  double _draftLengthMm(List<Offset> pts) {
    var len = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      len += CalcEngine.pxToMm((pts[i + 1] - pts[i]).distance, _k);
    }
    return len;
  }

  Future<void> _finishWallFromMouse() async {
    final draft = <Offset>[..._wallPoints];
    if (_mouseTip != null &&
        (draft.isEmpty || (draft.last - _mouseTip!).distance >= 4)) {
      draft.add(_mouseTip!);
    }
    final cleaned = <Offset>[];
    for (final p in draft) {
      if (cleaned.isEmpty || (cleaned.last - p).distance >= 4) {
        cleaned.add(p);
      }
    }
    if (cleaned.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('点が足りません。赤→緑で2点以上取ってください')),
      );
      return;
    }
    _clearWallDraft();
    await _commitWallLine(cleaned);
  }

  /// 画完：単線＝新番号／多線＝同一番号に長さ合算（番号は最新線尾へ）
  Future<void> _commitWallLine(List<Offset> cleaned) async {
    if (_measurement == null) return;
    final pts = cleaned
        .map((o) {
          final s = _snapPoint(o);
          return Point2(s.x, s.y);
        })
        .toList();
    if (pts.length < 2) return;

    if (_wallDrawMode == WallDrawMode.multi) {
      final contId = _continueWallId;
      final existing =
          contId != null ? _wallById(contId) : null;
      if (existing != null && !existing.estimateReady) {
        final newStarts = [...existing.chainStarts, existing.points.length];
        final mergedPts = [...existing.points, ...pts];
        var openings = _linkOpeningsToWall(
          _measurement!.openings,
          existing.copyWith(points: mergedPts, chainStarts: newStarts),
        );
        final linked = existing.copyWith(
          points: mergedPts,
          chainStarts: newStarts,
          highlightArgb: _drawColorArgb,
          strokeWidth: _strokeWidth,
        );
        final qty = CalcEngine.calcWall(
          points: mergedPts,
          chainStarts: newStarts,
          heightMm: existing.heightMm,
          scalePxPerMm: _k,
          method: existing.method,
          openings: openings.where((o) => o.wallId == existing.id).toList(),
        );
        final updatedWall = linked.copyWith(quantities: qty);
        final walls = _measurement!.walls
            .map((w) => w.id == existing.id ? updatedWall : w)
            .toList();
        await _persist(
          _measurement!.copyWith(walls: walls, openings: openings),
        );
        if (!mounted) return;
        final num = _wallNumber(existing.id);
        setState(() => _selectedWallId = existing.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '線 $num に追加（${updatedWall.chains.length}本合算）。'
              '番号は最新線尾。完了したら番号タップ',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    } else {
      _continueWallId = null;
    }

    const method = WallMethod();
    const heightMm = 2700.0;
    final seg = WallSegment(
      id: context.read<AppState>().newId(),
      points: pts,
      heightMm: heightMm,
      method: method,
      quantities: const {},
      highlightArgb: _drawColorArgb,
      strokeWidth: _strokeWidth,
      estimateReady: false,
    );
    var openings = _linkOpeningsToWall(_measurement!.openings, seg);
    final hasReinforce = openings.any(
      (o) =>
          o.wallId == seg.id && o.material == OpeningMaterialKind.reinforce,
    );
    final method2 = hasReinforce
        ? method.copyWith(
            useReinforceMaterial: true,
            reinforceWidthMm: method.studWidthMm,
            reinforceLengthMm: heightMm,
          )
        : method;
    final qty = CalcEngine.calcWall(
      points: pts,
      heightMm: heightMm,
      scalePxPerMm: _k,
      method: method2,
      openings: openings.where((o) => o.wallId == seg.id).toList(),
    );
    final seg2 = WallSegment(
      id: seg.id,
      points: pts,
      heightMm: heightMm,
      method: method2,
      quantities: qty,
      highlightArgb: _drawColorArgb,
      strokeWidth: _strokeWidth,
      estimateReady: false,
    );
    final updated = _measurement!.copyWith(
      walls: [..._measurement!.walls, seg2],
      openings: openings,
    );
    await _persist(updated);
    if (!mounted) return;
    if (_wallDrawMode == WallDrawMode.multi) {
      _continueWallId = seg2.id;
    } else {
      _continueWallId = null;
    }
    final num = updated.walls.length;
    setState(() => _selectedWallId = seg2.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _wallDrawMode == WallDrawMode.multi
              ? '線 $num 開始（多線）。続けて画線で合算／番号タップで工法選択'
              : '線 $num を追加。線尾の番号をタップ → 工法選択 / 削除',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<WallDrawMode?> _pickWallDrawMode() async {
    return showModalBottomSheet<WallDrawMode>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const Text(
                  '壁マウス — 画線モード',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.timeline, color: AppTheme.navy),
                  title: const Text(
                    '単線',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('1本の線ごとに番号が付きます'),
                  onTap: () => Navigator.pop(ctx, WallDrawMode.single),
                ),
                ListTile(
                  leading: const Icon(Icons.account_tree, color: AppTheme.accent),
                  title: const Text(
                    '多線',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    '複数線を合算して1つの番号。壁高さ・工法は同一にしてください。'
                    '交差点はスタッド3本を加算します',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(ctx, WallDrawMode.multi),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCeiling() async {
    if (_ceilingDraft.length < 3 || _measurement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3点以上（各点1.5秒）で領域を閉じてください')),
      );
      return;
    }
    final pts = _ceilingDraft.map((o) {
      final s = _snapPoint(o);
      return Point2(s.x, s.y);
    }).toList();

    final result = await showModalBottomSheet<CeilingParamsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CeilingParamsSheet(),
    );
    if (result == null) return;

    final qty = CalcEngine.calcCeiling(
      points: pts,
      scalePxPerMm: _k,
      method: result.method,
    );
    final region = CeilingRegion(
      id: context.read<AppState>().newId(),
      points: pts,
      method: result.method,
      quantities: qty,
    );
    final updated = _measurement!.copyWith(
      ceilings: [..._measurement!.ceilings, region],
    );
    await _persist(updated);
    setState(() {
      _ceilingDraft.clear();
      _mouseTip = null;
      _mouseReady = false;
    });
    if (!mounted) return;

    final ceilingOnly = <EstimateLine>[];
    for (final c in updated.ceilings) {
      ceilingOnly.addAll(
        EstimateBuilder.fromCeiling(
          ceiling: c,
          idGen: () => context.read<AppState>().newId(),
        ),
      );
    }
    final merged = EstimateBuilder.mergeByNameAndSize(
      ceilingOnly,
      idGen: () => context.read<AppState>().newId(),
    );
    SiteProject? project;
    try {
      project = await context.read<AppState>().db.getProject(
            updated.projectId,
          );
    } catch (_) {}
    if (!mounted) return;
    final areas = EstimateBuilder.areasFromMeasurement(
      updated,
      onlyEstimateReady: false,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: '試算表',
          initialLines: merged,
          projectName: project?.name ?? updated.name,
          siteAddress: project?.address,
          sitePhone: project?.phone,
          siteContact: project?.contactName,
          areaLabel: '天井',
          areaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsAreaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          boardAreaM2: areas.boardM2 > 0 ? areas.boardM2 : null,
          rockFeltM: areas.rockFeltM > 0 ? areas.rockFeltM : null,
          glassWoolM2: areas.glassWoolM2 > 0 ? areas.glassWoolM2 : null,
          onSavePersist: (save) => _persistEstimateSave(save, showSnack: false),
        ),
      ),
    );
  }

  Future<void> _rotateCeilingGrid(CeilingRegion region) async {
    if (_measurement == null) return;
    final rotated = CeilingRegion(
      id: region.id,
      points: region.points,
      method: region.method.copyWith(rotated90: !region.method.rotated90),
      quantities: CalcEngine.calcCeiling(
        points: region.points,
        scalePxPerMm: _k,
        method: region.method.copyWith(rotated90: !region.method.rotated90),
      ),
    );
    final list = _measurement!.ceilings
        .map((c) => c.id == region.id ? rotated : c)
        .toList();
    await _persist(_measurement!.copyWith(ceilings: list));
  }

  Future<void> _deleteWall(String wallId, {bool confirm = true}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('壁線を削除'),
          content: const Text(
            'この壁線を削除しますか？\n試算表に含まれている場合、対応する数量も除外されます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('削除'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (_measurement == null) return;
    final walls = _measurement!.walls.where((w) => w.id != wallId).toList();
    final openings = _measurement!.openings
        .map((o) => o.wallId == wallId ? o.copyWith(clearWallId: true) : o)
        .toList();
    await _persist(_measurement!.copyWith(walls: walls, openings: openings));
    if (!mounted) return;
    setState(() {
      if (_selectedWallId == wallId) _selectedWallId = null;
      if (_continueWallId == wallId) _continueWallId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('線を削除しました（試算数量も更新）'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  WallSegment? _wallById(String id) {
    for (final w in _measurement?.walls ?? const <WallSegment>[]) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> _setWallStroke(String? wallId, double width) async {
    setState(() => _strokeWidth = width);
    if (wallId == null || _measurement == null) return;
    final wall = _wallById(wallId);
    if (wall == null) return;
    final updatedWall = wall.copyWith(strokeWidth: width);
    final walls = _measurement!.walls
        .map((w) => w.id == wallId ? updatedWall : w)
        .toList();
    await _persist(_measurement!.copyWith(walls: walls));
  }

  int _wallNumber(String wallId) {
    final walls = _measurement?.walls ?? const [];
    for (var i = 0; i < walls.length; i++) {
      if (walls[i].id == wallId) return i + 1;
    }
    return 1;
  }

  Future<void> _openWallMaterial(String wallId) async {
    final wall = _wallById(wallId);
    if (wall == null || _measurement == null) return;
    setState(() => _selectedWallId = wallId);

    final result = await showModalBottomSheet<WallMaterialResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WallMaterialSheet(
        initialMethod: wall.method,
        initialHeightMm: wall.heightMm,
        wallNumber: _wallNumber(wallId),
        measuredLengthMm: wall.quantities['wall_length_mm'] ??
            _qtyForWall(wall)['wall_length_mm'],
      ),
    );
    if (result == null || _measurement == null || !mounted) return;

    if (result.action == WallMaterialAction.delete) {
      await _deleteWall(wallId);
      return;
    }

    // 番号タップ＝このグループ確定（多線の続きを終了）
    if (_continueWallId == wallId) {
      _continueWallId = null;
    }

    final qty = _qtyForWall(
      wall,
      method: result.method,
      heightMm: result.heightMm,
    );
    final working = wall.copyWith(
      method: result.method,
      heightMm: result.heightMm,
      quantities: qty,
    );
    final walls = _measurement!.walls
        .map((w) => w.id == wallId ? working : w)
        .toList();
    await _persist(_measurement!.copyWith(walls: walls));
    if (!mounted) return;

    // 工法選択 → 試算表
    // 工法選択 → 積算確定後に試算表（確定済み全線を合算）
    final openings = _openingsForWall(wallId);
    final hasReinforce = openings.any(
      (o) => o.material == OpeningMaterialKind.reinforce,
    );
    var paramsMethod = working.method;
    if (hasReinforce) {
      final studLen = paramsMethod.studLengthMm > 0
          ? paramsMethod.studLengthMm
          : working.heightMm;
      paramsMethod = paramsMethod.copyWith(
        useReinforceMaterial: true,
        reinforceWidthMm: paramsMethod.reinforceWidthMm > 0
            ? paramsMethod.reinforceWidthMm
            : paramsMethod.studWidthMm,
        reinforceLengthMm: paramsMethod.reinforceLengthMm > 0
            ? paramsMethod.reinforceLengthMm
            : studLen,
      );
    }
    final params = await showModalBottomSheet<WallParamsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WallParamsSheet(
        initialHeightMm: working.heightMm,
        initialMethod: paramsMethod,
        measuredLengthMm: working.quantities['wall_length_mm'],
        measuredCornerCount: working.cornerCount,
      ),
    );
    if (params == null || _measurement == null || !mounted) return;

    final qty2 = _qtyForWall(
      working,
      method: params.method,
      heightMm: params.heightMm,
    );
    final finalized = working.copyWith(
      heightMm: params.heightMm,
      method: params.method,
      quantities: qty2,
      estimateReady: true,
    );
    final walls2 = _measurement!.walls
        .map((w) => w.id == wallId ? finalized : w)
        .toList();
    final measurement = _measurement!.copyWith(walls: walls2);
    await _persist(measurement);
    if (!mounted) return;

    final lines = EstimateBuilder.fromMeasurement(
      measurement: measurement,
      idGen: () => context.read<AppState>().newId(),
      includeCeilings: false,
    );
    SiteProject? project;
    try {
      project = await context.read<AppState>().db.getProject(
            measurement.projectId,
          );
    } catch (_) {}
    if (!mounted) return;
    final areas = EstimateBuilder.areasFromMeasurement(measurement);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: '試算表',
          initialLines: lines,
          projectName: project?.name ?? measurement.name,
          siteAddress: project?.address,
          sitePhone: project?.phone,
          siteContact: project?.contactName,
          areaLabel: '壁',
          areaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsAreaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          boardAreaM2: areas.boardM2 > 0 ? areas.boardM2 : null,
          rockFeltM: areas.rockFeltM > 0 ? areas.rockFeltM : null,
          glassWoolM2: areas.glassWoolM2 > 0 ? areas.glassWoolM2 : null,
          onSavePersist: (save) => _persistEstimateSave(save, showSnack: false),
        ),
      ),
    );
  }

  Future<void> _persistEstimateSave(
    EstimateSaveResult save, {
    bool showSnack = true,
  }) async {
    if (_measurement == null) return;
    final m = save.kind == EstimateSheetKind.board
        ? _measurement!.copyWith(boardEstimate: save.lines)
        : _measurement!.copyWith(lgsEstimate: save.lines);
    await _persist(m);
    if (!mounted || !showSnack) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${save.kind.label}を保存しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onPointerDown(Offset local) {
    _pointerDownAt = DateTime.now();
    _pointerDownPos = local;
    _longPressHandled = false;

    if (_tool == CanvasTool.pan) return;

    // 番号バッジ付近は描画開始しない
    for (final b in _badgeHits) {
      if (b.hit(local, radius: 28)) return;
    }

    // 既存壁の近く＆ドラフト無し → 選択用（短押しは up）
    if (_tool == CanvasTool.wallPen &&
        _wallPoints.isEmpty &&
        !_touching) {
      final near = hitTestWall(_measurement?.walls ?? const [], local);
      if (near != null) return;
    }

    if (_tool == CanvasTool.wallPen ||
        _tool == CanvasTool.ceilingPen ||
        _tool == CanvasTool.openingReinforce) {
      final tip = _tipFromFinger(local);
      setState(() {
        _touching = true;
        _selectedWallId = null;
        _mouseTip = tip;
        if (_mouseReady) {
          _mouseReady = false;
        }
      });
      _startHoldWatch(tip);
    }
  }

  void _onPointerMove(Offset local) {
    // 長押し削除（確定壁・ドラフト無し）
    if (!_touching &&
        _pointerDownPos != null &&
        !_longPressHandled &&
        _pointerDownAt != null &&
        DateTime.now().difference(_pointerDownAt!) >
            const Duration(milliseconds: 550) &&
        (local - _pointerDownPos!).distance < 12) {
      final id = hitTestWall(_measurement?.walls ?? const [], local);
      if (id != null && _wallPoints.isEmpty) {
        _longPressHandled = true;
        _deleteWall(id);
        return;
      }
    }

    if (!_touching) return;
    if (_tool != CanvasTool.wallPen &&
        _tool != CanvasTool.ceilingPen &&
        _tool != CanvasTool.openingReinforce) {
      return;
    }

    final tip = _tipFromFinger(local);
    setState(() {
      _mouseTip = tip;
    });

    // 停頓判定：アンカーから離れたらホールドやり直し（赤に戻る）
    if (_holdAnchorTip != null &&
        (tip - _holdAnchorTip!).distance > _stillPx) {
      _resetHold(tip);
      _startHoldWatch(tip);
    }
  }

  void _onPointerUp(Offset local) {
    if (_longPressHandled) {
      _touching = false;
      return;
    }

    // 番号バッジ → 材料寸法
    if (!_touching || (_wallPoints.isEmpty && !_startLocked)) {
      for (final b in _badgeHits) {
        if (b.hit(local, radius: 28)) {
          _holdTicker?.cancel();
          setState(() {
            _touching = false;
            _mouseTip = null;
          });
          _openWallMaterial(b.wallId);
          return;
        }
      }
    }

    // 短押し選択（壁）
    if (!_touching || (_wallPoints.isEmpty && !_startLocked)) {
      if (_tool == CanvasTool.wallPen || _tool == CanvasTool.pan) {
        final id = hitTestWall(_measurement?.walls ?? const [], local);
        if (id != null && _wallPoints.isEmpty) {
          setState(() {
            _selectedWallId = _selectedWallId == id ? null : id;
            if (_selectedWallId != null) {
              final w = _wallById(_selectedWallId!);
              if (w != null) {
                _drawColorArgb =
                    w.highlightArgb ?? WallHighlightColors.defaultArgb;
                _strokeWidth = w.strokeWidth;
              }
            }
            _touching = false;
            _mouseTip = null;
          });
          _holdTicker?.cancel();
          return;
        }
      }
    }

    if (_tool == CanvasTool.wallPen && _touching) {
      final wasReady = _mouseReady;
      final pts = _wallPoints.length;
      _holdTicker?.cancel();
      setState(() {
        _touching = false;
        // 緑のまま離したら測定完了
        if (!wasReady) {
          _mouseTip = null;
          _holdProgress = 0;
        }
      });
      if (wasReady && pts >= 2) {
        _finishWallFromMouse();
      } else if (wasReady && pts >= 1) {
        // 緑だが1点だけ → 先端を消さず次のタッチ待ち
        setState(() {
          _mouseReady = false;
          _mouseTip = null;
          _holdProgress = 0;
        });
      }
      return;
    }

    if (_tool == CanvasTool.ceilingPen && _touching) {
      final wasReady = _mouseReady;
      _holdTicker?.cancel();
      setState(() {
        _touching = false;
        _mouseTip = null;
        _mouseReady = false;
        _holdProgress = 0;
      });
      if (wasReady && _ceilingDraft.length >= 3) {
        _confirmCeiling();
      }
    }

    if (_tool == CanvasTool.openingReinforce && _touching) {
      final wasReady = _mouseReady;
      final n = _openingDraft.length;
      _holdTicker?.cancel();
      setState(() {
        _touching = false;
        if (!wasReady) {
          _mouseTip = null;
          _holdProgress = 0;
        }
      });
      if (wasReady && n >= 2) {
        _finishOpeningFromMouse();
      } else if (wasReady && n >= 1) {
        setState(() {
          _mouseReady = false;
          _mouseTip = null;
          _holdProgress = 0;
        });
      }
    }
  }

  List<WallOpening> _openingsForWall(String wallId) {
    return (_measurement?.openings ?? const [])
        .where((o) => o.wallId == wallId)
        .toList();
  }

  Map<String, double> _qtyForWall(
    WallSegment wall, {
    WallMethod? method,
    double? heightMm,
  }) {
    return CalcEngine.calcWall(
      points: wall.points,
      chainStarts: wall.chainStarts,
      heightMm: heightMm ?? wall.heightMm,
      scalePxPerMm: _k,
      method: method ?? wall.method,
      openings: _openingsForWall(wall.id),
    );
  }

  Future<void> _finishOpeningFromMouse() async {
    if (_openingDraft.length < 2 || _measurement == null) return;
    final a = _snapPoint(_openingDraft[0]);
    final b = _snapPoint(_openingDraft[1]);
    final widthMm = CalcEngine.pxToMm(
      Offset(b.x - a.x, b.y - a.y).distance,
      _k,
    );
    setState(() {
      _mouseTip = null;
      _mouseReady = false;
      _holdProgress = 0;
    });
    final result = await showModalBottomSheet<OpeningReinforceResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OpeningReinforceSheet(
        defaultWidthMm: widthMm > 50 ? widthMm : 900,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _openingDraft.clear());
      return;
    }
    final opening = WallOpening(
      id: context.read<AppState>().newId(),
      a: Point2(a.x, a.y),
      b: Point2(b.x, b.y),
      highlightArgb: _drawColorArgb,
      markerSize: _strokeWidth.clamp(8, 56),
      patternName: result.pattern.name,
      material: result.material,
      heightMm: result.heightMm,
      widthMm: result.widthMm,
      magusaSegments: result.magusaSegments,
    );
    await _persist(
      _measurement!.copyWith(
        openings: [..._measurement!.openings, opening],
      ),
    );
    if (!mounted) return;
    setState(() {
      _openingDraft.clear();
      _openingSetupDone = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '開口補強を追加（${result.pattern.label}／${result.material.label}）'
          '。続けて追加するか、壁マウスで画線',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 画線が開口マーカー付近を通ったら紐付け
  List<WallOpening> _linkOpeningsToWall(
    List<WallOpening> openings,
    WallSegment wall,
  ) {
    return openings.map((o) {
      if (o.wallId != null && o.wallId!.isNotEmpty) return o;
      if (OpeningReinforceCalc.openingNearWall(
        opening: o,
        wall: wall,
        maxDistPx: math.max(48, wall.strokeWidth * 3),
      )) {
        return o.copyWith(wallId: wall.id);
      }
      return o;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final m = _measurement;
    return Scaffold(
      appBar: AppBar(
        title: Text(m?.name ?? '測定'),
        actions: [
          IconButton(
            tooltip: _snapEnabled ? '吸着ON' : '吸着OFF',
            onPressed: () => setState(() => _snapEnabled = !_snapEnabled),
            icon: Icon(
              _snapEnabled ? Icons.center_focus_strong : Icons.center_focus_weak,
              color: _snapEnabled ? AppTheme.safetyYellow : Colors.white70,
            ),
          ),
          if (m != null && m.ceilings.isNotEmpty)
            IconButton(
              tooltip: '天井グリッド90°回転',
              onPressed: () => _rotateCeilingGrid(m.ceilings.last),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
            ),
        ],
      ),
      body: m == null || _bgImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _toolbar(),
                WallHighlightColorBar(
                  selectedArgb: _drawColorArgb,
                  strokeWidth: _selectedWallId != null
                      ? (_wallById(_selectedWallId!)?.strokeWidth ??
                          _strokeWidth)
                      : _strokeWidth,
                  onSelect: (c) {
                    // 線色は「これから描く線」専用。既存線の色は変えない
                    setState(() => _drawColorArgb = c);
                  },
                  onStrokeWidth: (w) {
                    if (_selectedWallId != null) {
                      _setWallStroke(_selectedWallId, w);
                    } else {
                      setState(() => _strokeWidth = w);
                    }
                  },
                ),
                Expanded(child: _canvas()),
                _bottomBar(),
              ],
            ),
    );
  }

  Widget _toolbar() {
    Widget chip(String label, CanvasTool tool, Widget icon) {
      final sel = _tool == tool;
      return ChoiceChip(
        selected: sel,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (_) async {
          if (tool == CanvasTool.wallPen) {
            if (!_openingSetupDone &&
                (_measurement?.openings.isEmpty ?? true)) {
              final go = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('開口補強の確認'),
                  content: const Text(
                    '壁マウスの前に開口補強を設定してください。\n'
                    '開口がない場合は「開口なし」で続行できます。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'cancel'),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'opening'),
                      child: const Text('開口補強へ'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, 'skip'),
                      child: const Text('開口なし'),
                    ),
                  ],
                ),
              );
              if (!mounted) return;
              if (go == null || go == 'cancel') return;
              if (go == 'opening') {
                setState(() {
                  _tool = CanvasTool.openingReinforce;
                  _openingDraft.clear();
                  _clearWallDraft(notify: false);
                });
                return;
              }
              _openingSetupDone = true;
            }
            final mode = await _pickWallDrawMode();
            if (mode == null || !mounted) return;
            setState(() {
              _tool = CanvasTool.wallPen;
              _wallDrawMode = mode;
              if (mode == WallDrawMode.single) {
                _continueWallId = null;
              }
              _clearWallDraft(notify: false);
              _openingDraft.clear();
            });
            if (mode == WallDrawMode.multi && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '多線モード：壁高さ・工法は同一に。'
                    '画線後に番号が最新線尾へ移動します',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
          if (tool == CanvasTool.openingReinforce) {
            setState(() {
              _tool = CanvasTool.openingReinforce;
              _openingSetupDone = true;
              _clearWallDraft(notify: false);
              _openingDraft.clear();
              _continueWallId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '開口補強：線色を選び、開口の両端を各1.5秒で確定',
                ),
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
          setState(() {
            _tool = tool;
            if (tool == CanvasTool.pan) {
              _clearWallDraft(notify: false);
              _openingDraft.clear();
            }
            if (tool != CanvasTool.wallPen) {
              _continueWallId = null;
            }
          });
        },
        selectedColor: AppTheme.safetyYellow,
      );
    }

    final modeHint = _tool == CanvasTool.openingReinforce
        ? '［開口補強］'
        : _tool != CanvasTool.wallPen
            ? ''
            : (_wallDrawMode == WallDrawMode.multi ? '［多線］' : '［単線］');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('移動', CanvasTool.pan, const Icon(Icons.open_with, size: 16)),
            const SizedBox(width: 6),
            chip(
              '開口補強',
              CanvasTool.openingReinforce,
              const Icon(Icons.crop_square, size: 16),
            ),
            const SizedBox(width: 6),
            chip('壁マウス', CanvasTool.wallPen, const MouseToolIcon(size: 14)),
            const SizedBox(width: 6),
            chip('天井マウス', CanvasTool.ceilingPen, const MouseToolIcon(size: 14)),
            const SizedBox(width: 10),
            Text(
              _touching
                  ? (_mouseReady
                      ? '緑：離すと完了／移動で次点'
                      : '赤：1.5秒停頓で緑に')
                  : (modeHint == '［開口補強］'
                      ? '開口の両端を確定→形状・材料を選択'
                      : (modeHint.isEmpty
                          ? '画完→線尾に番号表示。番号タップで工法選択／削除'
                          : '$modeHint 画完→線尾番号。番号タップで工法選択／削除')),
              style: const TextStyle(fontSize: 12, color: AppTheme.steel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.05,
              maxScale: 20,
              panEnabled: _tool == CanvasTool.pan || !_touching,
              scaleEnabled: true,
              child: SizedBox(
                width: _imageSize.width,
                height: _imageSize.height,
                child: Listener(
                  onPointerDown: (e) {
                    if (_tool == CanvasTool.pan) return;
                    _onPointerDown(e.localPosition);
                  },
                  onPointerMove: (e) {
                    if (_tool == CanvasTool.pan) return;
                    _onPointerMove(e.localPosition);
                  },
                  onPointerUp: (e) {
                    _onPointerUp(e.localPosition);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RawImage(image: _bgImage, fit: BoxFit.fill),
                      CustomPaint(
                        painter: OverlayMidPainter(
                          snapLines:
                              _snapEnabled ? _snapLines : const [],
                          ceilings: _measurement!.ceilings,
                          ceilingDraft: _ceilingDraft,
                          scalePxPerMm: _k,
                          wallDraft: [
                            ..._wallPoints,
                            if (_touching &&
                                _mouseTip != null &&
                                !_mouseReady)
                              _mouseTip!,
                          ],
                        ),
                      ),
                      CustomPaint(
                        painter: OverlayTopPainter(
                          walls: _measurement!.walls,
                          ceilings: _measurement!.ceilings,
                          openings: _measurement!.openings,
                          openingDraft: [
                            ..._openingDraft,
                            if (_tool == CanvasTool.openingReinforce &&
                                _touching &&
                                _mouseTip != null &&
                                !_mouseReady &&
                                _openingDraft.length < 2)
                              _mouseTip!,
                          ],
                          openingDraftArgb: _drawColorArgb,
                          openingDraftMarkerSize: _strokeWidth,
                          scalePxPerMm: _k,
                          selectedWallId: _selectedWallId,
                          badgeHits: _badgeHits,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 画面固定サイズのマウス（ズーム非連動）
            if (_touching && _mouseTip != null)
              AnimatedBuilder(
                animation: _transform,
                builder: (context, _) {
                  final screenTip = MatrixUtils.transformPoint(
                    _transform.value,
                    _mouseTip!,
                  );
                  const boxW = 80.0;
                  const boxH = 130.0;
                  return Positioned(
                    left: screenTip.dx - boxW / 2,
                    top: screenTip.dy - 4,
                    width: boxW,
                    height: boxH,
                    child: IgnorePointer(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: const Size(boxW, boxH),
                            painter: HoldProgressPainter(
                              center: Offset(boxW / 2, 8),
                              progress: _holdProgress,
                              color: _mouseReady
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(boxW, boxH),
                            painter: MeasureMousePainter(
                              tip: Offset(boxW / 2, 4),
                              ready: _mouseReady,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        color: Colors.white,
        child: Row(
          children: [
            if (_tool == CanvasTool.ceilingPen) ...[
              OutlinedButton(
                onPressed: _ceilingDraft.isEmpty
                    ? null
                    : () => setState(() => _ceilingDraft.removeLast()),
                child: const Text('点取消'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _ceilingDraft.isEmpty
                    ? null
                    : () => setState(() {
                          _ceilingDraft.clear();
                          _clearWallDraft();
                        }),
                child: const Text('クリア'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _confirmCeiling,
                child: const Text('確認（天井）'),
              ),
            ] else if (_tool == CanvasTool.wallPen) ...[
              OutlinedButton(
                onPressed: (_wallPoints.isEmpty && _mouseTip == null)
                    ? null
                    : _clearWallDraft,
                child: const Text('クリア'),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    '単線＝1本1番号／多線＝合算1番号（番号は最新線尾へ移動）',
                    style: TextStyle(fontSize: 12, color: AppTheme.steel),
                  ),
                ),
              ),
            ] else ...[
              const Expanded(
                child: Text(
                  'ピンチで拡大。壁線タップ＝色・十字入力／長押し＝削除。',
                  style: TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
