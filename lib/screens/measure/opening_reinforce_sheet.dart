import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../services/opening_reinforce.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';

class OpeningReinforceResult {
  OpeningReinforceResult({
    required this.pattern,
    required this.material,
    required this.heightMm,
    required this.widthMm,
    required this.magusaSegments,
    this.delete = false,
  });

  OpeningReinforceResult.deleted()
      : pattern = OpeningReinforcePattern.redH,
        material = OpeningMaterialKind.reinforce,
        heightMm = 0,
        widthMm = 0,
        magusaSegments = 1,
        delete = true;

  final OpeningReinforcePattern pattern;
  final OpeningMaterialKind material;
  final double heightMm;
  final double widthMm;
  final int magusaSegments;
  final bool delete;
}

/// 開口補強の新規／再設定
class OpeningReinforceSheet extends StatefulWidget {
  const OpeningReinforceSheet({
    super.key,
    required this.defaultWidthMm,
    this.defaultHeightMm = 2100,
    this.initialPattern,
    this.initialMaterial,
    this.initialMagusaSegments,
    this.allowDelete = false,
    this.stockLengthMm = 3000,
  });

  final double defaultWidthMm;
  final double defaultHeightMm;
  final OpeningReinforcePattern? initialPattern;
  final OpeningMaterialKind? initialMaterial;
  final int? initialMagusaSegments;
  final bool allowDelete;
  /// 補強材定尺（本数目安表示用）
  final double stockLengthMm;

  @override
  State<OpeningReinforceSheet> createState() => _OpeningReinforceSheetState();
}

class _OpeningReinforceSheetState extends State<OpeningReinforceSheet> {
  late OpeningReinforcePattern _pattern;
  late OpeningMaterialKind _material;
  late int _magusa;
  late final TextEditingController _height;
  late final TextEditingController _width;

  @override
  void initState() {
    super.initState();
    _pattern = widget.initialPattern ?? OpeningReinforcePattern.redHOrange;
    _material = widget.initialMaterial ?? OpeningMaterialKind.reinforce;
    _magusa = (widget.initialMagusaSegments ?? 1).clamp(1, 4);
    _height = TextEditingController(
      text: widget.defaultHeightMm.toStringAsFixed(0),
    );
    final w = widget.defaultWidthMm > 0 ? widget.defaultWidthMm : 900.0;
    _width = TextEditingController(text: w.round().toString());
  }

  @override
  void dispose() {
    _height.dispose();
    _width.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(context).openingDeleteTitle),
        content: Text(Ms.of(context).openingDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(S.of(ctx).delete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, OpeningReinforceResult.deleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDoneScope(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.allowDelete
                          ? Ms.of(context).openingReset
                          : Ms.of(context).openingPickShape,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      S.of(context).cancel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _pattern.label,
                style: const TextStyle(color: AppTheme.steel, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: OpeningReinforcePattern.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final p = OpeningReinforcePattern.values[i];
                    return GestureDetector(
                      onTap: () => setState(() => _pattern = p),
                      child: Column(
                        children: [
                          OpeningPatternIcon(
                            pattern: p,
                            selected: _pattern == p,
                            size: 72,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _pattern == p
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                Ms.of(context).materialContent,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in OpeningMaterialKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m.label),
                          selected: _material == m,
                          onSelected: (_) => setState(() => _material = m),
                          selectedColor: AppTheme.safetyYellow,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _height,
                      keyboardType: DoneKeyboard.integer,
                      inputFormatters: DoneKeyboard.integerFormatters,
                      textInputAction: DoneKeyboard.action,
                      onSubmitted: DoneKeyboard.onSubmitted,
                      decoration: InputDecoration(
                        labelText: Ms.of(context).openingH,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _width,
                      keyboardType: DoneKeyboard.integer,
                      inputFormatters: DoneKeyboard.integerFormatters,
                      textInputAction: DoneKeyboard.action,
                      onSubmitted: DoneKeyboard.onSubmitted,
                      decoration: InputDecoration(
                        labelText: Ms.of(context).openingW,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                Ms.of(context).lintelTiers,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var s = 1; s <= 4; s++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(Ms.of(context).nDan(s)),
                          selected: _magusa == s,
                          onSelected: (_) => setState(() => _magusa = s),
                          selectedColor: AppTheme.safetyYellow,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final h = double.tryParse(_height.text.trim()) ?? 2100;
                  final w = double.tryParse(_width.text.trim()) ?? 900;
                  Navigator.pop(
                    context,
                    OpeningReinforceResult(
                      pattern: _pattern,
                      material: _material,
                      heightMm: h,
                      widthMm: w,
                      magusaSegments: _magusa,
                    ),
                  );
                },
                child: Text(widget.allowDelete
                    ? Ms.of(context).update
                    : Ms.of(context).confirm),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              if (widget.allowDelete) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                  child: Text(Ms.of(context).deleteThisOpening),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
