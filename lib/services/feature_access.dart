import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/locale_controller.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../screens/account/account_screen.dart';

/// 機能制限は撤廃。図面アップロード回数のみ別途チェック。
class FeatureAccess {
  FeatureAccess._();

  static bool hasFullAccess(AppUser? user, [DateTime? now]) =>
      user?.activated == true;

  static Future<bool> requireFullAccess(BuildContext context) async {
    final user = context.read<AppState>().user;
    if (hasFullAccess(user)) return true;
    if (!context.mounted) return false;
    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.notLoggedIn)),
    );
    return false;
  }

  static Future<bool> requireUploadSlot(BuildContext context) async {
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) return false;
    if (user.canUploadDrawing) return true;
    if (!context.mounted) return false;
    final s = S.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.uploadLimitTitle),
        content: Text(s.uploadLimitMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.close),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.goAccount),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );
    }
    return false;
  }
}
