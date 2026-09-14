import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../l10n/s_measure.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'keyboard_done.dart';
import 'lockable_picker.dart';

/// 「＋」で別寸法を1件だけ入力する浮き確認。確定後に本リストへ載せる。
Future<ExtraSizedItem?> showExtraSizeDialog({
  required BuildContext context,
  required String title,
  required ExtraSizedItem initial,
  List<double> widths = const [],
  List<double> lengths = const [],
  List<String> codes = const [],
  bool showName = false,
  String widthLabel = '寸法',
  String lengthLabel = '定尺',
  String codeLabel = '種類',
}) {
  return showDialog<ExtraSizedItem>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _ExtraSizeDialog(
      title: title,
      initial: initial,
      widths: widths,
      lengths: lengths,
      codes: codes,
      showName: showName,
      widthLabel: widthLabel,
      lengthLabel: lengthLabel,
      codeLabel: codeLabel,
    ),
  );
}

class _ExtraSizeDialog extends StatefulWidget {
  const _ExtraSizeDialog({
    required this.title,
    required this.initial,
    required this.widths,
    required this.lengths,
    required this.codes,
    required this.showName,
    required this.widthLabel,
    required this.lengthLabel,
    required this.codeLabel,
  });

  final String title;
  final ExtraSizedItem initial;
  final List<double> widths;
  final List<double> lengths;
  final List<String> codes;
  final bool showName;
  final String widthLabel;
  final String lengthLabel;
  final String codeLabel;

  @override
  State<_ExtraSizeDialog> createState() => _ExtraSizeDialogState();
}

class _ExtraSizeDialogState extends State<_ExtraSizeDialog> {
  late double _widthMm;
  late double _lengthMm;
  late String _code;
  late final TextEditingController _qty;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _widthMm = _pickWidth(widget.initial.widthMm);
    _lengthMm = _pickLength(widget.initial.lengthMm);
    _code = _pickCode(widget.initial.code);
    final q = widget.initial.qty <= 0 ? 1.0 : widget.initial.qty;
    _qty = TextEditingController(
      text: q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString(),
    );
    _name = TextEditingController(text: widget.initial.code);
  }

  @override
  void dispose() {
    _qty.dispose();
    _name.dispose();
    super.dispose();
  }

  double _pickWidth(double v) {
    if (widget.widths.isEmpty) return v;
    if (widget.widths.contains(v)) return v;
    return widget.widths.first;
  }

  double _pickLength(double v) {
    if (widget.lengths.isEmpty) return v > 0 ? v : 0;
    if (widget.lengths.contains(v)) return v;
    return widget.lengths.first;
  }

  String _pickCode(String v) {
    if (widget.codes.isEmpty) return v;
    if (widget.codes.contains(v)) return v;
    return widget.codes.first;
  }

  ExtraSizedItem _toItem() {
    final name = _name.text.trim();
    return ExtraSizedItem(
      kind: widget.initial.kind,
      widthMm: _widthMm,
      lengthMm: _lengthMm,
      qty: double.tryParse(_qty.text.trim()) ?? 0,
      unit: widget.initial.unit,
      code: widget.showName ? name : _code,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: KeyboardDoneScope(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Ms.of(context).extraSizeHint,
                  style: const TextStyle(fontSize: 13, color: AppTheme.steel),
                ),
                const SizedBox(height: 12),
                if (widget.showName) ...[
                  TextField(
                    controller: _name,
                    textInputAction: DoneKeyboard.action,
                    onSubmitted: DoneKeyboard.onSubmitted,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: Ms.of(context).extraNameCode,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.codes.isNotEmpty)
                  LockableCupertinoPicker(
                    label: widget.codeLabel,
                    labels: widget.codes,
                    selectedIndex: widget.codes
                        .indexOf(_code)
                        .clamp(0, widget.codes.length - 1),
                    height: 96,
                    liveUpdate: false,
                    onSelected: (i) => setState(() => _code = widget.codes[i]),
                  ),
                if (widget.widths.isNotEmpty) ...[
                  if (widget.codes.isNotEmpty) const SizedBox(height: 8),
                  LockableCupertinoPicker(
                    label: widget.widthLabel,
                    labels: [
                      for (final w in widget.widths) '${w.round()}mm',
                    ],
                    selectedIndex: widget.widths
                        .indexOf(_widthMm)
                        .clamp(0, widget.widths.length - 1),
                    height: 96,
                    liveUpdate: false,
                    onSelected: (i) =>
                        setState(() => _widthMm = widget.widths[i]),
                  ),
                ],
                if (widget.lengths.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LockableCupertinoPicker(
                    label: widget.lengthLabel,
                    labels: [
                      for (final L in widget.lengths) '${L.round()}mm',
                    ],
                    selectedIndex: widget.lengths
                        .indexOf(_lengthMm)
                        .clamp(0, widget.lengths.length - 1),
                    height: 96,
                    liveUpdate: false,
                    onSelected: (i) =>
                        setState(() => _lengthMm = widget.lengths[i]),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _qty,
                  keyboardType: DoneKeyboard.decimal,
                  inputFormatters: DoneKeyboard.decimalFormatters,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: Ms.of(context).qtyWithUnit(widget.initial.unit),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of(context).cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _toItem()),
          child: Text(Ms.of(context).confirm),
        ),
      ],
    );
  }
}
