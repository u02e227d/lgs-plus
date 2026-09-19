import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../account/account_screen.dart';
import '../../services/calc_engine.dart';
import '../../services/edge_snap_engine.dart';
import '../../services/estimate_builder.dart';
import '../../services/feature_access.dart';
import '../../services/app_platform.dart';
import '../../theme/app_theme.dart';
import '../../widgets/drop_draw_guide.dart';
import '../../widgets/measure_mouse.dart';
import '../../widgets/measure_painters.dart';
import '../../widgets/wall_triad_editor.dart';
import 'ceiling_params_sheet.dart';
import 'ceiling_material_sheet.dart';
import 'drop_settings_sheet.dart';
import 'estimate_table_screen.dart';
import 'opening_reinforce_sheet.dart';
import 'cross_dedicated_sheet.dart';
import 'iron_plate_measure_sheet.dart';
import 'wall_material_sheet.dart';
import 'wall_params_sheet.dart';
import '../../services/opening_reinforce.dart';
import '../../services/drop_calc.dart';

enum CanvasTool { pan, wallPen, ceilingPen, dropPen, openingReinforce }

/// 壁マウスの画線モード
enum WallDrawMode { single, multi, ironPlate }

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
  final List<Offset> _dropDraft = [];
  final List<DropTurnWidth> _dropDraftTurnWidths = [];
  bool _dropSecWidthMode = false;
  String? _dropSecWidthDropId; // null＝ドラフト
  Offset? _dropSecWidthOrigin;
  int _dropSecWidthTurnIndex = 2;
  bool _openingSetupDone = false;
  bool _chromeCollapsed = false;

  String? _selectedWallId;
  String? _selectedCeilingId;
  String? _selectedDropId;
  String? _continueWallId;
  /// 次に描く天井の番号（統合時は既存番号を継続）
  int _ceilingGroupNumber = 1;
  bool _ceilingUnifyWithPrevious = false;
  int _dropGroupNumber = 1;
  bool _dropUnifyWithPrevious = false;
  final List<WallBadgeHit> _badgeHits = [];
  final List<CeilingBadgeHit> _ceilingBadgeHits = [];
  final List<DropBadgeHit> _dropBadgeHits = [];
  final List<DropWidthPlusHit> _dropWidthPlusHits = [];
  final List<OpeningMarkerHit> _openingHits = [];
  int _drawColorArgb = WallHighlightColors.defaultArgb;
  double _strokeWidth = 8;
  DateTime? _pointerDownAt;
  Offset? _pointerDownPos;
  bool _longPressHandled = false;
  DateTime? _ignoreNumberOpenUntil;
  bool _openedNumberOnDown = false;

  ui.Image? _bgImage;
  Size _imageSize = Size.zero;

  static const _holdNeed = Duration(milliseconds: 1500);
  static const _stillPx = 14.0;

  // Mac：測定キャンバスの拡大縮小・移動
  static bool get _isMac => AppPlatform.usesDesktopPointer;
  Offset? _macNavDownPos;
  DateTime? _macNavLastTapAt;
  Offset? _macNavLastTapPos;
  bool _macNavPanning = false;
  int? _macNavPointer;
  Timer? _macNavTapTimer;
  static const _macNavClickSlop = 6.0;
  static const _macNavDoubleTapMs = 350;
  static const _macNavZoomIn = 1.35;
  static const _macNavZoomOut = 1 / 1.35;

  List<LineSeg> get _snapLines => _snap.lines;

  double _scaleK = 1;

  @override
  void initState() {
    super.initState();
    _scaleK = widget.drawing.scalePxPerMm ?? 1;
    _boot();
  }

  @override
  void dispose() {
    _macNavTapTimer?.cancel();
    _holdTicker?.cancel();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final state = context.read<AppState>();
    final m = await state.db.getMeasurement(widget.measurementId);
    // 比例尺は DB → SharedPreferences の順でローカル復元
    var drawing = await state.db.getDrawing(widget.drawing.id) ?? widget.drawing;
    var k = drawing.scalePxPerMm;
    if (k == null || k <= 0) {
      final prefs = await SharedPreferences.getInstance();
      k = prefs.getDouble('drawing_scale_${drawing.id}');
      if (k != null && k > 0) {
        drawing = drawing.copyWith(scalePxPerMm: k);
        await state.saveDrawing(drawing);
      }
    }
    final bytes = await File(drawing.localPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _bgImage = frame.image;
    _imageSize = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );

    if (!mounted) return;
    setState(() {
      _scaleK = drawing.scalePxPerMm ?? 1;
      _measurement = m;
      if ((m?.openings.isNotEmpty ?? false)) {
        _openingSetupDone = true;
      }
    });
  }

  double get _k => _scaleK > 0 ? _scaleK : 1;

  double get _viewScale {
    final s = _transform.value.getMaxScaleOnAxis();
    return s <= 0 ? 1.0 : s;
  }

  Point2 _snapPoint(Offset raw) {
    final p = Point2(raw.dx, raw.dy);
    if (!_snapEnabled) return p;
    return _snap.snap(p);
  }

  void _toggleSnap() {
    setState(() => _snapEnabled = !_snapEnabled);
    final ms = Ms.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_snapEnabled ? ms.snapOnHint : ms.snapOffHint),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Offset _tipFromFinger(Offset finger) {
    // Mac：実ポインタ位置＝先端（十字カーソルのホットスポット）
    final raw = _isMac
        ? finger
        : MeasureMousePainter.tipFromFinger(finger, _viewScale);
    final s = _snapPoint(raw);
    return Offset(s.x, s.y);
  }

  Offset _viewportToContent(Offset viewport) {
    final inv = Matrix4.inverted(_transform.value);
    return MatrixUtils.transformPoint(inv, viewport);
  }

  Offset _contentToViewport(Offset content) {
    return MatrixUtils.transformPoint(_transform.value, content);
  }

  void _zoomAtViewport(Offset focalViewport, double factor) {
    final current = _transform.value;
    final scale = current.getMaxScaleOnAxis();
    if (scale <= 0) return;
    final nextScale = (scale * factor).clamp(0.05, 20.0);
    final ratio = nextScale / scale;
    if ((ratio - 1).abs() < 1e-6) return;

    final sceneFocal = _viewportToContent(focalViewport);
    final matrix = Matrix4.identity()
      ..translateByDouble(focalViewport.dx, focalViewport.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-focalViewport.dx, -focalViewport.dy, 0, 1)
      ..multiply(current);

    final after = MatrixUtils.transformPoint(matrix, sceneFocal);
    matrix.translateByDouble(
      focalViewport.dx - after.dx,
      focalViewport.dy - after.dy,
      0,
      1,
    );
    _transform.value = matrix;
  }

  bool get _macClickZoomEnabled =>
      _isMac &&
      !_touching &&
      !_dropSecWidthMode &&
      _tool == CanvasTool.pan;

  void _macNavPointerDown(PointerDownEvent e, Offset local) {
    if (!_macClickZoomEnabled) return;
    _macNavPointer = e.pointer;
    _macNavDownPos = local;
    _macNavPanning = false;
  }

  void _macNavPointerMove(PointerMoveEvent e, Offset local) {
    if (e.pointer != _macNavPointer || _macNavDownPos == null) return;
    final delta = local - _macNavDownPos!;
    if (delta.distance > _macNavClickSlop) {
      _macNavTapTimer?.cancel();
      _macNavTapTimer = null;
      _macNavLastTapAt = null;
      _macNavLastTapPos = null;
      _macNavPanning = true;
    }
  }

  void _macNavPointerUp(PointerEvent e, Offset local) {
    if (e.pointer != _macNavPointer) return;
    final wasPanning = _macNavPanning;
    final downPos = _macNavDownPos;
    _macNavPointer = null;
    _macNavDownPos = null;
    _macNavPanning = false;

    if (!_isMac || _touching || _dropSecWidthMode || _tool != CanvasTool.pan) {
      return;
    }
    if (wasPanning || downPos == null) return;

    final now = DateTime.now();
    final isDouble = _macNavLastTapAt != null &&
        now.difference(_macNavLastTapAt!) <
            const Duration(milliseconds: _macNavDoubleTapMs) &&
        _macNavLastTapPos != null &&
        (local - _macNavLastTapPos!).distance < 28;

    if (isDouble) {
      _macNavTapTimer?.cancel();
      _macNavTapTimer = null;
      _macNavLastTapAt = null;
      _macNavLastTapPos = null;
      _zoomAtViewport(_contentToViewport(local), _macNavZoomIn);
      return;
    }

    _macNavLastTapAt = now;
    _macNavLastTapPos = local;
    _macNavTapTimer?.cancel();
    _macNavTapTimer = Timer(
      const Duration(milliseconds: _macNavDoubleTapMs),
      () {
        if (!mounted) return;
        final focal = _macNavLastTapPos;
        _macNavLastTapAt = null;
        _macNavLastTapPos = null;
        _macNavTapTimer = null;
        if (focal != null && _tool == CanvasTool.pan && !_touching) {
          _zoomAtViewport(_contentToViewport(focal), _macNavZoomOut);
        }
      },
    );
  }

  void _macNavScrollZoom(PointerScrollEvent e, Offset local) {
    if (!_isMac || _touching || _dropSecWidthMode) return;
    // トラックパッド／マウスホイールで拡大縮小
    final dy = e.scrollDelta.dy;
    if (dy.abs() < 0.1) return;
    final factor = dy > 0 ? (1 / 1.12) : 1.12;
    _zoomAtViewport(local, factor);
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

    if (_dropSecWidthMode) {
      setState(() {
        _mouseReady = true;
        _holdProgress = 1;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Ms.of(context).greenConfirmMark(
              dropWidthCircleLabel(_dropSecWidthTurnIndex),
            ),
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
      return;
    }

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
                ? Ms.of(context).greenStartNext
                : Ms.of(context).greenPointContinue,
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } else if (_tool == CanvasTool.ceilingPen) {
      final tip = _mouseTip!;
      setState(() {
        _mouseReady = true;
        _holdProgress = 1;
        final nearStart = _ceilingDraft.length >= 3 &&
            (tip - _ceilingDraft.first).distance <= 40;
        if (nearStart) {
          // 始点へ閉合（頂点は増やさない）
        } else if (_ceilingDraft.isEmpty ||
            (_ceilingDraft.last - tip).distance >= 12) {
          _ceilingDraft.add(tip);
        }
      });
      final closed = _ceilingDraft.length >= 3 &&
          _mouseTip != null &&
          (_mouseTip! - _ceilingDraft.first).distance <= 40;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            closed
                ? Ms.of(context).closeOkRelease
                : (_ceilingDraft.length < 3
                    ? Ms.of(context).greenNeed3
                    : Ms.of(context).greenContinueClose),
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } else if (_tool == CanvasTool.dropPen) {
      final tip = _mouseTip!;
      setState(() {
        _mouseTip = tip;
        _mouseReady = true;
        _holdProgress = 1;
        if (_dropDraft.isEmpty ||
            (_dropDraft.last - tip).distance >= 12) {
          _dropDraft.add(tip);
        }
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final n = _dropDraft.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n <= 1
                ? Ms.of(context).greenDropStart
                : (n == 2
                    ? Ms.of(context).greenDropBend
                    : Ms.of(context).greenDropMore),
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
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
          SnackBar(
            content: Text(Ms.of(context).openingFirstPoint),
            duration: const Duration(milliseconds: 1400),
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
        SnackBar(content: Text(Ms.of(context).needMorePoints)),
      );
      return;
    }
    _clearWallDraft();
    await _commitWallLine(cleaned);
    _armNumberOpenIgnore();
    if (mounted) {
      setState(() => _tool = CanvasTool.pan);
    }
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
          highlightArgb: existing.highlightArgb ?? _drawColorArgb,
          strokeWidth: existing.strokeWidth,
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
        final openingM2 = qty['opening_area_m2'] ?? 0.0;
        final netM2 = qty['wall_net_area_m2'] ?? 0.0;
        setState(() => _selectedWallId = existing.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              openingM2 > 0
                  ? Ms.of(context).wallMergedOpen(
                      num,
                      updatedWall.chains.length,
                      netM2.toStringAsFixed(2),
                      openingM2.toStringAsFixed(2),
                    )
                  : Ms.of(context).wallMerged(num, updatedWall.chains.length),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    } else {
      _continueWallId = null;
    }

    final method = _wallDrawMode == WallDrawMode.ironPlate
        ? const WallMethod(
            useLgs: false,
            useBoard: false,
            useBoardFaceA: false,
            useBoardFaceB: false,
            bothSides: false,
            useFureDome: false,
            useIronPlate: true,
          )
        : const WallMethod();
    const heightMm = 2700.0;
    final ironMeasured = _wallDrawMode == WallDrawMode.ironPlate;
    final seg = WallSegment(
      id: context.read<AppState>().newId(),
      points: pts,
      heightMm: heightMm,
      method: method,
      quantities: const {},
      highlightArgb: _drawColorArgb,
      strokeWidth: _strokeWidth,
      estimateReady: false,
      ironPlateMeasured: ironMeasured,
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
    final qty = Map<String, double>.from(
      CalcEngine.calcWall(
        points: pts,
        heightMm: heightMm,
        scalePxPerMm: _k,
        method: method2,
        openings: openings.where((o) => o.wallId == seg.id).toList(),
      ),
    );
    final painted = _paintedMmOfPoints(pts);
    var fullRun = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      fullRun += CalcEngine.pxToMm(CalcEngine.distPx(pts[i], pts[i + 1]), _k);
    }
    if (fullRun > 0 || painted.runMm > 0) {
      qty['wall_length_mm'] = fullRun > 0 ? fullRun : painted.runMm;
      qty['iron_plate_measure_mm'] =
          ironMeasured ? (fullRun > 0 ? fullRun : painted.runMm) : painted.tipMm;
    }
    if (ironMeasured) {
      qty['iron_plate_draw'] = 1;
    }
    final seg2 = WallSegment(
      id: seg.id,
      points: pts,
      heightMm: heightMm,
      method: method2,
      quantities: qty,
      highlightArgb: _drawColorArgb,
      strokeWidth: _strokeWidth,
      estimateReady: false,
      ironPlateMeasured: ironMeasured,
    );
    final walls = [..._measurement!.walls, seg2];
    await _persist(
      _measurement!.copyWith(walls: walls, openings: openings),
    );
    if (!mounted) return;
    _continueWallId =
        _wallDrawMode == WallDrawMode.multi ? seg2.id : null;
    setState(() => _selectedWallId = seg2.id);
    final openingM2 = qty['opening_area_m2'] ?? 0.0;
    final netM2 = qty['wall_net_area_m2'] ?? qty['wall_gross_area_m2'] ?? 0.0;
    final num = _wallNumber(seg2.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openingM2 > 0
              ? Ms.of(context).wallAreaOpen(
                  num,
                  netM2.toStringAsFixed(2),
                  openingM2.toStringAsFixed(2),
                )
              : _wallDrawMode == WallDrawMode.ironPlate
                  ? Ms.of(context).ironLineAdded
                  : (_wallDrawMode == WallDrawMode.multi
                      ? Ms.of(context).wallMultiStarted(num)
                      : Ms.of(context).wallLineAdded(num)),
        ),
        duration: const Duration(seconds: 3),
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
                Text(
                  Ms.of(ctx).wallDrawTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.timeline, color: AppTheme.navy),
                  title: Text(
                    Ms.of(ctx).singleLine,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(Ms.of(ctx).singleLineSub),
                  onTap: () => Navigator.pop(ctx, WallDrawMode.single),
                ),
                ListTile(
                  leading: const Icon(Icons.account_tree, color: AppTheme.accent),
                  title: Text(
                    Ms.of(ctx).multiLine,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(Ms.of(ctx).multiLineSub),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(ctx, WallDrawMode.multi),
                ),
                ListTile(
                  leading: const Icon(Icons.square_foot, color: AppTheme.navy),
                  title: Text(
                    Ms.of(ctx).ironOnly,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(Ms.of(ctx).ironOnlySub),
                  onTap: () => Navigator.pop(ctx, WallDrawMode.ironPlate),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(S.of(ctx).cancel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _maxCeilingGroupNumber() {
    final list = _measurement?.ceilings ?? const <CeilingRegion>[];
    var maxN = 0;
    for (final c in list) {
      if (c.groupNumber > maxN) maxN = c.groupNumber;
    }
    return maxN;
  }

  CeilingRegion? _lastCeiling() {
    final list = _measurement?.ceilings;
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  /// 統合中は既存番号の色を使う。線色バーを変えても既描画は変えない。
  int _colorForNewCeiling() {
    if (_ceilingUnifyWithPrevious) {
      final last = _lastCeiling();
      if (last?.highlightArgb != null) return last!.highlightArgb!;
      for (final c in _measurement?.ceilings ?? const <CeilingRegion>[]) {
        if (c.groupNumber == _ceilingGroupNumber && c.highlightArgb != null) {
          return c.highlightArgb!;
        }
      }
    }
    return _drawColorArgb;
  }

  int _colorForNewDrop() {
    if (_dropUnifyWithPrevious) {
      final last = _lastDrop();
      if (last?.highlightArgb != null) return last!.highlightArgb!;
    }
    return _drawColorArgb;
  }

  Future<bool> _askCeilingUnify() async {
    final last = _lastCeiling();
    final lastNum = last?.groupNumber ?? 1;
    final nextNum = _maxCeilingGroupNumber() + 1;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).mergeCeilTitle),
        content: Text(Ms.of(ctx).mergeCeilBody(lastNum, nextNum)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Ms.of(ctx).mergeNo(nextNum)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Ms.of(ctx).mergeYes(lastNum)),
          ),
        ],
      ),
    );
    if (go == null) return false;
    setState(() {
      _ceilingUnifyWithPrevious = go;
      if (go) {
        _ceilingGroupNumber = lastNum;
        if (last?.highlightArgb != null) {
          _drawColorArgb = last!.highlightArgb!;
        }
      } else {
        _ceilingGroupNumber = nextNum;
      }
    });
    return true;
  }

  Future<void> _activateCeilingPen() async {
    final hasCeilings = _measurement?.ceilings.isNotEmpty ?? false;
    if (hasCeilings) {
      final ok = await _askCeilingUnify();
      if (!ok || !mounted) return;
    } else {
      _ceilingGroupNumber = 1;
      _ceilingUnifyWithPrevious = false;
    }
    setState(() {
      _tool = CanvasTool.ceilingPen;
      _ceilingDraft.clear();
      _clearWallDraft(notify: false);
      _openingDraft.clear();
      _dropDraft.clear();
      _continueWallId = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _ceilingUnifyWithPrevious
              ? Ms.of(context).ceilMouseMerged(_ceilingGroupNumber)
              : Ms.of(context).ceilMouse(_ceilingGroupNumber),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearDropSecWidthMode({bool clearMouse = true}) {
    _dropSecWidthMode = false;
    _dropSecWidthDropId = null;
    _dropSecWidthOrigin = null;
    _dropSecWidthTurnIndex = 2;
    _dropWidthPlusHits.clear();
    if (clearMouse) {
      _touching = false;
      _mouseTip = null;
      _mouseReady = false;
      _holdProgress = 0;
    }
  }

  DropRegion? _lastDrop() {
    final list = _measurement?.drops ?? const <DropRegion>[];
    if (list.isEmpty) return null;
    return list.last;
  }

  int _maxDropGroupNumber() {
    var n = 0;
    for (final d in _measurement?.drops ?? const <DropRegion>[]) {
      if (d.groupNumber > n) n = d.groupNumber;
    }
    return n;
  }

  Future<bool> _askDropUnify() async {
    final last = _lastDrop();
    final lastNum = last?.groupNumber ?? 1;
    final nextNum = _maxDropGroupNumber() + 1;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).mergeDropTitle),
        content: Text(Ms.of(ctx).mergeDropBody(lastNum, nextNum)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Ms.of(ctx).mergeNo(nextNum)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Ms.of(ctx).mergeYes(lastNum)),
          ),
        ],
      ),
    );
    if (go == null) return false;
    setState(() {
      _dropUnifyWithPrevious = go;
      if (go) {
        _dropGroupNumber = lastNum;
        if (last?.highlightArgb != null) {
          _drawColorArgb = last!.highlightArgb!;
        }
      } else {
        _dropGroupNumber = nextNum;
      }
    });
    return true;
  }

  Future<void> _showDropDrawGuide() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).dropGuideTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DropDrawGuide(width: 220, height: 150),
            const SizedBox(height: 12),
            Text(Ms.of(ctx).dropGuideBody),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Ms.of(ctx).confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _activateDropPen() async {
    final hasDrops = _measurement?.drops.isNotEmpty ?? false;
    if (hasDrops) {
      final ok = await _askDropUnify();
      if (!ok || !mounted) return;
    } else {
      _dropGroupNumber = 1;
      _dropUnifyWithPrevious = false;
    }
    setState(() {
      _dropDraft.clear();
      _dropDraftTurnWidths.clear();
      _clearDropSecWidthMode();
      _tool = CanvasTool.dropPen;
      _clearWallDraft(notify: false);
      _openingDraft.clear();
      _ceilingDraft.clear();
    });
    if (!mounted) return;
    await _showDropDrawGuide();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _dropUnifyWithPrevious
              ? Ms.of(context).dropMouseMerged(_dropGroupNumber)
              : Ms.of(context).dropMouse(_dropGroupNumber),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _hitDrop(DropRegion d, Offset p, {double thresh = 18}) {
    for (var i = 0; i < d.points.length - 1; i++) {
      final a = Offset(d.points[i].x, d.points[i].y);
      final b = Offset(d.points[i + 1].x, d.points[i + 1].y);
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (len2 < 1e-6) {
        if ((p - a).distance <= thresh) return true;
        continue;
      }
      var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
      t = t.clamp(0.0, 1.0);
      final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      if ((p - proj).distance <= thresh) return true;
    }
    return false;
  }

  Future<void> _finishDropFromMouse() async {
    if (_measurement == null || _dropDraft.length < 3) return;
    final pts = [
      for (final o in _dropDraft)
        () {
          final s = _snapPoint(o);
          return Offset(s.x, s.y);
        }(),
    ];
    final point2s = [for (final o in pts) Point2(o.dx, o.dy)];
    // 始点→第1折点＝幅、それ以降の全区間合計＝長さ
    final widthMm = CalcEngine.pxToMm((pts[1] - pts[0]).distance, _k);
    var lengthMm = 0.0;
    for (var i = 1; i < pts.length - 1; i++) {
      lengthMm += CalcEngine.pxToMm((pts[i + 1] - pts[i]).distance, _k);
    }
    final turns = List<DropTurnWidth>.from(_dropDraftTurnWidths);
    setState(() {
      _mouseTip = null;
      _mouseReady = false;
      _holdProgress = 0;
    });
    DropMethod method = const DropMethod();
    var heightMm = 300.0;
    if (_dropUnifyWithPrevious) {
      final last = _lastDrop();
      if (last != null) {
        method = last.method;
        if (last.heightMm > 0) heightMm = last.heightMm;
      }
    }
    final qty = DropCalc.calc(
      lengthMm: lengthMm,
      widthMm: widthMm,
      heightMm: heightMm,
      method: method,
      points: point2s,
      scalePxPerMm: _k,
      turnWidths: turns,
    );
    final drop = DropRegion(
      id: context.read<AppState>().newId(),
      points: point2s,
      lengthMm: lengthMm,
      widthMm: widthMm,
      heightMm: heightMm,
      turnWidths: turns,
      method: method,
      quantities: qty,
      highlightArgb: _colorForNewDrop(),
      groupNumber: _dropGroupNumber,
    );
    await _persist(
      _measurement!.copyWith(drops: [..._measurement!.drops, drop]),
    );
    if (!mounted) return;
    setState(() {
      _dropDraft.clear();
      _dropDraftTurnWidths.clear();
      _clearDropSecWidthMode();
      _tool = CanvasTool.pan;
      _selectedDropId = drop.id;
    });
    _armNumberOpenIgnore();
    final nPlus = pts.length >= 4 ? Ms.of(context).dropPlusHint : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          turns.isNotEmpty
              ? Ms.of(context).dropAddedExtra(drop.groupNumber, turns.length)
              : '${Ms.of(context).dropAdded(drop.groupNumber)}$nPlus',
        ),
      ),
    );
  }

  void _startDropSecondWidthMeasure(DropWidthPlusHit hit) {
    _holdTicker?.cancel();
    setState(() {
      _dropSecWidthMode = true;
      _dropSecWidthDropId = hit.isDraft ? null : hit.dropId;
      _dropSecWidthOrigin = hit.origin;
      _dropSecWidthTurnIndex = hit.turnIndex;
      _mouseTip = hit.origin;
      _mouseReady = false;
      _holdProgress = 0;
      // 指を一旦離してからドラッグ（InteractiveViewer のパンと競合しない）
      _touching = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Ms.of(context).secWidthDrag(dropWidthCircleLabel(hit.turnIndex)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onPointerDownSecWidth(Offset local) {
    final tip = _tipFromFinger(local);
    setState(() {
      _touching = true;
      _mouseTip = tip;
      _mouseReady = false;
    });
    _startHoldWatch(tip);
  }

  void _onPointerMoveSecWidth(Offset local) {
    if (!_touching) return;
    final tip = _tipFromFinger(local);
    setState(() => _mouseTip = tip);
    if (_holdAnchorTip != null &&
        (tip - _holdAnchorTip!).distance > _stillPx) {
      _resetHold(tip);
      _startHoldWatch(tip);
    }
  }

  void _onPointerUpSecWidth(Offset local) {
    final wasReady = _mouseReady;
    final tip = _mouseTip;
    _holdTicker?.cancel();
    if (wasReady && tip != null && _dropSecWidthOrigin != null) {
      _finishDropSecondWidthMeasure(tip);
    } else {
      setState(() {
        _touching = false;
        _mouseTip = null;
        _mouseReady = false;
        _holdProgress = 0;
      });
    }
  }

  Future<void> _finishDropSecondWidthMeasure(Offset tip) async {
    final origin = _dropSecWidthOrigin;
    if (origin == null) return;
    final turnIndex = _dropSecWidthTurnIndex;
    final mm = CalcEngine.pxToMm((tip - origin).distance, _k);
    if (mm < 10) {
      setState(_clearDropSecWidthMode);
      return;
    }
    final tw = DropTurnWidth(
      turnIndex: turnIndex,
      widthMm: mm,
      from: Point2(origin.dx, origin.dy),
      to: Point2(tip.dx, tip.dy),
    );
    final dropId = _dropSecWidthDropId;
    if (dropId == null) {
      setState(() {
        _dropDraftTurnWidths
          ..removeWhere((e) => e.turnIndex == turnIndex)
          ..add(tw)
          ..sort((a, b) => a.turnIndex.compareTo(b.turnIndex));
        _clearDropSecWidthMode();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Ms.of(context).secWidthRecorded(
              dropWidthCircleLabel(turnIndex),
              mm.round(),
            ),
          ),
        ),
      );
      return;
    }
    if (_measurement == null) return;
    DropRegion? drop;
    for (final d in _measurement!.drops) {
      if (d.id == dropId) {
        drop = d;
        break;
      }
    }
    if (drop == null) return;
    final updatedBase = drop.withTurnWidth(tw);
    final qty = DropCalc.calc(
      lengthMm: updatedBase.lengthMm,
      widthMm: updatedBase.widthMm,
      heightMm: updatedBase.heightMm,
      method: updatedBase.method,
      points: updatedBase.points,
      scalePxPerMm: _k,
      turnWidths: updatedBase.turnWidths,
    );
    final updated = updatedBase.copyWith(quantities: qty);
    await _persist(
      _measurement!.copyWith(
        drops: [
          for (final d in _measurement!.drops)
            if (d.id == dropId) updated else d,
        ],
      ),
    );
    if (!mounted) return;
    setState(_clearDropSecWidthMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Ms.of(context).secWidthUpdated(
            dropWidthCircleLabel(turnIndex),
            mm.round(),
          ),
        ),
      ),
    );
  }

  Future<void> _editDrop(String dropId) async {
    if (_measurement == null) return;
    DropRegion? drop;
    for (final d in _measurement!.drops) {
      if (d.id == dropId) {
        drop = d;
        break;
      }
    }
    if (drop == null) return;
    if (await _blockFreeNumberPage(
      deleteLabel: Ms.of(context).deleteThisDrop,
      onDelete: () async {
        await _persist(
          _measurement!.copyWith(
            drops: _measurement!.drops.where((d) => d.id != dropId).toList(),
          ),
        );
        if (!mounted) return;
        setState(() {
          _selectedDropId = null;
          _dropDraftTurnWidths.clear();
          _clearDropSecWidthMode();
        });
      },
    )) {
      return;
    }
    final result = await showModalBottomSheet<DropSettingsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DropSettingsSheet(
        initialLengthMm: drop!.lengthMm,
        initialWidthMm: drop.widthMm,
        initialHeightMm: drop.heightMm,
        initialTurnWidths: drop.turnWidths,
        initialPoints: drop.points,
        scalePxPerMm: _k,
        initialMethod: drop.method,
        allowDelete: true,
        groupNumber: drop.groupNumber,
        projectName: _measurement?.name,
        onEstimatePersist: (save) async {
          if (!await FeatureAccess.requireFullAccess(context)) return;
          await _persistEstimateSave(
            save,
            showSnack: false,
            areaLabel: '下り',
          );
        },
      ),
    );
    if (!mounted || result == null || _measurement == null) return;
    if (result.action == DropSettingsAction.delete) {
      await _persist(
        _measurement!.copyWith(
          drops: _measurement!.drops.where((d) => d.id != dropId).toList(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedDropId = null;
        _dropDraftTurnWidths.clear();
        _clearDropSecWidthMode();
      });
      return;
    }
    final qty = DropCalc.calc(
      lengthMm: result.lengthMm,
      widthMm: result.widthMm,
      heightMm: result.heightMm,
      method: result.method,
      points: drop.points,
      scalePxPerMm: _k,
      turnWidths: result.turnWidths,
    );
    final updated = drop.copyWith(
      lengthMm: result.lengthMm,
      widthMm: result.widthMm,
      heightMm: result.heightMm,
      turnWidths: result.turnWidths,
      method: result.method,
      quantities: qty,
    );
    await _persist(
      _measurement!.copyWith(
        drops: [
          for (final d in _measurement!.drops)
            if (d.id == dropId) updated else d,
        ],
      ),
    );
  }

  Future<void> _confirmCeiling({bool requireClosed = true}) async {
    if (_ceilingDraft.length < 3 || _measurement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Ms.of(context).need3Points)),
      );
      return;
    }
    if (requireClosed) {
      final closed = (_ceilingDraft.last - _ceilingDraft.first).distance <= 48;
      if (!closed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Ms.of(context).returnToStartRing),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    final pts = _ceilingDraft.map((o) {
      final s = _snapPoint(o);
      return Point2(s.x, s.y);
    }).toList();

    final areaM2 = CalcEngine.polygonAreaMm2(pts, _k) / 1e6;
    final groupNum = _ceilingGroupNumber <= 0
        ? (_maxCeilingGroupNumber() + 1)
        : _ceilingGroupNumber;

    final sameGroup = _measurement!.ceilings
        .where((c) => c.groupNumber == groupNum)
        .toList();

    // 先に領域を保存して番号を表示（工法シートを閉じても番号が残る）
    final method = sameGroup.isNotEmpty
        ? sameGroup.last.method.copyWith(showLayout: true)
        : const CeilingMethod(showLayout: true);
    final qty = CalcEngine.calcCeiling(
      points: pts,
      scalePxPerMm: _k,
      method: method,
    );
    final region = CeilingRegion(
      id: context.read<AppState>().newId(),
      points: pts,
      method: method,
      quantities: qty,
      highlightArgb: _colorForNewCeiling(),
      groupNumber: groupNum,
    );
    final list = <CeilingRegion>[
      ..._measurement!.ceilings,
      region,
    ];
    final updated = _measurement!.copyWith(ceilings: list);
    await _persist(updated);
    if (!mounted) return;
    setState(() {
      _ceilingDraft.clear();
      _mouseTip = null;
      _mouseReady = false;
      _touching = false;
      _tool = CanvasTool.pan; // 天井マウス自動オフ
      _selectedCeilingId = region.id;
      _ceilingGroupNumber = groupNum;
    });

    if (_ceilingUnifyWithPrevious && sameGroup.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Ms.of(context).ceilMergedArea(
              groupNum,
              areaM2.toStringAsFixed(2),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _armNumberOpenIgnore();
    // 有料／特典：番号表示後に工法シート。無料は番号だけ残す
    if (!FeatureAccess.hasFullAccess(context.read<AppState>().user)) return;
    await _openCeilingParams(region.id);
  }

  Future<void> _openCeilingParams(String ceilingId) async {
    if (_measurement == null) return;
    if (await _blockFreeNumberPage(
      deleteLabel: Ms.of(context).deleteThisArea,
      onDelete: () async {
        final list = [..._measurement!.ceilings]
          ..removeWhere((c) => c.id == ceilingId);
        await _persist(_measurement!.copyWith(ceilings: list));
      },
    )) {
      return;
    }
    final idx = _measurement!.ceilings.indexWhere((c) => c.id == ceilingId);
    if (idx < 0) return;
    final region = _measurement!.ceilings[idx];
    final groupNum = region.groupNumber;
    final areaM2 = region.quantities['ceiling_area_m2'] ??
        CalcEngine.polygonAreaMm2(region.points, _k) / 1e6;

    final result = await showModalBottomSheet<CeilingParamsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CeilingParamsSheet(
        ceilingNumber: groupNum,
        areaM2: areaM2,
        initialMethod: region.method,
        projectName: _measurement?.name,
        onCrossEstimateSave: (save) async {
          if (!await FeatureAccess.requireFullAccess(context)) return;
          await _persistEstimateSave(save, showSnack: false);
        },
        onLiveUpdate: (m) async {
          if (_measurement == null) return;
          final list = [
            for (final c in _measurement!.ceilings)
              c.id == ceilingId
                  ? c.copyWith(
                      method: m,
                      quantities: CalcEngine.calcCeiling(
                        points: c.points,
                        scalePxPerMm: _k,
                        method: m,
                      ),
                    )
                  : c,
          ];
          await _persist(_measurement!.copyWith(ceilings: list));
          if (mounted) setState(() {});
        },
      ),
    );
    if (result == null || !mounted) return;

    if (result.action == CeilingParamsAction.delete) {
      final groupCount =
          _measurement!.ceilings.where((c) => c.groupNumber == groupNum).length;
      final ok = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(Ms.of(ctx).deleteCeilTitle),
          content: Text(
            groupCount > 1
                ? Ms.of(ctx).deleteCeilGroup(groupNum, groupCount)
                : Ms.of(ctx).deleteCeilOne(groupNum),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel),
            ),
            if (groupCount > 1)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'one'),
                child: Text(Ms.of(ctx).thisRegionOnly),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'group'),
              child: Text(
                groupCount > 1 ? Ms.of(ctx).deleteGroupAll(groupNum) : S.of(ctx).delete,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      );
      if (ok == 'one') {
        final list =
            [..._measurement!.ceilings]..removeWhere((c) => c.id == ceilingId);
        await _persist(_measurement!.copyWith(ceilings: list));
      } else if (ok == 'group') {
        final list = [..._measurement!.ceilings]
          ..removeWhere((c) => c.groupNumber == groupNum);
        await _persist(_measurement!.copyWith(ceilings: list));
      }
      return;
    }

    final method = result.method.copyWith(showLayout: true);
    final list = [
      for (final c in _measurement!.ceilings)
        c.id == ceilingId
            ? c.copyWith(
                method: method,
                quantities: CalcEngine.calcCeiling(
                  points: c.points,
                  scalePxPerMm: _k,
                  method: method,
                ),
              )
            : c,
    ];
    final updated = _measurement!.copyWith(ceilings: list);
    await _persist(updated);
    if (!mounted) return;

    if (result.action == CeilingParamsAction.estimate) {
      if (!await FeatureAccess.requireFullAccess(context)) return;
      if (!mounted) return;
      await _openCeilingMaterialSettings(groupNum, ceilingId: ceilingId);
    }
  }

  Future<void> _openCeilingMaterialSettings(
    int groupNum, {
    required String ceilingId,
  }) async {
    if (_measurement == null) return;
    final current = _measurement!.ceilings
        .where((c) => c.id == ceilingId)
        .toList();
    if (current.isEmpty) return;
    if (!await FeatureAccess.requireFullAccess(context)) return;
    if (!mounted) return;
    final material = await Navigator.of(context).push<CeilingMaterialResult>(
      MaterialPageRoute(
        builder: (_) => CeilingMaterialSheet(
          ceilings: current,
          scalePxPerMm: _k,
          ceilingNumber: groupNum,
          initialMethod: current.first.method,
        ),
      ),
    );
    if (material == null || !mounted || _measurement == null) return;

    final mat = material.method;
    final list = <CeilingRegion>[
      for (final c in _measurement!.ceilings)
        if (c.id != ceilingId)
          c
        else
        c.copyWith(
          method: mat,
          quantities: CalcEngine.calcCeiling(
            points: c.points,
            scalePxPerMm: _k,
            method: mat,
          ),
        ),
    ];
    final updated = _measurement!.copyWith(ceilings: list);
    await _persist(updated);
    if (!mounted) return;
    if (material.action == CeilingMaterialAction.estimate) {
      await _openCeilingEstimate(updated, groupNum: groupNum);
    }
  }

  Future<void> _openCeilingEstimate(
    Measurement updated, {
    int? groupNum,
  }) async {
    if (!await FeatureAccess.requireFullAccess(context)) return;
    if (!mounted) return;
    final ceilingOnly = <EstimateLine>[];
    final src = groupNum == null
        ? updated.ceilings
        : updated.ceilings.where((c) => c.groupNumber == groupNum);
    for (final c in src) {
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
      project = await context.read<AppState>().db.getProject(updated.projectId);
    } catch (_) {}
    if (!mounted) return;
    final areas = EstimateBuilder.areasFromMeasurement(
      updated,
      onlyEstimateReady: false,
      includeWalls: false,
      ceilingGroupNumber: groupNum,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: Ms.of(context).estimateCeil,
          initialLines: merged,
          projectName: updated.name,
          siteAddress: project?.address,
          sitePhone: project?.phone,
          siteContact: project?.contactName,
          areaLabel: '天井',
          areaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsAreaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsMethodLabel: EstimateBuilder.lgsMethodLabel(
            updated,
            areaKind: '天井',
            onlyEstimateReady: false,
            ceilingGroupNumber: groupNum,
          ),
          boardAreaM2: areas.boardM2 > 0 ? areas.boardM2 : null,
          boardAreaParts: EstimateBuilder.boardAreasByName(
            updated,
            areaKind: '天井',
            onlyEstimateReady: false,
            ceilingGroupNumber: groupNum,
          ),
          onSavePersist: (save) => _persistEstimateSave(
            save,
            showSnack: false,
            areaLabel: '天井',
          ),
        ),
      ),
    );
  }

  Future<void> _rotateCeilingGrid(CeilingRegion region) async {
    if (_measurement == null) return;
    final method = region.method.copyWith(rotated90: !region.method.rotated90);
    final rotated = region.copyWith(
      method: method,
      quantities: CalcEngine.calcCeiling(
        points: region.points,
        scalePxPerMm: _k,
        method: method,
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
          title: Text(Ms.of(ctx).deleteWallTitle),
          content: Text(Ms.of(ctx).deleteWallBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.of(ctx).cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: Text(S.of(ctx).delete),
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
      SnackBar(
        content: Text(Ms.of(context).wallDeleted),
        duration: const Duration(seconds: 2),
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
    var n = 0;
    for (final w in _measurement?.walls ?? const []) {
      if (w.isIronPlate) continue;
      n++;
      if (w.id == wallId) return n;
    }
    return n < 1 ? 1 : n;
  }

  void _armNumberOpenIgnore() {
    _ignoreNumberOpenUntil =
        DateTime.now().add(const Duration(milliseconds: 700));
  }

  bool get _ignoreNumberOpen =>
      _ignoreNumberOpenUntil != null &&
      DateTime.now().isBefore(_ignoreNumberOpenUntil!);

  /// 無料：番号ページは見られない。画線直後の誤タップは黙って無視。
  Future<bool> _blockFreeNumberPage({
    required String deleteLabel,
    required Future<void> Function() onDelete,
  }) async {
    if (FeatureAccess.hasFullAccess(context.read<AppState>().user)) {
      return false;
    }
    if (_ignoreNumberOpen) return true;
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).upgradeTitle),
        content: Text(S.of(ctx).upgradeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).close),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(deleteLabel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
            child: Text(S.of(ctx).goAccount),
          ),
        ],
      ),
    );
    if (delete == true) await onDelete();
    return true;
  }

  Future<void> _openWallMaterial(String wallId) async {
    var wall = _wallById(wallId);
    if (wall == null || _measurement == null) return;
    if (await _blockFreeNumberPage(
      deleteLabel: Ms.of(context).deleteThisLine,
      onDelete: () => _deleteWall(wallId),
    )) {
      return;
    }
    setState(() => _selectedWallId = wallId);

    // 番号タップ時に開口を再紐付け（未紐付け・近傍・壁が1本なら全部）
    final linked = _attachOpeningsToWall(wall);
    if (linked) {
      wall = _wallById(wallId);
      if (wall == null || _measurement == null) return;
      await _persist(_measurement!);
      if (!mounted) return;
      wall = _wallById(wallId);
      if (wall == null) return;
    }

    // 鉄板専用で画いた線だけ T。材料選択の鉄板ONはここでは見ない
    final drawnAsIron = _isIronWall(wall);
    final tLen = _tIronLengthMm(drawnAsIron ? wall : null);
    if (drawnAsIron) {
      final ironAction = await showModalBottomSheet<IronPlateMeasureAction>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => IronPlateMeasureSheet(lengthMm: tLen),
      );
      if (ironAction == null || _measurement == null || !mounted) return;
      if (ironAction == IronPlateMeasureAction.delete) {
        await _deleteWall(wallId);
        return;
      }
    } else {
      late WallMaterialResult result;
      while (mounted && _measurement != null) {
      wall = _wallById(wallId);
      if (wall == null) return;
      final painted = _paintedMm(wall);
      final sheetResult = await showModalBottomSheet<WallMaterialResult>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => WallMaterialSheet(
          initialMethod: wall!.method,
          initialHeightMm: wall.heightMm,
          wallNumber: _wallNumber(wallId),
          measuredLengthMm: painted.runMm,
          measuredOpeningAreaM2: wall.quantities['opening_area_m2'] ??
              _qtyForWall(wall)['opening_area_m2'],
          ironPlateMeasured: drawnAsIron,
          projectName: _measurement?.name,
          onCrossEstimateSave: (save) =>
              _persistEstimateSave(save, showSnack: false),
        ),
      );
      if (sheetResult == null || _measurement == null || !mounted) return;
      result = sheetResult;

      if (result.action == WallMaterialAction.delete) {
        await _deleteWall(wallId);
        return;
      }

      wall = _wallById(wallId);
      if (wall == null) return;
      await _applyWallBasicResult(wall, result, drawnAsIron: drawnAsIron);
      if (!mounted || _measurement == null) return;

      if (result.action == WallMaterialAction.openCross) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!mounted || _measurement == null) return;
        await _openCrossDedicatedForWall(wallId);
        if (!mounted || _measurement == null) return;
        continue;
      }
      break;
    }
    }
    if (!mounted || _measurement == null) return;
    wall = _wallById(wallId);
    if (wall == null) return;

    // 番号タップ＝このグループ確定（多線の続きを終了）
    if (_continueWallId == wallId) {
      _continueWallId = null;
    }

    final paintedNow = _paintedMm(wall);
    final ironMeasured = drawnAsIron || _isIronWall(wall);
    final measureLen = paintedNow.runMm > 0 ? paintedNow.runMm : paintedNow.tipMm;
    final working = wall;

    // 工法選択 → 材料選択 → 試算表
    final openings = _effectiveOpeningsForWall(wallId);
    final hasOpenings = openings.isNotEmpty;
    final hasReinforce = openings.any(
      (o) => o.material == OpeningMaterialKind.reinforce,
    );
    var paramsMethod = working.method;
    final hasTLine = ironMeasured || tLen > 0;
    if (hasTLine) {
      paramsMethod = paramsMethod.copyWith(useIronPlate: true);
    }
    if (hasOpenings) {
      paramsMethod = paramsMethod.copyWith(useAnglePiece: true);
    }
    if (hasOpenings) {
      final studLen = paramsMethod.studLengthMm > 0
          ? paramsMethod.studLengthMm
          : working.heightMm;
      paramsMethod = paramsMethod.copyWith(
        useReinforceMaterial: true,
        reinforceWidthMm: paramsMethod.runnerWidthMm > 0
            ? paramsMethod.runnerWidthMm
            : paramsMethod.studWidthMm,
        reinforceLengthMm: paramsMethod.reinforceLengthMm > 0
            ? paramsMethod.reinforceLengthMm
            : studLen,
      );
    }
    final stockLen = paramsMethod.reinforceLengthMm > 0
        ? paramsMethod.reinforceLengthMm
        : (paramsMethod.studLengthMm > 0
            ? paramsMethod.studLengthMm
            : working.heightMm);
    final reinforceOpenings = hasReinforce
        ? openings
        : [
            for (final o in openings)
              o.copyWith(material: OpeningMaterialKind.reinforce),
          ];
    final params = await showModalBottomSheet<WallParamsResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => WallParamsSheet(
        initialHeightMm: working.heightMm,
        initialMethod: paramsMethod,
        measuredLengthMm: ironMeasured ? tLen : measureLen,
        ironDrawLengthMm: tLen,
        linePoints: working.chains.isNotEmpty
            ? working.chains.last
            : working.points,
        scalePxPerMm: _k,
        measuredCornerCount: working.cornerCount,
        measuredOpeningAreaM2: working.quantities['opening_area_m2'] ??
            openings.fold<double>(0, (s, o) => s + o.areaM2),
        autoCheckIronPlate: hasTLine,
        ironPlateOnly: ironMeasured,
        autoCheckReinforce: hasOpenings,
        autoCheckAngle: hasOpenings,
        reinforceBarCount: OpeningReinforceCalc.reinforceBarsForOpenings(
          openings: reinforceOpenings,
          stockLengthMm: stockLen,
        ),
        anglePieceCount: [
          for (final o in openings)
            OpeningReinforceCalc.anglePieces(
              pattern: OpeningReinforcePatternX.parse(o.patternName),
              magusaSegments: o.magusaSegments,
            ),
        ].fold<int>(0, (s, n) => s + n),
      ),
    );
    if (params == null || _measurement == null || !mounted) return;

    final qty2 = Map<String, double>.from(
      _qtyForWall(
        working,
        method: params.method,
        heightMm: params.heightMm,
        ironPlateRunMm: tLen,
      ),
    );
    if (ironMeasured && tLen > 0) {
      qty2['wall_length_mm'] = tLen;
    } else if (measureLen > 0) {
      qty2['wall_length_mm'] = measureLen;
    }
    if (params.method.useIronPlate && tLen > 0) {
      final seg =
          params.method.ironPlateSegmentCount;
      final runMm = tLen * seg;
      final stock = params.method.ironPlateLengthMm;
      qty2['iron_plate_measure_mm'] = tLen;
      qty2['iron_plate_run_mm'] = runMm;
      if (stock > 0) {
        final sheets = (runMm / stock).ceilToDouble();
        qty2['iron_plate_sheets'] = sheets < 1 ? 1.0 : sheets;
      }
    }
    final finalized = working.copyWith(
      heightMm: params.heightMm,
      method: params.method,
      quantities: qty2,
      estimateReady: true,
      ironPlateMeasured: working.ironPlateMeasured || ironMeasured,
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
          title: Ms.of(context).estimate,
          initialLines: lines,
          projectName: measurement.name,
          siteAddress: project?.address,
          sitePhone: project?.phone,
          siteContact: project?.contactName,
          areaLabel: '壁',
          areaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsAreaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsMethodLabel: EstimateBuilder.lgsMethodLabel(
            measurement,
            areaKind: '壁',
          ),
          boardAreaM2: areas.boardM2 > 0 ? areas.boardM2 : null,
          boardAreaParts: EstimateBuilder.boardAreasByName(
            measurement,
            areaKind: '壁',
          ),
          rockFeltM: areas.rockFeltM > 0 ? areas.rockFeltM : null,
          glassWoolM2: areas.glassWoolM2 > 0 ? areas.glassWoolM2 : null,
          onSavePersist: (save) => _persistEstimateSave(
            save,
            showSnack: false,
            areaLabel: '壁',
          ),
        ),
      ),
    );
  }

  Future<void> _persistEstimateSave(
    EstimateSaveResult save, {
    bool showSnack = true,
    String areaLabel = '壁',
  }) async {
    if (_measurement == null) return;
    final ceiling = areaLabel == '天井';
    final drop = areaLabel == '下り' || save.kind == EstimateSheetKind.drop;
    for (final e in save.lines) {
      if (e.areaKind.isEmpty) {
        e.areaKind = drop
            ? 'drop'
            : save.kind == EstimateSheetKind.cross
                ? 'cross'
                : ceiling
                    ? 'ceiling'
                    : 'wall';
      }
    }
    final Measurement m;
    if (drop) {
      m = _measurement!.copyWith(
        dropEstimate: EstimateBuilder.mergeReplacingLineNumbersOfKind(
          existing: _measurement!.dropEstimate,
          incoming: save.lines,
          kind: save.kind,
        ),
      );
    } else {
      m = switch (save.kind) {
        EstimateSheetKind.board => ceiling
            ? _measurement!.copyWith(
                ceilingBoardEstimate: EstimateBuilder.mergeReplacingLineNumbers(
                  existing: _measurement!.ceilingBoardEstimate,
                  incoming: save.lines,
                ),
              )
            : _measurement!.copyWith(boardEstimate: save.lines),
        EstimateSheetKind.lgs => ceiling
            ? _measurement!.copyWith(
                ceilingLgsEstimate: EstimateBuilder.mergeReplacingLineNumbers(
                  existing: _measurement!.ceilingLgsEstimate,
                  incoming: save.lines,
                ),
              )
            : _measurement!.copyWith(lgsEstimate: save.lines),
        EstimateSheetKind.cross =>
          _measurement!.copyWith(crossEstimate: save.lines),
        EstimateSheetKind.drop =>
          _measurement!.copyWith(dropEstimate: save.lines),
      };
    }
    await _persist(m);
    if (!mounted || !showSnack) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(Ms.of(context).savedKind(
            Ms.of(context).estimateKindTitle(save.kind.label),
          )),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  WallBadgeHit? _badgeAt(Offset local, {double radius = 40}) {
    for (var i = _badgeHits.length - 1; i >= 0; i--) {
      if (_badgeHits[i].hit(local, radius: radius)) return _badgeHits[i];
    }
    return null;
  }

  void _onPointerDown(Offset local) {
    _pointerDownAt = DateTime.now();
    _pointerDownPos = local;
    _longPressHandled = false;

    if (_tool == CanvasTool.pan) return;

    // 番号バッジ付近は描画開始しない（上の T を優先）
    if (_badgeAt(local) != null) return;
    for (final b in _ceilingBadgeHits) {
      if (b.hit(local)) return;
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
        _tool == CanvasTool.dropPen ||
        _tool == CanvasTool.openingReinforce) {
      var tip = _tipFromFinger(local);
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
        _tool != CanvasTool.dropPen &&
        _tool != CanvasTool.openingReinforce) {
      return;
    }

    var tip = _tipFromFinger(local);
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
    if (_openedNumberOnDown) {
      _openedNumberOnDown = false;
      _touching = false;
      return;
    }
    if (_longPressHandled) {
      _touching = false;
      return;
    }

    // 番号バッジ → 材料寸法（重なるときは上の T）
    if (!_touching || (_wallPoints.isEmpty && !_startLocked)) {
      final badge = _badgeAt(local);
      if (badge != null) {
        _holdTicker?.cancel();
        setState(() {
          _touching = false;
          _mouseTip = null;
        });
        _openWallMaterial(badge.wallId);
        return;
      }
      for (final b in _ceilingBadgeHits) {
        if (b.hit(local)) {
          _holdTicker?.cancel();
          setState(() {
            _touching = false;
            _mouseTip = null;
            _selectedCeilingId = b.ceilingId;
            CeilingRegion? ceil;
            for (final e in _measurement?.ceilings ?? const <CeilingRegion>[]) {
              if (e.id == b.ceilingId) {
                ceil = e;
                break;
              }
            }
            if (ceil?.highlightArgb != null) {
              _drawColorArgb = ceil!.highlightArgb!;
            }
          });
          _openCeilingParams(b.ceilingId);
          return;
        }
      }
      for (final d in _measurement?.drops ?? const <DropRegion>[]) {
        if (_hitDrop(d, local)) {
          _holdTicker?.cancel();
          setState(() {
            _touching = false;
            _mouseTip = null;
            _selectedDropId = d.id;
            if (d.highlightArgb != null) {
              _drawColorArgb = d.highlightArgb!;
            }
          });
          // 設定は線尾番号タップ（ドラッグ測定中でないとき）
          return;
        }
      }
      // 開口マーカー → 再設定／削除
      for (final h in _openingHits) {
        if (h.hit(local)) {
          _holdTicker?.cancel();
          setState(() {
            _touching = false;
            _mouseTip = null;
            _openingDraft.clear();
          });
          _editOpening(h.openingId);
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
      final n = _ceilingDraft.length;
      final tip = _mouseTip;
      final closedByTip = tip != null &&
          n >= 3 &&
          (tip - _ceilingDraft.first).distance <= 40;
      final closedByLast = n >= 3 &&
          (_ceilingDraft.last - _ceilingDraft.first).distance <= 48;
      _holdTicker?.cancel();
      setState(() {
        _touching = false;
        _mouseTip = null;
        _mouseReady = false;
        _holdProgress = 0;
      });
      // 始点へ戻して閉合した場合のみ確定（番号表示→工法）
      if (wasReady && n >= 3 && (closedByTip || closedByLast)) {
        _confirmCeiling(requireClosed: false);
      } else if (wasReady && n >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Ms.of(context).returnToStartRingShort),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    if (_tool == CanvasTool.dropPen && _touching) {
      final wasReady = _mouseReady;
      final n = _dropDraft.length;
      _holdTicker?.cancel();
      setState(() {
        _touching = false;
        // 緑のまま離したら測定完了（3点以上）／不足なら次点待ち
        if (!wasReady) {
          _mouseTip = null;
          _holdProgress = 0;
        }
      });
      if (wasReady && n >= 3) {
        _finishDropFromMouse();
      } else if (wasReady && n >= 1) {
        setState(() {
          _mouseReady = false;
          _mouseTip = null;
          _holdProgress = 0;
        });
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

  /// この壁の開口。未紐付けしか無いときは測定全体を使う（自動チェック用）
  List<WallOpening> _effectiveOpeningsForWall(String wallId) {
    final linked = _openingsForWall(wallId);
    if (linked.isNotEmpty) return linked;
    final all = _measurement?.openings ?? const <WallOpening>[];
    if (all.isEmpty) return const [];
    final unlinked = all
        .where((o) => o.wallId == null || o.wallId!.isEmpty)
        .toList();
    if (unlinked.isNotEmpty) return unlinked;
    if ((_measurement?.walls.length ?? 0) <= 1) return List.of(all);
    return const [];
  }

  bool _isIronWall(WallSegment wall) => wall.isIronDrawLine;

  /// 図上の T 線の全長。材料選択の鉄板欄はこれだけを使う（壁長は使わない）
  double _tIronLengthMm([WallSegment? prefer]) {
    if (prefer != null && prefer.isIronDrawLine) {
      return ironPlateLengthMm(prefer, _k);
    }
    var sum = 0.0;
    for (final w in _measurement?.walls ?? const <WallSegment>[]) {
      if (!w.isIronDrawLine) continue;
      sum += ironPlateLengthMm(w, _k);
    }
    return sum;
  }

  /// 鉄板の画線全長（T 横の数字・材料選択と同じ式）
  double _ironTotalMm(
    WallSegment wall, [
    ({double tipMm, double runMm})? painted,
  ]) {
    final run = ironPlateLengthMm(wall, _k);
    if (run > 0) return run;
    final p = painted ?? _paintedMm(wall);
    if (p.runMm > 0) return p.runMm;
    return p.tipMm;
  }

  /// 線上の黄色い長さラベルと同じ計算（8px未満はラベルも出さないので除外）
  ({double tipMm, double runMm}) _paintedMmOfPoints(List<Point2> pts) {
    var tip = 0.0;
    var run = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final mm = distanceLabelMm(
        Offset(pts[i].x, pts[i].y),
        Offset(pts[i + 1].x, pts[i + 1].y),
        _k,
      );
      if (mm <= 0) continue;
      run += mm;
      tip = mm;
    }
    return (tipMm: tip, runMm: run);
  }

  ({double tipMm, double runMm}) _paintedMm(WallSegment wall) {
    var tip = 0.0;
    var run = 0.0;
    final chains = wall.chains.isNotEmpty ? wall.chains : [wall.points];
    for (final chain in chains) {
      final part = _paintedMmOfPoints(chain);
      if (part.runMm <= 0) continue;
      run += part.runMm;
      tip = part.tipMm;
    }
    if (run > 0) return (tipMm: tip, runMm: run);
    final stored = wall.quantities['iron_plate_measure_mm'] ??
        wall.quantities['wall_length_mm'] ??
        0;
    return (tipMm: stored, runMm: stored);
  }

  double _lineLengthMm(WallSegment wall) => _paintedMm(wall).runMm;

  double _paintedWallLengthMm(WallSegment wall) => _paintedMm(wall).runMm;

  double _measuredWallLengthMm(WallSegment wall) => _paintedMm(wall).runMm;

  Future<void> _applyWallBasicResult(
    WallSegment wall,
    WallMaterialResult result, {
    bool drawnAsIron = false,
  }) async {
    if (_measurement == null) return;
    final painted = _paintedMm(wall);
    final qty = Map<String, double>.from(
      _qtyForWall(
        wall,
        method: result.method,
        heightMm: result.heightMm,
      ),
    );
    final ironDraw = drawnAsIron || wall.isIronDrawLine;
    if (painted.runMm > 0 || (ironDraw && _ironTotalMm(wall, painted) > 0)) {
      final ironLen = _tIronLengthMm(ironDraw ? wall : null);
      qty['wall_length_mm'] = ironDraw && ironLen > 0 ? ironLen : painted.runMm;
      if (ironDraw && ironLen > 0) {
        qty['iron_plate_measure_mm'] = ironLen;
        qty['iron_plate_draw'] = 1;
      }
    }
    final method = ironDraw
        ? result.method.copyWith(useIronPlate: true)
        : result.method;
    final working = wall.copyWith(
      method: method,
      heightMm: result.heightMm,
      quantities: qty,
      ironPlateMeasured: wall.ironPlateMeasured || drawnAsIron,
    );
    final walls = _measurement!.walls
        .map((w) => w.id == wall.id ? working : w)
        .toList();
    await _persist(_measurement!.copyWith(walls: walls));
  }

  Future<void> _openCrossDedicatedForWall(String wallId) async {
    final wall = _wallById(wallId);
    if (wall == null || !mounted) return;
    final len = _paintedMm(wall).runMm;
    final h = wall.heightMm > 0 ? wall.heightMm : 2700;
    final openings = _effectiveOpeningsForWall(wallId);
    final openingArea = openings.fold<double>(0, (s, o) => s + o.areaM2);
    final gross = (len / 1000.0) * (h / 1000.0);
    final area = (gross - openingArea).clamp(0.0, double.infinity);
    final config = await Navigator.of(context, rootNavigator: true)
        .push<CrossDedicatedConfig>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CrossDedicatedSheet(
          areaM2: area,
          initial: wall.method.crossDedicated,
          title: Ms.of(context).crossDedicatedWall,
          showWallFaces: true,
          onSavePersist: (save) =>
              _persistEstimateSave(save, showSnack: false),
          projectName: _measurement?.name,
        ),
      ),
    );
    if (config == null || _measurement == null || !mounted) return;
    final latest = _wallById(wallId);
    if (latest == null) return;
    final method = latest.method.copyWith(
      useCross: config.enabled,
      crossDedicated: config,
    );
    final walls = _measurement!.walls
        .map((w) => w.id == wallId ? latest.copyWith(method: method) : w)
        .toList();
    await _persist(_measurement!.copyWith(walls: walls));
  }

  Map<String, double> _qtyForWall(
    WallSegment wall, {
    WallMethod? method,
    double? heightMm,
    double? ironPlateRunMm,
  }) {
    final m = method ?? wall.method;
    final ironRun = ironPlateRunMm ??
        (wall.isIronDrawLine ? _tIronLengthMm(wall) : _tIronLengthMm());
    return CalcEngine.calcWall(
      points: wall.points,
      chainStarts: wall.chainStarts,
      heightMm: heightMm ?? wall.heightMm,
      scalePxPerMm: _k,
      method: m,
      openings: _openingsForWall(wall.id),
      ironPlateRunMm: m.useIronPlate && ironRun > 0 ? ironRun : null,
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
    if (!FeatureAccess.hasFullAccess(context.read<AppState>().user)) {
      final opening = WallOpening(
        id: context.read<AppState>().newId(),
        a: Point2(a.x, a.y),
        b: Point2(b.x, b.y),
        highlightArgb: _drawColorArgb,
        markerSize: _strokeWidth.clamp(8, 56),
        heightMm: 2100,
        widthMm: widthMm > 50 ? widthMm : 900,
      );
      final nextOpenings = [..._measurement!.openings, opening];
      await _relinkOpeningsAndRecalcWalls(nextOpenings);
      if (!mounted) return;
      setState(() {
        _openingDraft.clear();
        _openingSetupDone = true;
        _tool = CanvasTool.pan;
      });
      return;
    }
    final result = await showModalBottomSheet<OpeningReinforceResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OpeningReinforceSheet(
        defaultWidthMm: widthMm > 50 ? widthMm : 900,
      ),
    );
    if (!mounted) return;
    if (result == null || result.delete) {
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
    final nextOpenings = [..._measurement!.openings, opening];
    await _relinkOpeningsAndRecalcWalls(nextOpenings);
    if (!mounted) return;
    setState(() {
      _openingDraft.clear();
      _openingSetupDone = true;
      _tool = CanvasTool.pan;
    });
    final linked = (_measurement?.openings ?? const [])
        .where((o) => o.id == opening.id && o.wallId != null)
        .isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          linked
              ? Ms.of(context).openingAddedDeduct(opening.areaM2.toStringAsFixed(2))
              : Ms.of(context).openingAdded(
                  result.pattern.label,
                  result.material.label,
                ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _editOpening(String openingId) async {
    if (_measurement == null) return;
    WallOpening? opening;
    for (final o in _measurement!.openings) {
      if (o.id == openingId) {
        opening = o;
        break;
      }
    }
    if (opening == null) return;
    if (!FeatureAccess.hasFullAccess(context.read<AppState>().user)) {
      final delete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(S.of(ctx).upgradeTitle),
          content: Text(
            '${S.of(ctx).upgradeMessage}\n\n${Ms.of(ctx).freeDeleteOpeningNote}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.of(ctx).close),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Ms.of(ctx).deleteThisOpening),
            ),
          ],
        ),
      );
      if (delete == true && _measurement != null) {
        final next =
            _measurement!.openings.where((o) => o.id != openingId).toList();
        await _relinkOpeningsAndRecalcWalls(next);
      }
      return;
    }

    double stock = 3000;
    if (opening.wallId != null) {
      final wall = _wallById(opening.wallId!);
      if (wall != null) {
        final m = wall.method;
        stock = m.reinforceLengthMm > 0
            ? m.reinforceLengthMm
            : (m.studLengthMm > 0 ? m.studLengthMm : wall.heightMm);
      }
    }

    final result = await showModalBottomSheet<OpeningReinforceResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OpeningReinforceSheet(
        defaultWidthMm: opening!.widthMm,
        defaultHeightMm: opening.heightMm,
        initialPattern: OpeningReinforcePatternX.parse(opening.patternName),
        initialMaterial: opening.material,
        initialMagusaSegments: opening.magusaSegments,
        allowDelete: true,
        stockLengthMm: stock,
      ),
    );
    if (!mounted || result == null || _measurement == null) return;

    if (result.delete) {
      final openings =
          _measurement!.openings.where((o) => o.id != openingId).toList();
      var walls = _measurement!.walls;
      final wid = opening.wallId;
      if (wid != null) {
        walls = [
          for (final w in walls)
            if (w.id == wid)
              w.copyWith(
                quantities: CalcEngine.calcWall(
                  points: w.points,
                  chainStarts: w.chainStarts,
                  heightMm: w.heightMm,
                  scalePxPerMm: _k,
                  method: w.method,
                  openings: openings.where((o) => o.wallId == wid).toList(),
                ),
              )
            else
              w,
        ];
      }
      await _persist(
        _measurement!.copyWith(openings: openings, walls: walls),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Ms.of(context).openingDeleted)),
      );
      return;
    }

    final updated = opening.copyWith(
      patternName: result.pattern.name,
      material: result.material,
      heightMm: result.heightMm,
      widthMm: result.widthMm,
      magusaSegments: result.magusaSegments,
    );
    final openings = _measurement!.openings
        .map((o) => o.id == openingId ? updated : o)
        .toList();
    if (updated.wallId == null || updated.wallId!.isEmpty) {
      await _relinkOpeningsAndRecalcWalls(openings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Ms.of(context).openingUpdated(result.pattern.label))),
      );
      return;
    }
    var walls = _measurement!.walls;
    final wid = updated.wallId!;
    final hasReinforce = openings.any(
      (o) =>
          o.wallId == wid && o.material == OpeningMaterialKind.reinforce,
    );
    walls = [
      for (final w in walls)
        if (w.id == wid)
          () {
            var method = w.method;
            if (hasReinforce && !method.useReinforceMaterial) {
              method = method.copyWith(
                useReinforceMaterial: true,
                reinforceWidthMm: method.reinforceWidthMm > 0
                    ? method.reinforceWidthMm
                    : method.studWidthMm,
                reinforceLengthMm: method.reinforceLengthMm > 0
                    ? method.reinforceLengthMm
                    : (method.studLengthMm > 0
                        ? method.studLengthMm
                        : w.heightMm),
              );
            }
            return w.copyWith(
              method: method,
              quantities: CalcEngine.calcWall(
                points: w.points,
                chainStarts: w.chainStarts,
                heightMm: w.heightMm,
                scalePxPerMm: _k,
                method: method,
                openings: openings.where((o) => o.wallId == wid).toList(),
              ),
            );
          }()
        else
          w,
    ];
    await _persist(
      _measurement!.copyWith(openings: openings, walls: walls),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Ms.of(context).openingUpdated(result.pattern.label)),
      ),
    );
  }

  /// 番号タップ時：この壁へ開口を割り当てる
  bool _attachOpeningsToWall(WallSegment wall) {
    if (_measurement == null) return false;
    final wallIds = {for (final w in _measurement!.walls) w.id};
    final onlyWall = _measurement!.walls.length == 1;
    var changed = false;
    final next = _measurement!.openings.map((o) {
      if (o.wallId == wall.id) return o;
      final taken = o.wallId != null &&
          o.wallId!.isNotEmpty &&
          wallIds.contains(o.wallId);
      final near = OpeningReinforceCalc.openingNearWall(
        opening: o,
        wall: wall,
        maxDistPx: 400,
      );
      if (onlyWall || !taken || near) {
        changed = true;
        return o.copyWith(wallId: wall.id);
      }
      return o;
    }).toList();
    if (!changed) return false;
    _measurement = _measurement!.copyWith(openings: next);
    return true;
  }

  /// 画線が開口マーカー付近を通ったら紐付け
  List<WallOpening> _linkOpeningsToWall(
    List<WallOpening> openings,
    WallSegment wall, {
    double? maxDistPx,
  }) {
    final thresh = maxDistPx ?? math.max(64.0, wall.strokeWidth * 4);
    return openings.map((o) {
      if (o.wallId != null && o.wallId!.isNotEmpty) return o;
      if (OpeningReinforceCalc.openingNearWall(
        opening: o,
        wall: wall,
        maxDistPx: thresh,
      )) {
        return o.copyWith(wallId: wall.id);
      }
      return o;
    }).toList();
  }

  /// 未紐付け開口を既存壁へ割り当て、該当壁の面積を再計算
  Future<void> _relinkOpeningsAndRecalcWalls(
    List<WallOpening> openings,
  ) async {
    if (_measurement == null) return;
    var nextOpenings = openings;
    for (final w in _measurement!.walls) {
      nextOpenings = _linkOpeningsToWall(nextOpenings, w);
    }
    final touched = <String>{
      for (final o in nextOpenings)
        if (o.wallId != null && o.wallId!.isNotEmpty) o.wallId!,
    };
    final walls = [
      for (final w in _measurement!.walls)
        if (touched.contains(w.id))
          w.copyWith(
            quantities: CalcEngine.calcWall(
              points: w.points,
              chainStarts: w.chainStarts,
              heightMm: w.heightMm,
              scalePxPerMm: _k,
              method: w.method,
              openings: nextOpenings.where((o) => o.wallId == w.id).toList(),
            ),
          )
        else
          w,
    ];
    await _persist(
      _measurement!.copyWith(walls: walls, openings: nextOpenings),
    );
  }

  bool get _isLandscape =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  bool get _hideMeasureChrome => _chromeCollapsed && _isLandscape;

  void _collapseChromeIfLandscape() {
    if (!mounted) return;
    if (MediaQuery.orientationOf(context) != Orientation.landscape) return;
    if (_chromeCollapsed) return;
    setState(() => _chromeCollapsed = true);
  }

  @override
  Widget build(BuildContext context) {
    final m = _measurement;
    final hideChrome = _hideMeasureChrome;
    return Scaffold(
      appBar: hideChrome
          ? null
          : AppBar(
        title: Text(m?.name ?? Ms.of(context).measure),
        actions: [
          IconButton(
            tooltip: _snapEnabled ? Ms.of(context).snapOn : Ms.of(context).snapOff,
            onPressed: _toggleSnap,
            icon: Icon(
              _snapEnabled ? Icons.center_focus_strong : Icons.center_focus_weak,
              color: _snapEnabled ? AppTheme.safetyYellow : Colors.white70,
            ),
          ),
          if (m != null && m.ceilings.isNotEmpty)
            IconButton(
              tooltip: Ms.of(context).rotateCeilGrid,
              onPressed: () => _rotateCeilingGrid(m.ceilings.last),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
            ),
        ],
      ),
      body: m == null || _bgImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!hideChrome) _toolbar(),
                if (!hideChrome)
                WallHighlightColorBar(
                  selectedArgb: _drawColorArgb,
                  strokeWidth: _selectedWallId != null
                      ? (_wallById(_selectedWallId!)?.strokeWidth ??
                          _strokeWidth)
                      : _strokeWidth,
                  onSelect: (c) {
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
                Expanded(
                  child: hideChrome
                      ? Stack(
                          children: [
                            Positioned.fill(child: _canvas()),
                            _expandChromeButton(),
                          ],
                        )
                      : _canvas(),
                ),
                if (!hideChrome) _bottomBar(),
              ],
            ),
    );
  }

  Widget _expandChromeButton() {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          Material(
            color: AppTheme.navy.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: Ms.of(context).back,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const Spacer(),
          Material(
            color: AppTheme.navy.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => _chromeCollapsed = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      Ms.of(context).menu,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
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
                  title: Text(Ms.of(ctx).openingConfirmTitle),
                  content: Text(Ms.of(ctx).openingConfirmBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'cancel'),
                      child: Text(S.of(ctx).cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'opening'),
                      child: Text(Ms.of(ctx).goOpening),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, 'skip'),
                      child: Text(Ms.of(ctx).noOpening),
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
                _collapseChromeIfLandscape();
                return;
              }
              _openingSetupDone = true;
            }
            final mode = await _pickWallDrawMode();
            if (mode == null || !mounted) return;
            setState(() {
              _tool = CanvasTool.wallPen;
              _wallDrawMode = mode;
              if (mode != WallDrawMode.multi) {
                _continueWallId = null;
              }
              _clearWallDraft(notify: false);
              _openingDraft.clear();
            });
            if (mode == WallDrawMode.multi && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(Ms.of(context).multiModeSnack),
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (mode == WallDrawMode.ironPlate && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(Ms.of(context).ironModeSnack),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            _collapseChromeIfLandscape();
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
            _collapseChromeIfLandscape();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Ms.of(context).openingModeSnack),
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
          if (tool == CanvasTool.ceilingPen) {
            await _activateCeilingPen();
            _collapseChromeIfLandscape();
            return;
          }
          if (tool == CanvasTool.dropPen) {
            await _activateDropPen();
            _collapseChromeIfLandscape();
            return;
          }
          setState(() {
            _tool = tool;
            if (tool == CanvasTool.pan) {
              _clearWallDraft(notify: false);
              _openingDraft.clear();
              _dropDraft.clear();
              _dropDraftTurnWidths.clear();
              _clearDropSecWidthMode();
            }
            if (tool != CanvasTool.wallPen) {
              _continueWallId = null;
            }
            if (tool != CanvasTool.dropPen) {
              _clearDropSecWidthMode();
              _dropDraftTurnWidths.clear();
            }
          });
          _collapseChromeIfLandscape();
        },
        selectedColor: AppTheme.safetyYellow,
      );
    }

    final ms = Ms.of(context);
    final modeHint = _tool == CanvasTool.openingReinforce
        ? ms.modeOpening
        : _tool == CanvasTool.dropPen
            ? ms.modeDrop
            : _tool != CanvasTool.wallPen
                ? ''
                : (_wallDrawMode == WallDrawMode.ironPlate
                    ? ms.modeIron
                    : (_wallDrawMode == WallDrawMode.multi ? ms.modeMulti : ms.modeSingle));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(ms.toolPan, CanvasTool.pan, const Icon(Icons.open_with, size: 16)),
            const SizedBox(width: 6),
            chip(
              ms.toolOpening,
              CanvasTool.openingReinforce,
              const Icon(Icons.crop_square, size: 16),
            ),
            const SizedBox(width: 6),
            chip(ms.toolWall, CanvasTool.wallPen, const MouseToolIcon(size: 14)),
            const SizedBox(width: 6),
            chip(ms.toolCeil, CanvasTool.ceilingPen, const MouseToolIcon(size: 14)),
            const SizedBox(width: 6),
            chip(ms.toolDrop, CanvasTool.dropPen, const MouseToolIcon(size: 14)),
            const SizedBox(width: 10),
            Text(
              _touching
                  ? (_mouseReady ? ms.hintGreenNext : ms.hintRedHold)
                  : (modeHint.isEmpty
                      ? ms.hintDefault
                      : modeHint == ms.modeOpening
                          ? ms.hintOpening
                          : modeHint == ms.modeDrop
                              ? ms.hintDrop
                              : (_tool == CanvasTool.ceilingPen
                                  ? ms.ceilHint(_ceilingGroupNumber)
                                  : ms.hintModeDraw(modeHint))),
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
        final macPanClickZoom =
            _isMac && _tool == CanvasTool.pan && !_dropSecWidthMode;
        return MouseRegion(
          // 描画ツール：精密十字カーソル（ホットスポット＝中心＝測点）
          // 押下中はシステムカーソルを隠し、自前の先端リングを表示
          cursor: _isMac && _tool != CanvasTool.pan
              ? ((_touching || _dropSecWidthMode)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.precise)
              : MouseCursor.defer,
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                _macNavScrollZoom(e, box.globalToLocal(e.position));
              }
            },
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.05,
                  maxScale: 20,
                  // Mac：描画ツール中でも二本指パン／ピンチ可（マウス押下中のみ停止）
                  panEnabled: !_touching && !_dropSecWidthMode,
                  scaleEnabled: !_dropSecWidthMode,
                  child: SizedBox(
                    width: _imageSize.width,
                    height: _imageSize.height,
                    child: Listener(
                      onPointerDown: (e) {
                        if (macPanClickZoom) {
                          _macNavPointerDown(e, e.localPosition);
                        }
                        _openedNumberOnDown = false;
                        // 天井／壁／下り／開口の番号は移動モードでもタップ可
                        for (final b in _ceilingBadgeHits) {
                          if (b.hit(e.localPosition)) {
                            _holdTicker?.cancel();
                            setState(() {
                              _touching = false;
                              _mouseTip = null;
                              _selectedCeilingId = b.ceilingId;
                              for (final ceil in _measurement?.ceilings ??
                                  const <CeilingRegion>[]) {
                                if (ceil.id == b.ceilingId &&
                                    ceil.highlightArgb != null) {
                                  _drawColorArgb = ceil.highlightArgb!;
                                  break;
                                }
                              }
                            });
                            _openedNumberOnDown = true;
                            _openCeilingParams(b.ceilingId);
                            return;
                          }
                        }
                        final wallBadge = _badgeAt(e.localPosition);
                        if (wallBadge != null) {
                          _holdTicker?.cancel();
                          setState(() {
                            _touching = false;
                            _mouseTip = null;
                          });
                          _openedNumberOnDown = true;
                          _openWallMaterial(wallBadge.wallId);
                          return;
                        }
                        for (final b in _dropBadgeHits) {
                          if (b.hit(e.localPosition, radius: 28)) {
                            _holdTicker?.cancel();
                            setState(() {
                              _touching = false;
                              _mouseTip = null;
                              _selectedDropId = b.dropId;
                              for (final d in _measurement?.drops ??
                                  const <DropRegion>[]) {
                                if (d.id == b.dropId &&
                                    d.highlightArgb != null) {
                                  _drawColorArgb = d.highlightArgb!;
                                  break;
                                }
                              }
                            });
                            _openedNumberOnDown = true;
                            _editDrop(b.dropId);
                            return;
                          }
                        }
                        for (final h in _openingHits) {
                          if (h.hit(e.localPosition)) {
                            _holdTicker?.cancel();
                            setState(() {
                              _touching = false;
                              _mouseTip = null;
                              _openingDraft.clear();
                            });
                            _openedNumberOnDown = true;
                            _editOpening(h.openingId);
                            return;
                          }
                        }
                        for (final h in _dropWidthPlusHits) {
                          if (h.hit(e.localPosition, radius: 22)) {
                            _holdTicker?.cancel();
                            _startDropSecondWidthMeasure(h);
                            return;
                          }
                        }
                        if (_dropSecWidthMode) {
                          _onPointerDownSecWidth(e.localPosition);
                          return;
                        }
                        if (_tool == CanvasTool.pan) return;
                        _onPointerDown(e.localPosition);
                      },
                      onPointerMove: (e) {
                        if (macPanClickZoom) {
                          _macNavPointerMove(e, e.localPosition);
                        }
                        if (_dropSecWidthMode) {
                          _onPointerMoveSecWidth(e.localPosition);
                          return;
                        }
                        if (_tool == CanvasTool.pan) return;
                        _onPointerMove(e.localPosition);
                      },
                      onPointerUp: (e) {
                        if (macPanClickZoom) {
                          _macNavPointerUp(e, e.localPosition);
                        }
                        if (_dropSecWidthMode) {
                          _onPointerUpSecWidth(e.localPosition);
                          return;
                        }
                        if (_tool == CanvasTool.pan) return;
                        _onPointerUp(e.localPosition);
                      },
                      onPointerCancel: (e) {
                        if (macPanClickZoom) {
                          _macNavPointerUp(e, e.localPosition);
                        }
                      },
                      child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RawImage(image: _bgImage, fit: BoxFit.fill),
                      AnimatedBuilder(
                        animation: _transform,
                        builder: (context, _) {
                          final vs = _viewScale;
                          final inv = 1.0 / vs.clamp(0.35, 5.0);
                          final ceilings = _measurement!.ceilings;
                          _ceilingBadgeHits.clear();
                          final badgeOverlays = <Widget>[];
                          for (var i = 0; i < ceilings.length; i++) {
                            final c = ceilings[i];
                            if (c.points.length < 3) continue;
                            var sx = 0.0, sy = 0.0;
                            for (final p in c.points) {
                              sx += p.x;
                              sy += p.y;
                            }
                            final cx = sx / c.points.length;
                            final cy = sy / c.points.length;
                            final areaM2 = (c.quantities['ceiling_area_m2'] ??
                                    CalcEngine.polygonAreaMm2(c.points, _k) /
                                        1e6)
                                .toDouble();
                            if (areaM2 <= 0) continue;
                            final n =
                                c.groupNumber <= 0 ? (i + 1) : c.groupNumber;
                            final areaText = areaM2 >= 10
                                ? '${areaM2.toStringAsFixed(1)} ㎡'
                                : '${areaM2.toStringAsFixed(2)} ㎡';
                            final metricTp = TextPainter(
                              text: TextSpan(
                                text: areaText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              textDirection: TextDirection.ltr,
                            )..layout();
                            final chipHit = numberMetricChipHit(
                              anchor: Offset(cx, cy),
                              inv: inv,
                              metricWidth: metricTp.width,
                            );
                            _ceilingBadgeHits.add(
                              CeilingBadgeHit(
                                ceilingId: c.id,
                                center: chipHit.numberCenter,
                                number: n,
                                radius: 22 * inv,
                                hitRect: chipHit.hitRect,
                              ),
                            );
                            badgeOverlays.add(
                              Positioned(
                                left: cx,
                                top: cy,
                                child: Transform.translate(
                                  offset: Offset(-52 * inv, -16 * inv),
                                  child: Transform.scale(
                                    scale: inv,
                                    alignment: Alignment.topLeft,
                                    child: _NumberMetricChip(
                                      number: n,
                                      metricText: areaText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          // 壁番号＋長さ合計（天井と同サイズのチップ）
                          var wallNo = 0;
                          for (final w in _measurement!.walls) {
                            if (w.isIronPlate || w.points.length < 2) continue;
                            wallNo++;
                            final tip = Offset(
                              w.points.last.x,
                              w.points.last.y,
                            );
                            final lenMm = (w.quantities['wall_length_mm']
                                        as num?)
                                    ?.toDouble() ??
                                wallDrawnLengthMm(w, _k);
                            final lenText =
                                lenMm > 0 ? distanceLabelText(lenMm) : '—';
                            badgeOverlays.add(
                              Positioned(
                                left: tip.dx,
                                top: tip.dy,
                                child: Transform.translate(
                                  offset: Offset(-52 * inv, -16 * inv),
                                  child: Transform.scale(
                                    scale: inv,
                                    alignment: Alignment.topLeft,
                                    child: _NumberMetricChip(
                                      number: wallNo,
                                      metricText: lenText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          // 下り番号＋総長さ（天井／壁と同サイズの底座チップ）
                          for (final d in _measurement?.drops ?? const []) {
                            if (d.points.length < 2) continue;
                            final tip = Offset(
                              d.points.last.x,
                              d.points.last.y,
                            );
                            final lenMm = d.lengthMm > 0
                                ? d.lengthMm
                                : (d.quantities['drop_length_mm'] as num?)
                                        ?.toDouble() ??
                                    0;
                            final lenText =
                                lenMm > 0 ? distanceLabelText(lenMm) : '—';
                            badgeOverlays.add(
                              Positioned(
                                left: tip.dx,
                                top: tip.dy,
                                child: Transform.translate(
                                  offset: Offset(-52 * inv, -16 * inv),
                                  child: Transform.scale(
                                    scale: inv,
                                    alignment: Alignment.topLeft,
                                    child: _NumberMetricChip(
                                      number: d.groupNumber,
                                      metricText: lenText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Stack(
                            fit: StackFit.expand,
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                painter: OverlayMidPainter(
                                  snapLines: _snapEnabled
                                      ? _snapLines
                                      : const [],
                                  ceilings: ceilings,
                                  ceilingDraft: [
                                    ..._ceilingDraft,
                                    if (_tool == CanvasTool.ceilingPen &&
                                        _touching &&
                                        _mouseTip != null &&
                                        !_mouseReady)
                                      _mouseTip!,
                                  ],
                                  drops: _measurement?.drops ?? const [],
                                  dropDraft: [
                                    ..._dropDraft,
                                    if (_tool == CanvasTool.dropPen &&
                                        !_dropSecWidthMode &&
                                        _touching &&
                                        _mouseTip != null &&
                                        !_mouseReady)
                                      _mouseTip!,
                                  ],
                                  dropBadgeHits: _dropBadgeHits,
                                  dropWidthPlusHits: _dropWidthPlusHits,
                                  dropDraftTurnWidths: _dropDraftTurnWidths,
                                  dropWidthMeasureOrigin: _dropSecWidthMode
                                      ? _dropSecWidthOrigin
                                      : null,
                                  dropWidthMeasureTip: _dropSecWidthMode
                                      ? _mouseTip
                                      : null,
                                  dropWidthMeasureTurnIndex: _dropSecWidthMode
                                      ? _dropSecWidthTurnIndex
                                      : null,
                                  scalePxPerMm: _k,
                                  draftFillArgb: _drawColorArgb,
                                  viewScale: vs,
                                  paintDropNumberBadges: false,
                                  ironDraft: _wallDrawMode == WallDrawMode.ironPlate,
                                  wallDraftFollowTip: _touching &&
                                      _mouseTip != null &&
                                      !_mouseReady,
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
                                  ceilings: ceilings,
                                  showLgsPreview: FeatureAccess.hasFullAccess(
                                    context.read<AppState>().user,
                                  ),
                                  openings: _measurement!.openings,
                                  openingDraft: [
                                    ..._openingDraft,
                                    if (_tool ==
                                            CanvasTool.openingReinforce &&
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
                                  ironDraft:
                                      _wallDrawMode == WallDrawMode.ironPlate,
                                  wallDraftFollowTip:
                                      _wallDrawMode == WallDrawMode.ironPlate &&
                                          _touching &&
                                          _mouseTip != null &&
                                          !_mouseReady,
                                  wallDraft: [
                                    ..._wallPoints,
                                    if (_wallDrawMode ==
                                            WallDrawMode.ironPlate &&
                                        _touching &&
                                        _mouseTip != null &&
                                        !_mouseReady)
                                      _mouseTip!,
                                  ],
                                  badgeHits: _badgeHits,
                                  ceilingBadgeHits: null,
                                  openingHits: _openingHits,
                                  viewScale: vs,
                                  paintCeilingLabels: false,
                                ),
                              ),
                              ...badgeOverlays,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 画面固定サイズのマウス／Mac は先端十字＋赤→緑リング
            if ((_touching || _dropSecWidthMode) && _mouseTip != null)
              AnimatedBuilder(
                animation: _transform,
                builder: (context, _) {
                  final screenTip = MatrixUtils.transformPoint(
                    _transform.value,
                    _mouseTip!,
                  );
                  final readyColor = _mouseReady
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828);
                  if (_isMac) {
                    const box = 48.0;
                    return Positioned(
                      left: screenTip.dx - box / 2,
                      top: screenTip.dy - box / 2,
                      width: box,
                      height: box,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: const Size(box, box),
                          painter: MacMeasureTipPainter(
                            progress: _holdProgress,
                            color: readyColor,
                          ),
                        ),
                      ),
                    );
                  }
                  const boxW = 88.0;
                  const boxH = 145.0;
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
                              color: readyColor,
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
            if (_tool == CanvasTool.dropPen)
              Positioned(
                top: 10,
                right: 10,
                child: IgnorePointer(
                  child: Material(
                    elevation: 4,
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: DropDrawGuide(width: 148, height: 108),
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
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
                child: Text(Ms.of(context).undoPoint),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _ceilingDraft.isEmpty
                    ? null
                    : () => setState(() {
                          _ceilingDraft.clear();
                          _clearWallDraft();
                        }),
                child: Text(Ms.of(context).clear),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    Ms.of(context).ceilBottomHint,
                    style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                  ),
                ),
              ),
            ] else if (_tool == CanvasTool.wallPen) ...[
              OutlinedButton(
                onPressed: (_wallPoints.isEmpty && _mouseTip == null)
                    ? null
                    : _clearWallDraft,
                child: Text(Ms.of(context).clear),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    Ms.of(context).wallBottomHint,
                    style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  Ms.of(context).pinchHint,
                  style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 番号＋計測値チップ（天井面積／壁長さで共通。画像座標で Transform.scale）
class _NumberMetricChip extends StatelessWidget {
  const _NumberMetricChip({
    required this.number,
    required this.metricText,
  });

  final int number;
  final String metricText;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black45,
      color: const Color(0xFF0D47A1),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              metricText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
