import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'scale_calibration_screen.dart';

class UploadDrawingScreen extends StatefulWidget {
  const UploadDrawingScreen({
    super.key,
    required this.projectId,
    this.existing,
  });

  final String projectId;
  final DrawingFile? existing;

  @override
  State<UploadDrawingScreen> createState() => _UploadDrawingScreenState();
}

class _UploadDrawingScreenState extends State<UploadDrawingScreen> {
  DrawingFile? _drawing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _drawing = widget.existing;
  }

  /// フォルダ／ファイルから取り込み（PDF・画像）
  Future<void> _importFromFolder() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'heic', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (files.isEmpty) return;
    final f = files.first;
    setState(() => _busy = true);
    try {
      late Uint8List bytes;
      if (f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      } else {
        bytes = await f.readAsBytes();
      }

      final lower = f.name.toLowerCase();
      final isPdf = lower.endsWith('.pdf');
      late File saved;
      late String kind;

      if (isPdf) {
        final doc = await PdfDocument.openData(bytes);
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        await doc.close();
        if (pageImage == null) throw Exception('PDFレンダリングに失敗しました');
        saved = await DrawingImportService.persistBytes(
          pageImage.bytes,
          '${f.name}.png',
        );
        kind = 'pdf';
      } else {
        saved = await DrawingImportService.persistBytes(bytes, f.name);
        kind = 'image';
      }

      final state = context.read<AppState>();
      final drawing = DrawingFile(
        id: state.newId(),
        projectId: widget.projectId,
        localPath: saved.path,
        fileName: f.name,
        kind: kind,
      );
      final stored = await state.saveDrawing(drawing);
      if (!mounted) return;
      setState(() => _drawing = stored);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('図面を保存しました。続けて比例尺を設定してください')),
      );
      await _goScale(stored);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importImage({required bool camera}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 95,
    );
    if (x == null) return;
    setState(() => _busy = true);
    try {
      final saved = await DrawingImportService.persistFile(
        File(x.path),
        x.name,
      );
      final state = context.read<AppState>();
      final drawing = DrawingFile(
        id: state.newId(),
        projectId: widget.projectId,
        localPath: saved.path,
        fileName: x.name,
        kind: 'image',
      );
      final stored = await state.saveDrawing(drawing);
      if (!mounted) return;
      setState(() => _drawing = stored);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('図面を保存しました。続けて比例尺を設定してください')),
      );
      await _goScale(stored);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goScale(DrawingFile drawing) async {
    final updated = await Navigator.of(context).push<DrawingFile>(
      MaterialPageRoute(
        builder: (_) => ScaleCalibrationScreen(drawing: drawing),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _drawing = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _drawing;
    return Scaffold(
      appBar: AppBar(title: const Text('図面アップロード')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '①フォルダ → ②アルバム → ③カメラ撮影の順で図面を取り込み、既知寸法で比例尺を設定します。',
            style: TextStyle(color: AppTheme.steel),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          ElevatedButton.icon(
            onPressed: _busy ? null : _importFromFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('① フォルダから選択（PDF / 画像）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _importImage(camera: false),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('② アルバムから選択'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _importImage(camera: true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('③ カメラで撮影・計測'),
          ),
          if (d != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.file(
                        File(d.localPath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('プレビュー不可'),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(d.fileName),
                    subtitle: Text(
                      d.scalePxPerMm == null
                          ? 'スケール未設定'
                          : 'K = ${d.scalePxPerMm!.toStringAsFixed(4)} px/mm',
                    ),
                    trailing: TextButton(
                      onPressed: () => _goScale(d),
                      child: const Text('スケール設定'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, d),
              child: const Text('完了'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 画像サイズ取得ヘルパ
Future<ui.Size> decodeImageSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
}
