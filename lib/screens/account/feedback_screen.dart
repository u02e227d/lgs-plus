import 'package:flutter/material.dart';
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
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'opinion';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
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
    final err = await LgsplusCloud.submitReport(
      user: user,
      kind: _kind,
      title: title,
      body: body,
      lang: LocaleController.instance.lang.code,
    );
    if (!mounted) return;
    setState(() => _busy = false);
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
