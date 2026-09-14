import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/s_measure.dart';
import '../theme/app_theme.dart';

/// 誤操作防止：ロック中はスクロール不可。解錠ボタンで操作可能に。
class LockableWheel extends StatefulWidget {
  const LockableWheel({
    super.key,
    required this.label,
    required this.child,
    this.height = 100,
    this.initiallyLocked = true,
  });

  final String label;
  final Widget child;
  final double height;
  final bool initiallyLocked;

  @override
  State<LockableWheel> createState() => _LockableWheelState();
}

class _LockableWheelState extends State<LockableWheel> {
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = widget.initiallyLocked;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.steel,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _locked = !_locked),
              icon: Icon(
                _locked ? Icons.lock : Icons.lock_open,
                size: 18,
                color: _locked ? AppTheme.steel : AppTheme.navy,
              ),
              label: Text(
                _locked ? Ms.of(context).locked : Ms.of(context).unlocked,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _locked ? AppTheme.steel : AppTheme.navy,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _locked ? const Color(0xFFB0B7C3) : const Color(0xFFD0D5DD),
            ),
          ),
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: _locked,
                child: widget.child,
              ),
              if (_locked)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text(Ms.of(context).unlockFirst),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 文字列／数値などの縦スクロール＋ロック。
/// スクロール中に親 setState されてもコントローラを維持し、再マウントしない。
class LockableCupertinoPicker extends StatefulWidget {
  const LockableCupertinoPicker({
    super.key,
    required this.label,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 100,
    this.itemExtent = 36,
    this.liveUpdate = true,
  });

  final String label;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final double itemExtent;
  /// false のとき選択はスクロール停止時のみ通知（品名などモード切替用）
  final bool liveUpdate;

  @override
  State<LockableCupertinoPicker> createState() =>
      _LockableCupertinoPickerState();
}

class _LockableCupertinoPickerState extends State<LockableCupertinoPicker> {
  late FixedExtentScrollController _controller;
  late int _lastIndex;
  String _labelsSig = '';
  bool _scrolling = false;
  /// onSelected → 親 setState → didUpdate のエコーで jump しない
  bool _ignoreExternalJump = false;

  int _clampIndex(int i) {
    if (widget.labels.isEmpty) return 0;
    return i.clamp(0, widget.labels.length - 1);
  }

  String _sigOf(List<String> labels) => labels.join('\u0001');

  @override
  void initState() {
    super.initState();
    _lastIndex = _clampIndex(widget.selectedIndex);
    _labelsSig = _sigOf(widget.labels);
    _controller = FixedExtentScrollController(initialItem: _lastIndex);
  }

  @override
  void didUpdateWidget(covariant LockableCupertinoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSig = _sigOf(widget.labels);
    final nextIdx = _clampIndex(widget.selectedIndex);

    // 選択肢セットが変わったときだけ作り直す
    if (nextSig != _labelsSig) {
      _labelsSig = nextSig;
      _lastIndex = nextIdx;
      _controller.dispose();
      _controller = FixedExtentScrollController(initialItem: _lastIndex);
      return;
    }

    // スクロール中／自発通知直後は親の古い selectedIndex で引き戻さない
    if (_scrolling || _ignoreExternalJump) return;

    // 外部から選択が変わったときだけ jump
    if (nextIdx != _lastIndex) {
      _lastIndex = nextIdx;
      if (_controller.hasClients && _controller.selectedItem != nextIdx) {
        _controller.jumpToItem(nextIdx);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(int i) {
    final idx = _clampIndex(i);
    _lastIndex = idx;
    _ignoreExternalJump = true;
    widget.onSelected(idx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ignoreExternalJump = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LockableWheel(
      label: widget.label,
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
            _scrolling = true;
          }
          if (n is ScrollEndNotification) {
            _scrolling = false;
            _emit(_lastIndex);
          }
          // ListView へのバブリングを止め、親子スクロール競合を減らす
          return true;
        },
        child: CupertinoPicker(
          backgroundColor: Colors.white,
          itemExtent: widget.itemExtent,
          scrollController: _controller,
          diameterRatio: 1.2,
          squeeze: 1.0,
          useMagnifier: true,
          magnification: 1.08,
          onSelectedItemChanged: (i) {
            // スクロール開始通知より先に来ることもある
            _scrolling = true;
            _lastIndex = _clampIndex(i);
            if (widget.liveUpdate) {
              _emit(_lastIndex);
            }
          },
          children: [
            for (final t in widget.labels)
              Center(
                child: Text(
                  t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
