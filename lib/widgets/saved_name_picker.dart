import 'package:flutter/material.dart';

import '../l10n/s_measure.dart';
import '../services/saved_name_catalog.dart';
import '../theme/app_theme.dart';
import 'keyboard_done.dart';
import 'lockable_picker.dart';

const kCustomNameLabel = 'カスタム入力';

/// 品名：カスタム入力＋プリセット＋保存済み。入力で自動保存、左スワイプで削除。
class SavedNamePicker extends StatefulWidget {
  const SavedNamePicker({
    super.key,
    required this.label,
    required this.prefsKey,
    required this.value,
    required this.onChanged,
    this.presets = const [],
    this.height = 110,
  });

  final String label;
  final String prefsKey;
  final String value;
  final ValueChanged<String> onChanged;
  /// 固定プリセット（カスタム入力は先頭に自動追加）
  final List<String> presets;
  final double height;

  @override
  State<SavedNamePicker> createState() => _SavedNamePickerState();
}

class _SavedNamePickerState extends State<SavedNamePicker> {
  late final TextEditingController _custom;
  List<String> _saved = [];
  bool _customMode = true;
  /// ホイール選択のローカル正（親 value 更新前の引き戻し防止）
  String _picked = '';

  List<String> get _labels => [
        kCustomNameLabel,
        ...widget.presets,
        ..._saved.where((e) => !widget.presets.contains(e)),
      ];

  @override
  void initState() {
    super.initState();
    _custom = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final saved = await SavedNameCatalog.load(widget.prefsKey);
    if (!mounted) return;
    final v = widget.value.trim();
    final inPreset = widget.presets.contains(v);
    final inSaved = saved.contains(v);
    setState(() {
      _saved = saved;
      if (v.isEmpty) {
        _customMode = true;
        _picked = '';
        _custom.clear();
      } else if (inPreset || inSaved) {
        _customMode = false;
        _picked = v;
        _custom.text = v;
      } else {
        _customMode = true;
        _picked = '';
        _custom.text = v;
      }
    });
  }

  @override
  void didUpdateWidget(covariant SavedNamePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final v = widget.value.trim();
    // 自分が onChanged した直後のエコーは無視（ホイール引き戻し防止）
    if (v == _picked || (!_customMode && v == _custom.text.trim())) return;
    if (_customMode && v == _custom.text.trim()) return;
    final labels = _labels;
    if (v.isEmpty) {
      _customMode = true;
      _picked = '';
      _custom.clear();
    } else if (labels.contains(v) && v != kCustomNameLabel) {
      _customMode = false;
      _picked = v;
      _custom.text = v;
    } else {
      _customMode = true;
      _picked = '';
      _custom.text = v;
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    if (_customMode) return 0;
    final labels = _labels;
    final name = _picked.isNotEmpty ? _picked : _custom.text.trim();
    final i = labels.indexOf(name);
    return i < 0 ? 0 : i;
  }

  Future<void> _commitCustom() async {
    final n = _custom.text.trim();
    if (n.isEmpty) {
      _picked = '';
      widget.onChanged('');
      return;
    }
    final next = await SavedNameCatalog.add(widget.prefsKey, n);
    if (!mounted) return;
    setState(() {
      _saved = next;
      _customMode = false;
      _picked = n;
      _custom.text = n;
    });
    widget.onChanged(n);
  }

  Future<void> _deleteSaved(String name) async {
    final next = await SavedNameCatalog.remove(widget.prefsKey, name);
    if (!mounted) return;
    setState(() {
      _saved = next;
      if (_picked == name || widget.value.trim() == name) {
        _customMode = true;
        _picked = '';
        _custom.clear();
        widget.onChanged('');
      }
    });
  }

  void _selectLabel(String sel) {
    if (sel == kCustomNameLabel) {
      setState(() {
        _customMode = true;
        _picked = '';
        if (widget.presets.contains(_custom.text) ||
            _saved.contains(_custom.text)) {
          _custom.clear();
        }
      });
      widget.onChanged(_custom.text.trim());
      return;
    }
    setState(() {
      _customMode = false;
      _picked = sel;
      _custom.text = sel;
    });
    widget.onChanged(sel);
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
    final savedOnly = [
      for (final e in _saved)
        if (!widget.presets.contains(e)) e,
    ];
    final selectedName = _customMode ? '' : _picked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LockableCupertinoPicker(
          label: widget.label,
          labels: [
            for (final t in labels)
              t == kCustomNameLabel ? Ms.of(context).customInput : t,
          ],
          selectedIndex: _selectedIndex.clamp(0, labels.length - 1),
          height: widget.height,
          liveUpdate: false,
          onSelected: (i) {
            if (i < 0 || i >= labels.length) return;
            _selectLabel(labels[i]);
          },
        ),
        if (_customMode) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _custom,
            textInputAction: DoneKeyboard.action,
            onSubmitted: (_) => _commitCustom(),
            onEditingComplete: _commitCustom,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              labelText: Ms.of(context).customNameHint,
              hintText: Ms.of(context).customSaveHint,
            ),
            onChanged: (t) {
              _picked = '';
              widget.onChanged(t.trim());
            },
          ),
        ],
        if (savedOnly.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            Ms.of(context).savedSwipeDelete,
            style: const TextStyle(fontSize: 11, color: AppTheme.steel),
          ),
          const SizedBox(height: 4),
          for (final name in savedOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Dismissible(
                key: ValueKey('saved-$name'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Ms.of(context).delete,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onDismissed: (_) => _deleteSaved(name),
                child: Material(
                  color: selectedName == name
                      ? const Color(0xFFE8EEF6)
                      : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontSize: 13)),
                    trailing: selectedName == name
                        ? const Icon(Icons.check, color: AppTheme.navy, size: 18)
                        : null,
                    onTap: () => _selectLabel(name),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
