import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/locale_controller.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../screens/account/account_screen.dart';

/// 無料：図面アップロード・スケール・測定のみ
/// 有料／特典期間：試算表・材料・注文を含む全機能
class FeatureAccess {
  FeatureAccess._();

  static const upgradeTitle = '有料・特典の機能です';
  static const upgradeMessage =
      '無料版で使えるのは、図面のアップロード、スケール設定、図面測定だけです。\n\n'
      '材料選択・試算表・注文書は、有料プランまたは招待特典の期限内でご利用ください。';

  static bool hasFullAccess(AppUser? user, [DateTime? now]) =>
      user?.hasFullAccess(now) ?? false;

  static Future<bool> requireFullAccess(BuildContext context) async {
    final user = context.read<AppState>().user;
    if (hasFullAccess(user)) return true;
    if (!context.mounted) return false;
    final s = S.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.upgradeTitle),
        content: Text(s.upgradeMessage),
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
