import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';

/// キーボード表示中／入力フォーカス中に「完了」を出し、閉じる。
///
/// iOS の数字パッドには確定キーがないため、入力は [DoneKeyboard.decimal] /
/// [DoneKeyboard.integer]（通常キーボード＋完了）を使う。
class KeyboardDoneScope extends StatefulWidget {
  const KeyboardDoneScope({super.key, required this.child});

  final Widget child;

  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  State<KeyboardDoneScope> createState() => _KeyboardDoneScopeState();
}

class _KeyboardDoneScopeState extends State<KeyboardDoneScope> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final next = _isEditingFocus(FocusManager.instance.primaryFocus);
    if (next != _editing && mounted) {
      setState(() => _editing = next);
    }
  }

  static bool _isEditingFocus(FocusNode? node) {
    if (node == null || !node.hasFocus) return false;
    final ctx = node.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    // バーを Column で出して ListView 高さが変わると、iOS の端バウンドが止まらなくなる
    final open = _editing;
    return Stack(
      children: [
        widget.child,
        if (open)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 6,
              color: const Color(0xFFEEF1F5),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: KeyboardDoneScope.dismiss,
                      child: Text(
                        S.of(context).done,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 入力確定（完了キー）でキーボードを閉じる共通設定。
///
/// 数字入力は [decimal] / [integer] を使い、通常キーボードの「完了」で閉じる。
class DoneKeyboard {
  DoneKeyboard._();

  static const action = TextInputAction.done;

  static void onSubmitted([String? _]) => KeyboardDoneScope.dismiss();

  /// 小数対応の通常キーボード（完了キーあり）
  static const TextInputType decimal = TextInputType.text;

  /// 整数の通常キーボード（完了キーあり）
  static const TextInputType integer = TextInputType.text;

  static final List<TextInputFormatter> decimalFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  ];

  static final List<TextInputFormatter> integerFormatters = [
    FilteringTextInputFormatter.digitsOnly,
  ];
}
