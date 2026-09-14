import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../theme/app_theme.dart';
import '../../widgets/measure_painters.dart';

enum IronPlateMeasureAction { proceed, delete }

/// 鉄板線（T）タップ後：測定長さの確認／削除。石膏ボード・クロスは出さない。
class IronPlateMeasureSheet extends StatelessWidget {
  const IronPlateMeasureSheet({
    super.key,
    required this.lengthMm,
  });

  final double lengthMm;

  @override
  Widget build(BuildContext context) {
    final label = lengthMm > 0 ? distanceLabelText(lengthMm) : '—';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              Ms.of(context).ironMeasure,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF59D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBC02D), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    Ms.of(context).ironTLength,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.steel,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, IronPlateMeasureAction.proceed),
              child: Text(Ms.of(context).goMaterials),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _confirmDelete(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger),
              ),
              child: Text(Ms.of(context).deleteThisLine),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                S.of(context).cancel,
                style: const TextStyle(color: AppTheme.steel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).deleteThisLine),
        content: Text(Ms.of(ctx).deleteThisLineQ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(S.of(ctx).deleteAction),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.pop(context, IronPlateMeasureAction.delete);
    }
  }
}
