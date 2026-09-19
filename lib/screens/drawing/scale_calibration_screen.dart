import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/app_platform.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';

/// InfCMS 同型の実測値（十字）比例尺設定
/// - ボタンで十字を出し、画面固定サイズのままドラッグ
/// - 始点確定 → 終点確定 → 実寸入力 → K (px/mm)
/// - 保存後は SQLite ＋ SharedPreferences にローカル永続化
class ScaleCalibrationScreen extends StatefulWidget {
  const ScaleCalibrationScreen({super.key, required this.drawing});

  final DrawingFile drawing;

  @override
  State<ScaleCalibrationScreen> createState() => _ScaleCalibrationScreenState();
}

enum _ScalePhase { idle, aimStart, aimEnd }

class _ScaleCalibrationScreenState extends State<ScaleCalibrationScreen> {
  final _transform = TransformationController();
  final _viewportKey = GlobalKey();
  final _mmCtrl = TextEditingController(text: '0');

  _ScalePhase _phase = _ScalePhase.idle;
  bool _crosshairReady = false;

  /// ビューポート（十字オーバーレイ）座標 — ズームしてもサイズ不変
  Offset _crosshairViewport = Offset.zero;

  /// 図面ピクセル座標（測定キャンバスと同じ座標系）
  Offset? _startContent;
  Offset? _endContent;

  Size _imageSize = Size.zero;
  ui.Image? _bgImage;

  // ドラッグ基準（InfCMS 同様：ポインタ差分で追従）
  Offset _dragStartCrosshair = Offset.zero;
  Offset _dragStartGlobal = Offset.zero;
  int? _activePointer;
  bool _dragging = false;

  // Mac：クリック縮小／ダブルクリック拡大／ドラッグ移動
  static bool get _isMac => AppPlatform.usesDesktopPointer;
  Offset? _macDownPos;
  Offset? _macDownGlobal;
  Matrix4? _macDownMatrix;
  DateTime? _macLastTapAt;
  Offset? _macLastTapPos;
  bool _macPanning = false;
  bool _macOnCrosshair = false;
  Timer? _macTapZoomTimer;
  static const _macClickSlop = 6.0;
  static const _macDoubleTapMs = 350;
  static const _macZoomIn = 1.35;
  static const _macZoomOut = 1 / 1.35;

