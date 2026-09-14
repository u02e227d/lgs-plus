import 'package:flutter/material.dart';

import '../l10n/s_measure.dart';
import '../theme/app_theme.dart';
import 'measure_painters.dart';

/// 色＋線太さバー
class WallHighlightColorBar extends StatelessWidget {
  const WallHighlightColorBar({
    super.key,
    required this.selectedArgb,
    required this.strokeWidth,
    required this.onSelect,
    required this.onStrokeWidth,
  });

  final int? selectedArgb;
  final double strokeWidth;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onStrokeWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                Ms.of(context).lineColor,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.steel,
                ),
              ),
              const SizedBox(width: 10),
              for (final c in WallHighlightColors.palette) ...[
                GestureDetector(
                  onTap: () => onSelect(c.toARGB32()),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedArgb == c.toARGB32()
                            ? AppTheme.navy
                            : Colors.black26,
                        width: selectedArgb == c.toARGB32() ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                Ms.of(context).strokeW(strokeWidth.toStringAsFixed(0)),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.steel,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                Ms.of(context).strokeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.steel,
                ),
              ),
              Expanded(
                child: Slider(
                  value: strokeWidth.clamp(2, 48),
                  min: 2,
                  max: 48,
                  divisions: 46,
                  label: strokeWidth.toStringAsFixed(0),
                  activeColor: AppTheme.navy,
                  onChanged: onStrokeWidth,
                ),
              ),
            ],
          ),
          Text(
            Ms.of(context).triadHint,
            style: const TextStyle(fontSize: 11, color: AppTheme.steel),
          ),
        ],
      ),
    );
  }
}
