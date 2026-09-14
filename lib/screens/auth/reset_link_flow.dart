import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import 'activate_screen.dart';

enum PasswordResetChannel { email, sms }

Future<void> showResetLinkSentAndOpen({
  required BuildContext context,
  required AppUser user,
  required PasswordResetChannel channel,
  String? extraMessage,
}) async {
  final s = S.of(context);
  final sent = channel == PasswordResetChannel.email
      ? s.resetSentEmail
      : s.resetSentSms;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.sentTitle),
      content: Text(
        [
          if (extraMessage != null && extraMessage.isNotEmpty) extraMessage,
          sent,
          s.resetSentDemo,
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.ok),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ActivateScreen(
        initialEmail: user.email,
        isPasswordReset: true,
      ),
    ),
  );
}
