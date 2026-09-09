import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';

class CeilingParamsResult {
  CeilingParamsResult({required this.method});
  final CeilingMethod method;
}

class CeilingParamsSheet extends StatefulWidget {
  const CeilingParamsSheet({super.key});

  @override
  State<CeilingParamsSheet> createState() => _CeilingParamsSheetState();
}

class _CeilingParamsSheetState extends State<CeilingParamsSheet> {
  double noen = 303;
  double uke = 910;
  BoardSize boardSize = BoardSize.size36;
  BoardLayers layers = BoardLayers.single;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
                '天井工法選択',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('野縁ピッチ', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                children: [
                  for (final v in [303.0, 455.0])
                    ChoiceChip(
                      label: Text('@${v.toInt()}'),
                      selected: noen == v,
                      onSelected: (_) => setState(() => noen = v),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('野縁受けピッチ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                children: [
                  for (final v in [910.0, 1000.0])
                    ChoiceChip(
                      label: Text('@${v.toInt()}'),
                      selected: uke == v,
                      onSelected: (_) => setState(() => uke = v),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('天井石膏ボード',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final s in BoardSize.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: boardSize == s,
                      onSelected: (_) => setState(() => boardSize = s),
                    ),
                  ChoiceChip(
                    label: const Text('1層'),
                    selected: layers == BoardLayers.single,
                    onSelected: (_) =>
                        setState(() => layers = BoardLayers.single),
                  ),
                  ChoiceChip(
                    label: const Text('2層'),
                    selected: layers == BoardLayers.double,
                    onSelected: (_) =>
                        setState(() => layers = BoardLayers.double),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '確定後、ツールバーの回転ボタンで骨格グリッドを90°回転できます。',
                style: TextStyle(fontSize: 12, color: AppTheme.steel),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    CeilingParamsResult(
                      method: CeilingMethod(
                        noenSpacingMm: noen,
                        noenuKeSpacingMm: uke,
                        boardSize: boardSize,
                        layers: layers,
                      ),
                    ),
                  );
                },
                child: const Text('確定して算量'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(color: AppTheme.steel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
