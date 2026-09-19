import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../services/app_platform.dart';
import '../theme/app_theme.dart';

/// デスクトップ：右クリック／二本指クリックで削除確認を出す共通処理
class MacListDelete {
  MacListDelete._();

  static bool get isMac => AppPlatform.usesDesktopPointer;

  /// ボトムシート＋確認ダイアログ（左スワイプと同じ流れ）
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String body,
    String? sheetActionLabel,
  }) async {
    final s = S.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.danger,
              ),
              title: Text(sheetActionLabel ?? s.delete),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.cancel),
              onTap: () => Navigator.pop(ctx, 'cancel'),
            ),
          ],
        ),
      ),
    );
    if (action != 'delete') return false;
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirmDelete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// ダイアログのみ（注文書履历など既存がダイアログのみの場合）
  static Future<bool> confirmDialogOnly({
    required BuildContext context,
    required String title,
    required String body,
  }) async {
    final s = S.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Mac のみ secondary tap を付与
  static Widget wrap({
    required Widget child,
    required Future<void> Function() onDelete,
  }) {
    if (!isMac) return child;
    return GestureDetector(
      onSecondaryTap: () async {
        await onDelete();
      },
      child: child,
    );
  }
}
