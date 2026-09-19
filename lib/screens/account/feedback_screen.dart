import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../services/lgsplus_cloud.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _maxImages = 3;

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();
  String _kind = 'opinion';
  bool _busy = false;
  final List<XFile> _images = [];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final s = S.of(context);
    final remain = _maxImages - _images.length;
    if (remain <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.feedbackImageMax)),
      );
      return;
    }
    final picked = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.take(remain));
    });
    if (picked.length > remain && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.feedbackImageMax)),
      );
    }
  }

  Future<List<Map<String, String>>> _encodeImages() async {
    final out = <Map<String, String>>[];
    for (final x in _images) {
      final bytes = await File(x.path).readAsBytes();
      if (bytes.isEmpty) continue;
      final lower = x.path.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      out.add({
        'mime': mime,
        'data': base64Encode(bytes),
      });
    }
    return out;
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final user = context.read<AppState>().user;
    if (user == null) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.feedbackNeedText)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final images = await _encodeImages();
      final err = await LgsplusCloud.submitReport(
        user: user,
        kind: _kind,
        title: title,
        body: body,
        lang: LocaleController.instance.lang.code,
        images: images,
      );
      if (!mounted) return;
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.feedbackSent)),
        );
        Navigator.pop(context);
        return;
      }
      final message = switch (err) {
        'offline' => s.feedbackOffline,
        'send_failed' => s.feedbackFailed,
        _ => err,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.feedbackTitle)),
      body: KeyboardDoneScope(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              s.feedbackHint,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(s.feedbackKind, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'opinion', label: Text(s.feedbackOpinion)),
                ButtonSegment(value: 'request', label: Text(s.feedbackRequest)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: s.feedbackSubject,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 6,
              maxLines: 12,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: s.feedbackBody,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.feedbackImages,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              s.feedbackImagesHint,
              style: const TextStyle(color: AppTheme.steel, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_images[i].path),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(28, 28),
                          ),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _images.removeAt(i)),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                if (_images.length < _maxImages)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.feedbackAddImage),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.send),
              label: Text(s.feedbackSend),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