  static const double _crosshairSize = 144;
  static const double _fingerSize = 54;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
    _loadImage();
  }

  @override
  void dispose() {
    _macTapZoomTimer?.cancel();
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    _mmCtrl.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.drawing.localPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _bgImage = frame.image;
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitImageInView());
  }

  /// 図面全体が見える初期ズーム（ピクセル座標系は維持）
  void _fitImageInView() {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _imageSize == Size.zero) return;
    final vw = box.size.width;
    final vh = box.size.height;
    if (vw <= 0 || vh <= 0) return;
    final sx = vw / _imageSize.width;
    final sy = vh / _imageSize.height;
    final s = math.min(sx, sy) * 0.96;
    if (s <= 0) return;
    final dx = (vw - _imageSize.width * s) / 2;
    final dy = (vh - _imageSize.height * s) / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  Offset _contentToViewport(Offset content) {
    return MatrixUtils.transformPoint(_transform.value, content);
  }

  Offset _viewportToContent(Offset viewport) {
    final inv = Matrix4.inverted(_transform.value);
    return MatrixUtils.transformPoint(inv, viewport);
  }

  Offset? get _startViewport =>
      _startContent == null ? null : _contentToViewport(_startContent!);

  Offset? get _endViewport =>
      _endContent == null ? null : _contentToViewport(_endContent!);

  void _activateSniper() {
    _mmCtrl.text = '0';
    setState(() {
      _phase = _ScalePhase.aimStart;
      _startContent = null;
      _endContent = null;
      _crosshairReady = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !mounted) return;
      setState(() {
        _crosshairViewport = Offset(box.size.width / 2, box.size.height / 2);
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).scaleHintStart),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _reset() {
    setState(() {
      _phase = _ScalePhase.idle;
      _crosshairReady = false;
      _startContent = null;
      _endContent = null;
      _dragging = false;
      _activePointer = null;
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    _dragging = true;
    _activePointer = e.pointer;
    _dragStartCrosshair = _crosshairViewport;
    _dragStartGlobal = e.position;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_dragging || e.pointer != _activePointer) return;
    final next = _dragStartCrosshair + (e.position - _dragStartGlobal);
    setState(() => _crosshairViewport = next);
  }

  Future<void> _onPointerUp(PointerEvent e) async {
    if (!_dragging || e.pointer != _activePointer) return;
    _dragging = false;
    _activePointer = null;

    final contentPt = _viewportToContent(_crosshairViewport);
    await _confirmAimPoint(contentPt);
  }

  Future<void> _confirmAimPoint(Offset contentPt) async {
    if (_phase == _ScalePhase.aimStart) {
      setState(() {
        _startContent = contentPt;
        _phase = _ScalePhase.aimEnd;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).scaleHintEnd),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_phase == _ScalePhase.aimEnd && _startContent != null) {
      // 始点とほぼ同じ位置は無視
      if ((contentPt - _startContent!).distance < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).scaleNeedDistance)),
        );
        return;
      }
      setState(() => _endContent = contentPt);
      await _promptAndSave();
    }
  }

  bool _hitCrosshair(Offset viewportLocal) {
    if (!_crosshairReady) return false;
    final d = (viewportLocal - _crosshairViewport).distance;
    return d <= _crosshairSize / 2;
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

    // 焦点がずれないよう微調整
    final after = MatrixUtils.transformPoint(matrix, sceneFocal);
    matrix.translateByDouble(
      focalViewport.dx - after.dx,
      focalViewport.dy - after.dy,
      0,
      1,
    );
    _transform.value = matrix;
  }

  void _macPointerDown(PointerDownEvent e) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(e.position);
    _macDownPos = local;
    _macDownGlobal = e.position;
    _macDownMatrix = Matrix4.copy(_transform.value);
    _macPanning = false;
    _macOnCrosshair = _hitCrosshair(local);
    _activePointer = e.pointer;

    if (_macOnCrosshair && _crosshairReady) {
      _dragging = true;
      _dragStartCrosshair = _crosshairViewport;
      _dragStartGlobal = e.position;
    }
  }

  void _macPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer || _macDownPos == null) return;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(e.position);
    final delta = local - _macDownPos!;

    if (_macOnCrosshair && _dragging) {
      final next = _dragStartCrosshair + (e.position - _macDownGlobal!);
      setState(() => _crosshairViewport = next);
      return;
    }

    if (delta.distance > _macClickSlop) {
      _macTapZoomTimer?.cancel();
      _macTapZoomTimer = null;
      _macLastTapAt = null;
      _macLastTapPos = null;
      _macPanning = true;
      final m = Matrix4.copy(_macDownMatrix!);
      m.translateByDouble(delta.dx, delta.dy, 0, 1);
      _transform.value = m;
    }
  }

  Future<void> _macPointerUp(PointerEvent e) async {
    if (e.pointer != _activePointer) return;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(e.position) ?? _macDownPos;
    final wasOnCrosshair = _macOnCrosshair;
    final wasPanning = _macPanning;
    final downPos = _macDownPos;

    _dragging = false;
    _activePointer = null;
    _macOnCrosshair = false;
    _macPanning = false;
    _macDownPos = null;
    _macDownGlobal = null;
    _macDownMatrix = null;

    if (local == null || downPos == null) return;

    if (wasOnCrosshair && _crosshairReady) {
      await _confirmAimPoint(_viewportToContent(_crosshairViewport));
      return;
    }

    if (wasPanning) return;

    final now = DateTime.now();
    final isDouble = _macLastTapAt != null &&
        now.difference(_macLastTapAt!) <
            const Duration(milliseconds: _macDoubleTapMs) &&
        _macLastTapPos != null &&
        (local - _macLastTapPos!).distance < 28;

    if (isDouble) {
      _macTapZoomTimer?.cancel();
      _macTapZoomTimer = null;
      _macLastTapAt = null;
      _macLastTapPos = null;
      _zoomAtViewport(local, _macZoomIn);
      return;
    }

    _macLastTapAt = now;
    _macLastTapPos = local;
    _macTapZoomTimer?.cancel();
    _macTapZoomTimer = Timer(
      const Duration(milliseconds: _macDoubleTapMs),
      () {
        if (!mounted) return;
        final focal = _macLastTapPos;
        _macLastTapAt = null;
        _macLastTapPos = null;
        _macTapZoomTimer = null;
        if (focal != null) _zoomAtViewport(focal, _macZoomOut);
      },
    );
  }

  Future<void> _promptAndSave() async {
    if (_startContent == null || _endContent == null) return;
    final px = (_endContent! - _startContent!).distance;
    _mmCtrl.text = '0';
    _mmCtrl.selection = TextSelection(baseOffset: 0, extentOffset: 1);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final s = S.of(ctx);
        return AlertDialog(
        title: Text(s.enterRealSize),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.drawingDistancePx(px.toStringAsFixed(1)),
              style: const TextStyle(color: AppTheme.steel, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mmCtrl,
              autofocus: true,
              keyboardType: DoneKeyboard.decimal,
              inputFormatters: DoneKeyboard.decimalFormatters,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              decoration: InputDecoration(
                labelText: s.realSizeMm,
                hintText: '1950',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _endContent = null;
                _phase = _ScalePhase.aimEnd;
              });
              Navigator.pop(ctx, false);
            },
            child: Text(s.retry),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirmValue),
          ),
        ],
      );
      },
    );

    if (ok != true || !mounted) return;

    final mm = double.tryParse(_mmCtrl.text.trim().replaceAll(',', ''));
    if (mm == null || mm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).invalidMm)),
      );
      setState(() {
        _endContent = null;
        _phase = _ScalePhase.aimEnd;
      });
      return;
    }

    // K = 図面ピクセル / 実寸mm（測定キャンバスと同じ定義）
    final k = px / mm;
    final updated = widget.drawing.copyWith(scalePxPerMm: k);
    final saved = await context.read<AppState>().saveDrawing(updated);
    // 端末ローカルへ二重保存（再起動後も確実に復元）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('drawing_scale_${saved.id}', k);
    await prefs.setString(
      'drawing_scale_meta_${saved.id}',
      '${DateTime.now().toIso8601String()}|${px.toStringAsFixed(1)}|$mm',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          S.of(context).scaleSaved(
            px.toStringAsFixed(0),
            mm.toStringAsFixed(0),
            k.toStringAsFixed(4),
          ),
        ),
      ),
    );
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final existingK = widget.drawing.scalePxPerMm;
    final phaseHint = switch (_phase) {
      _ScalePhase.idle => existingK != null
          ? s.scaleHintIdleSaved(existingK.toStringAsFixed(4))
          : s.scaleHintIdleUnset,
      _ScalePhase.aimStart => s.scaleHintAimStart,
      _ScalePhase.aimEnd => s.scaleHintAimEnd,
    };
    final navHint = _isMac ? s.scaleHintMacNav : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.setScale),
        actions: [
          if (_phase != _ScalePhase.idle)
            TextButton(
              onPressed: _reset,
              child: Text(s.reset, style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phaseHint,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.steel,
                        ),
                      ),
                      if (navHint != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          navHint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.steel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _phase != _ScalePhase.idle
                      ? AppTheme.safetyYellow
                      : AppTheme.navy,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _phase == _ScalePhase.idle ? _activateSniper : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/drawable/draw_chi_n.png',
                            width: 28,
                            height: 28,
                            color: _phase != _ScalePhase.idle
                                ? AppTheme.navy
                                : Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _phase == _ScalePhase.idle ? s.setScale : s.measuring,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _phase != _ScalePhase.idle
                                  ? AppTheme.navy
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _bgImage == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _isMac ? _macPointerDown : null,
                        onPointerMove: _isMac ? _macPointerMove : null,
                        onPointerUp: _isMac ? _macPointerUp : null,
                        onPointerCancel: _isMac ? _macPointerUp : null,
                        child: Stack(
                          key: _viewportKey,
                          fit: StackFit.expand,
                          children: [
                            // 図面：測定キャンバスと同じく画像ピクセル＝座標系
                            InteractiveViewer(
                              transformationController: _transform,
                              constrained: false,
                              boundaryMargin:
                                  const EdgeInsets.all(double.infinity),
                              minScale: 0.05,
                              maxScale: 20,
                              // Mac は自前でクリック拡大縮小・ドラッグ移動
                              panEnabled: !_isMac,
                              scaleEnabled: !_isMac,
                              child: SizedBox(
                                width: _imageSize.width,
                                height: _imageSize.height,
                                child: RawImage(
                                  image: _bgImage,
                                  width: _imageSize.width,
                                  height: _imageSize.height,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),

                            // 測定線・始点マーク（ビューポート座標・サイズ固定）
                            if (_startViewport != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _ScaleOverlayPainter(
                                      start: _startViewport!,
                                      end: _phase == _ScalePhase.aimEnd
                                          ? _crosshairViewport
                                          : _endViewport,
                                    ),
                                  ),
                                ),
                              ),

                            // 狙撃十字（画面固定サイズ）
                            if (_crosshairReady)
                              Positioned(
                                left:
                                    _crosshairViewport.dx - _crosshairSize / 2,
                                top:
                                    _crosshairViewport.dy - _crosshairSize / 2,
                                child: _isMac
                                    ? IgnorePointer(
                                        child: _crosshairVisual(),
                                      )
                                    : Listener(
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown: _onPointerDown,
                                        onPointerMove: _onPointerMove,
                                        onPointerUp: _onPointerUp,
                                        onPointerCancel: _onPointerUp,
                                        child: _crosshairVisual(),
                                      ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _crosshairVisual() {
    return SizedBox(
      width: _crosshairSize,
      height: _crosshairSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/drawable/measure_crosshair2x.png',
            width: _crosshairSize,
            height: _crosshairSize,
            fit: BoxFit.contain,
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0x99E53935),
                width: 1.5,
              ),
            ),
          ),
          // Mac は実マウスを使うため指アイコンは出さない
          if (!_isMac)
            Image.asset(
              'assets/drawable/shouzhi2x.png',
              width: _fingerSize,
              height: _fingerSize,
              fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }
}

class _ScaleOverlayPainter extends CustomPainter {
  _ScaleOverlayPainter({required this.start, required this.end});

  final Offset start;
  final Offset? end;

  @override
  void paint(Canvas canvas, Size size) {
    final startPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 6, startPaint);
    canvas.drawCircle(
      start,
      10,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (end == null) return;

    final line = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 破線
    final path = Path()..moveTo(start.dx, start.dy);
    path.lineTo(end!.dx, end!.dy);
    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      var d = 0.0;
      const dash = 8.0;
      const gap = 6.0;
      while (d < m.length) {
        final next = math.min(d + dash, m.length);
        canvas.drawPath(m.extractPath(d, next), line);
        d = next + gap;
      }
    }

    canvas.drawCircle(end!, 6, startPaint);
  }

  @override
  bool shouldRepaint(covariant _ScaleOverlayPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
