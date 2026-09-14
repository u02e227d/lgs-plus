import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/locale_controller.dart';
import '../../services/invite_card.dart';
import '../../theme/app_theme.dart';

/// メール画面に近い招待送信
class InviteComposeScreen extends StatefulWidget {
  const InviteComposeScreen({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  State<InviteComposeScreen> createState() => _InviteComposeScreenState();
}

class _InviteComposeScreenState extends State<InviteComposeScreen> {
  late final TextEditingController _to;
  late final TextEditingController _subject;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    final s = LocaleController.instance.strings;
    _to = TextEditingController();
    _subject = TextEditingController(text: s.inviteSubject);
    _body = TextEditingController(text: s.inviteBody(widget.inviteCode));
  }

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  String get _text {
    final dest = _to.text.trim();
    final head = dest.isEmpty
        ? ''
        : LocaleController.instance.strings.destPrefix(dest);
    return '$head${_subject.text.trim()}\n\n${_body.text.trim()}';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).inviteCopied)),
    );
  }

  Future<void> _shareSheet() async {
    await SharePlus.instance.share(ShareParams(text: _text));
  }

  Future<void> _open(Uri uri, String fallbackLabel) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).cannotOpen(fallbackLabel))),
      );
      await _shareSheet();
    }
  }

  Future<void> _sendLine() async {
    final uri = Uri.parse(
      'https://line.me/R/msg/text/?${Uri.encodeComponent(_text)}',
    );
    await _open(uri, 'LINE');
  }

  Future<void> _sendWeChat() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).weChatShareTitle),
        content: Text(S.of(ctx).weChatShareBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx).sendImage),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      final bytes = await InviteCard.png(inviteCode: widget.inviteCode);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lgs_invite_${widget.inviteCode}.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).imageFailed)),
      );
      await launchUrl(
        Uri.parse('weixin://'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _sendSms() async {
    final dest = _to.text.trim();
    final uri = dest.isEmpty
        ? Uri(scheme: 'sms', queryParameters: {'body': _text})
        : Uri(
            scheme: 'sms',
            path: dest,
            queryParameters: {'body': _text},
          );
    await _open(uri, 'SMS');
  }

  Future<void> _sendMail() async {
    final dest = _to.text.trim();
    final uri = Uri(
      scheme: 'mailto',
      path: dest,
      queryParameters: {
        'subject': _subject.text.trim(),
        'body': _body.text.trim(),
      },
    );
    await _open(uri, S.of(context).mail);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.inviteFriends),
        actions: [
          IconButton(
            tooltip: s.copy,
            onPressed: _copy,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _to,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: s.inviteTo,
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: InputDecoration(
              labelText: s.subject,
              prefixIcon: const Icon(Icons.subject),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              labelText: s.body,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.inviteChannelHint,
            style: const TextStyle(color: AppTheme.steel, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _sendMail,
            icon: const Icon(Icons.email_outlined),
            label: Text(s.sendMail),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sendSms,
            icon: const Icon(Icons.sms_outlined),
            label: Text(s.sendSms),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sendLine,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(s.sendLine),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sendWeChat,
            icon: const Icon(Icons.forum_outlined),
            label: Text(s.sendWeChat),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _shareSheet,
            icon: const Icon(Icons.ios_share),
            label: Text(s.shareOther),
          ),
        ],
      ),
    );
  }
}
