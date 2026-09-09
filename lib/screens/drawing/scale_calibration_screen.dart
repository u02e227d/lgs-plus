import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

/// InfCMS 同型の実測値（十字）比例尺設定
/// - ボタンで十字を出し、画面固定サイズのままドラッグ
/// - 始点確定 → 終点確定 → 実寸入力 → K (px/mm)
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
      const SnackBar(
        content: Text('実測値アイコンを始点までドラッグし、指を離して確定'),
        duration: Duration(seconds: 2),
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

    if (_phase == _ScalePhase.aimStart) {
      setState(() {
        _startContent = contentPt;
        _phase = _ScalePhase.aimEnd;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('始点確定。終点までドラッグして指を離してください'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_phase == _ScalePhase.aimEnd && _startContent != null) {
      // 始点とほぼ同じ位置は無視
      if ((contentPt - _startContent!).distance < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('始点から離れた位置で終点を指定してください')),
        );
        return;
      }
      setState(() => _endContent = contentPt);
      await _promptAndSave();
    }
  }

  Future<void> _promptAndSave() async {
    if (_startContent == null || _endContent == null) return;
    final px = (_endContent! - _startContent!).distance;
    _mmCtrl.text = '0';
    _mmCtrl.selection = TextSelection(baseOffset: 0, extentOffset: 1);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('実寸を入力'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '図面上の距離: ${px.toStringAsFixed(1)} px',
              style: const TextStyle(color: AppTheme.steel, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mmCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '実寸 (mm)',
                hintText: '例: 1950',
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
            child: const Text('やり直す'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final mm = double.tryParse(_mmCtrl.text.trim().replaceAll(',', ''));
    if (mm == null || mm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正しいミリメートル値を入力してください（0より大きい数）')),
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
    await context.read<AppState>().saveDrawing(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '比例尺を保存しました  ${px.toStringAsFixed(0)}px ÷ ${mm.toStringAsFixed(0)}mm'
          ' = K=${k.toStringAsFixed(4)} px/mm',
        ),
      ),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final phaseHint = switch (_phase) {
      _ScalePhase.idle => '実測値ボタンを押し、十字を図面に出してください',
      _ScalePhase.aimStart => '十字を始点へドラッグ → 指を離して確定',
      _ScalePhase.aimEnd => '十字を終点へドラッグ → 指を離して実寸入力',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('比例尺設定'),
        actions: [
          if (_phase != _ScalePhase.idle)
            TextButton(
              onPressed: _reset,
              child: const Text('リセット', style: TextStyle(color: Colors.white)),
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
                  child: Text(
                    phaseHint,
                    style: const TextStyle(fontSize: 13, color: AppTheme.steel),
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
                            _phase == _ScalePhase.idle ? '実測値' : '測定中',
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
                      return Stack(
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
                              left: _crosshairViewport.dx - _crosshairSize / 2,
                              top: _crosshairViewport.dy - _crosshairSize / 2,
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: _onPointerDown,
                                onPointerMove: _onPointerMove,
                                onPointerUp: _onPointerUp,
                                onPointerCancel: _onPointerUp,
                                child: SizedBox(
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
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x99E53935),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      Image.asset(
                                        'assets/drawable/shouzhi2x.png',
                                        width: _fingerSize,
                                        height: _fingerSize,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
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
