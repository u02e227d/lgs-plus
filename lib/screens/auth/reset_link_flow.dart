import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import 'verify_email_screen.dart';

Future<void> showResetLinkSentAndOpen({
  required BuildContext context,
  required String email,
}) async {
  final s = S.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.sentTitle),
      content: Text(s.resetSentEmail),
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
      builder: (_) => VerifyEmailScreen(
        email: email,
        isPasswordReset: true,
      ),
    ),
  );
}
