import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/opening_reinforce.dart';
import '../../theme/app_theme.dart';

class OpeningReinforceResult {
  OpeningReinforceResult({
    required this.pattern,
    required this.material,
    required this.heightMm,
    required this.widthMm,
    required this.magusaSegments,
  });

  final OpeningReinforcePattern pattern;
  final OpeningMaterialKind material;
  final double heightMm;
  final double widthMm;
  final int magusaSegments;
}

/// 2点確定後：7種グラフィック＋材料・寸法
class OpeningReinforceSheet extends StatefulWidget {
  const OpeningReinforceSheet({
    super.key,
    required this.defaultWidthMm,
    this.defaultHeightMm = 2100,
  });

  final double defaultWidthMm;
  final double defaultHeightMm;

  @override
  State<OpeningReinforceSheet> createState() => _OpeningReinforceSheetState();
}

class _OpeningReinforceSheetState extends State<OpeningReinforceSheet> {
  OpeningReinforcePattern _pattern = OpeningReinforcePattern.redOrange;
  OpeningMaterialKind _material = OpeningMaterialKind.reinforce;
  int _magusa = 1;
  late final TextEditingController _height;
  late final TextEditingController _width;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
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
              const Text(
                '開口補強 — 形状選択',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
              const Text(
                '材料内容',
                style: TextStyle(fontWeight: FontWeight.w800),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '開口高さ (mm)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _width,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '開口幅 (mm)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'まぐさ段数',
                style: TextStyle(fontWeight: FontWeight.w800),
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
                          label: Text('$s段'),
                          selected: _magusa == s,
                          onSelected: (_) => setState(() => _magusa = s),
                          selectedColor: AppTheme.safetyYellow,
                        ),
                      ),
                  ],
                ),
              ),
              if (_material == OpeningMaterialKind.reinforce) ...[
                const SizedBox(height: 10),
                Text(
                  '補強材：縦線${_pattern.verticalLines}本＋横線'
                  '${_pattern.horizontalLines(_magusa)}本（定尺割付）',
                  style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
              ],
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
                child: const Text('確定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
