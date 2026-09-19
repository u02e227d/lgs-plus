import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../services/calc_engine.dart';
import '../../services/ceiling_layout.dart';
import '../../theme/app_theme.dart';
import '../../widgets/extra_size_dialog.dart';
import '../../widgets/keyboard_done.dart';
import '../../widgets/lockable_picker.dart';
import '../../widgets/saved_name_picker.dart';
import '../../services/saved_name_catalog.dart';

enum CeilingMaterialAction { save, estimate }

const _kOtherNameCustom = 'カスタム入力';
const _kOtherNamePresets = [
  _kOtherNameCustom,
  'Gブレース',
  'チャンネルホルダー',
  'Eデッキ金具',
  'QLデッキ金具（トンボ）',
  'LGフック',
  'H-Cフック',
  '高ナット',
];

const _kOtherNamePresetsFixed = [
  'Gブレース',
  'チャンネルホルダー',
  'Eデッキ金具',
  'QLデッキ金具（トンボ）',
  'LGフック',
  'H-Cフック',
  '高ナット',
];

const _kBoardNameCustom = 'カスタム入力';
const _kBoardNames = [
  _kBoardNameCustom,
  'ケイカルVカット',
  'ケイカル平',
  'タイガーボード',
  'タイガー防水ボード',
  'タイガー不燃防水ボード',
  'ソーラトン平板',
  'ソーラトン・スカット',
  'ソーラトン キューブ',
  'ソーラトンライト・ワイド',
  'ダイケトン',
  'タイガージプトーン・ライト',
  'タイガースクエアート',
  'タイガーマーブルトーン・ライト',
  'タイガーハイクリンジプトーン・ライト',
  'タイガーハイクリンマーブルトーン・ライト',
  'タイガーステラート・ライト',
  '防カビジプトーン',
  'タイガージプトーン・ウルトラライト',
  'タイガースクエアトーン・Dプラス',
  '不燃ニュータイガートーン',
];

/// 天井ボードサイズ（表示ラベルと mm）
const _kBoardSizeOpts = <(String label, double wMm, double hMm)>[
  ('300mm×600mm', 300, 600),
  ('455mm×910mm', 455, 910),
  ('3×3', 910, 910),
  ('2×6', 606, 1820),
  ('3×6', 910, 1820),
  ('3×8', 910, 2420),
  ('3×9', 910, 2730),
];

const _kBoardThicknesses = [
  4.0,
  5.0,
  6.0,
  8.0,
  9.0,
  9.5,
  10.0,
  12.0,
  12.5,
  15.0,
  21.0,
];

const _kBoardOtherNamePresetsFixed = [
  'ビス',
  'ステープル',
  '速乾ボンド',
  'サクビボンド',
  'サウンドカット',
];

const _kBoardOtherNamePresets = [
  _kOtherNameCustom,
  ..._kBoardOtherNamePresetsFixed,
];

class CeilingMaterialResult {
  CeilingMaterialResult({
    required this.method,
    required this.action,
  });
  final CeilingMethod method;
  final CeilingMaterialAction action;
}

/// 天井材料設定（面積・SQ角スタッド・クリップ・全ネジ・ナット・ハンガー・野縁受け）
class CeilingMaterialSheet extends StatefulWidget {
  const CeilingMaterialSheet({
    super.key,
    required this.ceilings,
    required this.scalePxPerMm,
    this.ceilingNumber = 1,
    this.initialMethod,
  });

  final List<CeilingRegion> ceilings;
  final double scalePxPerMm;
  final int ceilingNumber;
  final CeilingMethod? initialMethod;

  @override
  State<CeilingMaterialSheet> createState() => _CeilingMaterialSheetState();
}

class _CeilingMaterialSheetState extends State<CeilingMaterialSheet> {
  static const _sqTypes = [
    '4020',
    '4025',
    '4045',
    '4050',
    '4565',
    '45100',
  ];
  static const _clipTypesFull = [
    '4020',
    '4025',
    '4040',
    '4045',
    '4540',
    '4050',
    '5040',
    '6545',
    '4565',
    '45100',
  ];
  static const _clipTypesNarrow = [
    '4020',
    '4025',
    '4040',
    '4045',
    '4540',
    '4050',
    '5040',
  ];
  static const _clipUkeLabels = ['C19', 'C25', 'C38'];
  static const _stockPresets = [3000.0, 4000.0, 5000.0];
  static const _runnerWidths = [
    20.0,
    25.0,
    38.0,
    40.0,
    45.0,
    50.0,
    65.0,
    75.0,
    90.0,
    100.0,
  ];
  static const _runnerLengthPresets = [3000.0, 4000.0];
  static const _boltWidths = ['W3/8', 'W1/2'];
  static const _boltLengthPresets = [
    300.0,
    500.0,
    600.0,
    700.0,
    800.0,
    900.0,
    1000.0,
    1500.0,
    2000.0,
    2500.0,
    3000.0,
  ];
  static const _ukeWidths = [19.0, 25.0, 38.0, 40.0];
  static const _barHeights = [19.0, 25.0];
  static const _channelJointWidths = [38.0, 40.0];
  static const _clipUkeWidths = [19.0, 25.0, 38.0, 40.0];
  static const _hangerHeights = [50.0, 99.0, 150.0];

  late String _sqType;
  late TextEditingController _sqLen;
  late String _clipUke;
  late String _clipType;
  late double _runnerWidth;
  late TextEditingController _runnerLen;
  late String _boltWidth;
  late TextEditingController _boltLen;
  late TextEditingController _nut;
  late TextEditingController _hanger;
  late String _hangerBolt;
  late double _hangerUke;
  late double _hangerHeight;
  late double _ukeWidth;
  late TextEditingController _ukeLen;
  late double _channelJointWidth;
  late double _wBarHeight;
  late TextEditingController _wBarLen;
  late double _singleBarHeight;
  late TextEditingController _singleBarLen;
  late double _wClipUkeWidth;
  late double _singleClipUkeWidth;
  late double _wBarJointHeight;
  late double _singleBarJointHeight;
  final List<_OtherRowState> _otherRows = [];
  final List<_OtherRowState> _boardOtherRows = [];
  final List<_FinishBoardLayerState> _boardLayers = [];
  final List<_ExtraSizeRow> _extraRows = [];
  late bool _mikiriEnabled;
  late TextEditingController _mikiriName;
  late TextEditingController _mikiriLen;
  bool _nutManual = false;
  bool _hangerManual = false;
  bool _mismatchDialogBusy = false;

  List<String> get _clipTypeOptions =>
      (_clipUke == 'C19' || _clipUke == 'C25')
          ? _clipTypesNarrow
          : _clipTypesFull;

  /// 工法：SQ / 在来（材料欄の表示切替）
  bool get _isSq {
    final m = widget.initialMethod ??
        (widget.ceilings.isNotEmpty ? widget.ceilings.first.method : null);
    return (m?.systemKind ?? CeilingSystemKind.sq) == CeilingSystemKind.sq;
  }

  bool get _isZairai => !_isSq;

  Future<bool> _confirmSizeMismatch() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(Ms.of(ctx).dimConfirm),
        content: Text(Ms.of(ctx).dimMismatch),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Ms.of(ctx).confirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  double _runnerWidthForBar(double barMm) => barMm == 19 ? 20 : barMm;

  bool _runnerMatchesBar(double runnerMm, double barMm) {
    if (runnerMm == barMm) return true;
    return barMm == 19 && runnerMm == 20;
  }

  void _syncFromWBar(double h) {
    _wBarHeight = h;
    _wBarJointHeight = h;
    _singleBarHeight = h;
    _singleBarJointHeight = h;
    final runner = _runnerWidthForBar(h);
    if (_runnerWidths.contains(runner)) _runnerWidth = runner;
  }

  void _syncFromChannel(double w) {
    _ukeWidth = w;
    if (_channelJointWidths.contains(w)) _channelJointWidth = w;
    if (_clipUkeWidths.contains(w)) {
      _wClipUkeWidth = w;
      _singleClipUkeWidth = w;
    }
    if (_ukeWidths.contains(w)) _hangerUke = w;
  }

  Future<void> _pickOrConfirm({
    required double current,
    required double next,
    required double matchTo,
    required void Function() apply,
    bool runnerBarPair = false,
  }) async {
    if (next == current) return;
    final matched = runnerBarPair
        ? _runnerMatchesBar(next, matchTo)
        : next == matchTo;
    if (!matched) {
      if (_mismatchDialogBusy) {
        if (mounted) setState(() {});
        return;
      }
      _mismatchDialogBusy = true;
      try {
        final ok = await _confirmSizeMismatch();
        if (!ok || !mounted) {
          setState(() {});
          return;
        }
      } finally {
        _mismatchDialogBusy = false;
      }
    }
    if (!mounted) return;
    setState(apply);
  }

  @override
  void initState() {
    super.initState();
    final m = widget.initialMethod ??
        (widget.ceilings.isNotEmpty
            ? widget.ceilings.first.method
            : const CeilingMethod());
    _sqType = _sqTypes.contains(m.sqStudType) ? m.sqStudType : '4045';
    // 図面から角スタッド実測長を算出し、長さ欄の初期値にする
    final measured = _computeMeasuredSqLengthsMm();
    final initialSqLen = measured.isNotEmpty
        ? measured.last // 最長（定尺選定の基準）
        : (m.sqStudLengthMm > 0 ? m.sqStudLengthMm : 4000.0);
    _sqLen = TextEditingController(text: initialSqLen.round().toString());
    _clipUke = _clipUkeLabels.contains(m.clipUkeLabel) ? m.clipUkeLabel : 'C38';
    final clipOpts = (_clipUke == 'C19' || _clipUke == 'C25')
        ? _clipTypesNarrow
        : _clipTypesFull;
    _clipType = clipOpts.contains(m.clipType) ? m.clipType : clipOpts.first;
    _singleBarHeight = _barHeights.contains(m.singleBarHeightMm)
        ? m.singleBarHeightMm
        : 19;
    // 在来：ランナー幅の既定はシングルバー高さに合わせる（旧既定45は未設定扱い）
    final isZairaiInit = m.systemKind == CeilingSystemKind.zairai;
    if (isZairaiInit) {
      if (_runnerWidths.contains(m.runnerWidthMm) && m.runnerWidthMm != 45) {
        _runnerWidth = m.runnerWidthMm;
      } else {
        _runnerWidth = _runnerWidthForBar(_singleBarHeight);
        if (!_runnerWidths.contains(_runnerWidth)) {
          _runnerWidth = 20;
        }
      }
    } else {
      _runnerWidth = m.runnerWidthMm == 19
          ? 20
          : (_runnerWidths.contains(m.runnerWidthMm) ? m.runnerWidthMm : 45);
    }
    _runnerLen = TextEditingController(
      text: (m.runnerLengthMm > 0 ? m.runnerLengthMm : 4000).round().toString(),
    );
    _boltWidth = _boltWidths.contains(m.boltWidthLabel)
        ? m.boltWidthLabel
        : 'W3/8';
    _boltLen = TextEditingController(
      text: (m.boltLengthMm > 0 ? m.boltLengthMm : 1000).round().toString(),
    );
    _ukeWidth = _ukeWidths.contains(m.ukeChannelWidthMm)
        ? m.ukeChannelWidthMm
        : 38;
    _ukeLen = TextEditingController(
      text: (m.ukeChannelLengthMm > 0 ? m.ukeChannelLengthMm : 4000)
          .round()
          .toString(),
    );
    _channelJointWidth = _channelJointWidths.contains(m.channelJointWidthMm)
        ? m.channelJointWidthMm
        : 38;
    _wBarHeight =
        _barHeights.contains(m.wBarHeightMm) ? m.wBarHeightMm : 19;
    _wBarLen = TextEditingController(
      text: (m.wBarLengthMm > 0 ? m.wBarLengthMm : 4000).round().toString(),
    );
    _singleBarLen = TextEditingController(
      text: (m.singleBarLengthMm > 0 ? m.singleBarLengthMm : 4000)
          .round()
          .toString(),
    );
    _wClipUkeWidth = _clipUkeWidths.contains(m.wClipUkeWidthMm)
        ? m.wClipUkeWidthMm
        : 38;
    _singleClipUkeWidth = _clipUkeWidths.contains(m.singleClipUkeWidthMm)
        ? m.singleClipUkeWidthMm
        : 38;
    _wBarJointHeight = _barHeights.contains(m.wBarJointHeightMm)
        ? m.wBarJointHeightMm
        : _wBarHeight;
    _singleBarJointHeight = _barHeights.contains(m.singleBarJointHeightMm)
        ? m.singleBarJointHeightMm
        : _singleBarHeight;
    _hangerBolt = _boltWidths.contains(m.hangerBoltWidthLabel)
        ? m.hangerBoltWidthLabel
        : _boltWidth;
    _hangerUke = _ukeWidths.contains(m.hangerUkeWidthMm)
        ? m.hangerUkeWidthMm
        : _ukeWidth;
    _hangerHeight = _hangerHeights.contains(m.hangerFixtureHeightMm)
        ? m.hangerFixtureHeightMm
        : 99;
    final bolts = _boltCount;
    _nutManual = m.nutCountOverride != null;
    _hangerManual = m.hangerCountOverride != null;
    _nut = TextEditingController(
      text: (m.nutCountOverride ?? bolts * 2).round().toString(),
    );
    _hanger = TextEditingController(
      text: (m.hangerCountOverride ?? bolts).round().toString(),
    );
    if (m.otherItems.isEmpty) {
      _otherRows.add(_OtherRowState());
    } else {
      for (final item in m.otherItems) {
        final migrated = item.name == 'チャンネルホルタ'
            ? item.copyWith(name: 'チャンネルホルダー')
            : item;
        _otherRows.add(_OtherRowState.fromItem(migrated));
      }
    }
    final layers = m.finishBoardLayers.isNotEmpty
        ? m.finishBoardLayers
        : const [CeilingFinishBoardLayer()];
    for (final layer in layers) {
      _boardLayers.add(_FinishBoardLayerState.fromLayer(layer));
    }
    _mikiriEnabled = m.mikiriEnabled;
    _mikiriName = TextEditingController(text: m.mikiriName);
    _mikiriLen = TextEditingController(
      text: (m.mikiriLengthMm > 0 ? m.mikiriLengthMm : 2000).round().toString(),
    );
    if (m.boardOtherItems.isEmpty) {
      _boardOtherRows.add(_OtherRowState.boardOther());
    } else {
      for (final item in m.boardOtherItems) {
        _boardOtherRows.add(_OtherRowState.boardOtherFromItem(item));
      }
    }
    for (final e in m.extraSizedItems) {
      _extraRows.add(_ExtraSizeRow.fromItem(e));
    }
  }

  @override
  void dispose() {
    _sqLen.dispose();
    _runnerLen.dispose();
    _boltLen.dispose();
    _nut.dispose();
    _hanger.dispose();
    _ukeLen.dispose();
    _wBarLen.dispose();
    _singleBarLen.dispose();
    _mikiriName.dispose();
    _mikiriLen.dispose();
    for (final r in _otherRows) {
      r.dispose();
    }
    for (final r in _boardOtherRows) {
      r.dispose();
    }
    for (final l in _boardLayers) {
      l.dispose();
    }
    for (final e in _extraRows) {
      e.dispose();
    }
    super.dispose();
  }

  double get _totalAreaM2 {
    var sum = 0.0;
    for (final c in widget.ceilings) {
      sum += c.quantities['ceiling_area_m2'] ??
          CalcEngine.polygonAreaMm2(c.points, widget.scalePxPerMm) / 1e6;
    }
    return sum;
  }

  double get _totalPerimeterMm {
    var sum = 0.0;
    for (final c in widget.ceilings) {
      final stored = c.quantities['perimeter_mm'];
      if (stored != null) {
        sum += stored;
        continue;
      }
      var periPx = 0.0;
      final pts = c.points;
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i];
        final b = pts[(i + 1) % pts.length];
        periPx += CalcEngine.distPx(a, b);
      }
      sum += CalcEngine.pxToMm(periPx, widget.scalePxPerMm);
    }
    return sum;
  }

  int get _mikiriCount {
    final peri = _totalPerimeterMm;
    final len = double.tryParse(_mikiriLen.text.trim()) ?? 0;
    if (len <= 0 || peri <= 0) return 0;
    return (peri / len).ceil();
  }

  List<CeilingLayoutResult> get _layouts {
    final live = widget.initialMethod;
    final out = <CeilingLayoutResult>[];
    for (final c in widget.ceilings) {
      if (c.points.length < 3) continue;
      final method = live == null
          ? c.method
          : c.method.copyWith(
              systemKind: live.systemKind,
              panelSpec: live.panelSpec,
              rotated90: live.rotated90,
              noenSpacingMm: live.noenSpacingMm,
            );
      out.add(CeilingLayoutEngine.layout(
        points: c.points,
        scalePxPerMm: widget.scalePxPerMm,
        method: method,
      ));
    }
    return out;
  }

  List<double> get _ukeLengthsMm => [
        for (final layout in _layouts)
          for (final b in layout.ukeBars) b.lengthPx / widget.scalePxPerMm,
      ];

  List<double> get _sqLengthsMm => [
        for (final layout in _layouts)
          for (final b in layout.squareStudBars)
            b.lengthPx / widget.scalePxPerMm,
      ];

  List<double> get _wBarLengthsMm => [
        for (final layout in _layouts)
          for (final b in layout.noenBars)
            if (b.isW && !b.isUke) b.lengthPx / widget.scalePxPerMm,
      ];

  List<double> get _singleBarLengthsMm => [
        for (final layout in _layouts)
          for (final b in layout.noenBars)
            if (!b.isW && !b.isUke) b.lengthPx / widget.scalePxPerMm,
      ];

  int get _wBarCount {
    final stock = double.tryParse(_wBarLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countUkeChannelPieces(
      ukeLengthsMm: _wBarLengthsMm,
      stockLengthMm: stock,
    );
  }

  int get _singleBarCount {
    final stock = double.tryParse(_singleBarLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countUkeChannelPieces(
      ukeLengthsMm: _singleBarLengthsMm,
      stockLengthMm: stock,
    );
  }

  int get _wBarJointCount {
    final stock = double.tryParse(_wBarLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countSpliceJoints(
      lengthsMm: _wBarLengthsMm,
      stockLengthMm: stock,
    );
  }

  int get _singleBarJointCount {
    final stock = double.tryParse(_singleBarLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countSpliceJoints(
      lengthsMm: _singleBarLengthsMm,
      stockLengthMm: stock,
    );
  }

  int get _channelJointCount {
    final stock = double.tryParse(_ukeLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countSpliceJoints(
      lengthsMm: _ukeLengthsMm,
      stockLengthMm: stock,
    );
  }

  int get _wClipCount {
    var n = 0;
    for (final layout in _layouts) {
      final wBars = [
        for (final b in layout.noenBars)
          if (b.isW && !b.isUke) b,
      ];
      n += CeilingLayoutEngine.countBarCrossings(wBars, layout.ukeBars);
    }
    return n;
  }

  int get _singleClipCount {
    var n = 0;
    for (final layout in _layouts) {
      final sBars = [
        for (final b in layout.noenBars)
          if (!b.isW && !b.isUke) b,
      ];
      n += CeilingLayoutEngine.countBarCrossings(sBars, layout.ukeBars);
    }
    return n;
  }

  /// 図面角スタッドの実測長さ（mm・昇順・重複除去）
  List<double> _computeMeasuredSqLengthsMm() {
    final set = <int>{};
    for (final c in widget.ceilings) {
      if (c.points.length < 3) continue;
      final layout = CeilingLayoutEngine.layout(
        points: c.points,
        scalePxPerMm: widget.scalePxPerMm,
        method: c.method,
      );
      for (final b in layout.squareStudBars) {
        final mm = b.lengthPx / widget.scalePxPerMm;
        if (mm > 1) set.add(mm.round());
      }
    }
    final list = set.toList()..sort();
    return [for (final n in list) n.toDouble()];
  }

  List<double> get _measuredSqLengthsMm => _computeMeasuredSqLengthsMm();

  /// 実測長 → 定尺候補 3000/4000/5000
  List<double> get _sqLenPickerValues {
    final out = <double>[..._measuredSqLengthsMm];
    for (final p in _stockPresets) {
      if (!out.any((v) => (v - p).abs() < 0.5)) out.add(p);
    }
    return out;
  }

  int get _boltCount =>
      _layouts.fold<int>(0, (s, l) => s + l.boltCount);

  int get _clipCount =>
      _layouts.fold<int>(0, (s, l) => s + l.squareStudUkeContactCount);

  double get _runnerEdgeTotalMm {
    var sum = 0.0;
    for (final c in widget.ceilings) {
      if (c.points.length < 3) continue;
      final layout = CeilingLayoutEngine.layout(
        points: c.points,
        scalePxPerMm: widget.scalePxPerMm,
        method: c.method,
      );
      sum += CeilingLayoutEngine.runnerPerpEdgeLengthMm(
        points: c.points,
        scalePxPerMm: widget.scalePxPerMm,
        method: c.method,
        squareStudBars: layout.squareStudBars,
      );
    }
    return sum;
  }

  int get _runnerCount {
    final stock = double.tryParse(_runnerLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countRunnerPieces(
      edgeTotalMm: _runnerEdgeTotalMm,
      stockLengthMm: stock,
    );
  }

  int get _sqStudCount {
    final stock = double.tryParse(_sqLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countUkeChannelPieces(
      ukeLengthsMm: _sqLengthsMm,
      stockLengthMm: stock,
    );
  }

  int get _ukeChannelCount {
    final stock = double.tryParse(_ukeLen.text.trim()) ?? 4000;
    return CeilingLayoutEngine.countUkeChannelPieces(
      ukeLengthsMm: _ukeLengthsMm,
      stockLengthMm: stock,
    );
  }

  CeilingMethod _buildMethod() {
    final base = widget.initialMethod ??
        (widget.ceilings.isNotEmpty
            ? widget.ceilings.first.method
            : const CeilingMethod());
    final boltLen = double.tryParse(_boltLen.text.trim()) ?? base.boltLengthMm;
    final sqLen = double.tryParse(_sqLen.text.trim()) ?? base.sqStudLengthMm;
    final ukeLen =
        double.tryParse(_ukeLen.text.trim()) ?? base.ukeChannelLengthMm;
    final runnerLen =
        double.tryParse(_runnerLen.text.trim()) ?? base.runnerLengthMm;
    final wBarLen = double.tryParse(_wBarLen.text.trim()) ?? base.wBarLengthMm;
    final singleBarLen =
        double.tryParse(_singleBarLen.text.trim()) ?? base.singleBarLengthMm;
    final nut = double.tryParse(_nut.text.trim());
    final hanger = double.tryParse(_hanger.text.trim());
    return base.copyWith(
      sqStudType: _sqType,
      sqStudLengthMm: sqLen,
      clipUkeLabel: _clipUke,
      clipType: _clipType,
      runnerWidthMm: _runnerWidth,
      runnerLengthMm: runnerLen,
      boltWidthLabel: _boltWidth,
      boltLengthMm: boltLen,
      ukeChannelWidthMm: _ukeWidth,
      ukeChannelLengthMm: ukeLen,
      channelJointWidthMm: _channelJointWidth,
      wBarHeightMm: _wBarHeight,
      wBarLengthMm: wBarLen,
      singleBarHeightMm: _singleBarHeight,
      singleBarLengthMm: singleBarLen,
      wClipUkeWidthMm: _wClipUkeWidth,
      singleClipUkeWidthMm: _singleClipUkeWidth,
      wBarJointHeightMm: _wBarJointHeight,
      singleBarJointHeightMm: _singleBarJointHeight,
      hangerBoltWidthLabel: _hangerBolt,
      hangerUkeWidthMm: _hangerUke,
      hangerFixtureHeightMm: _hangerHeight,
      extraSizedItems: [
        for (final r in _extraRows) r.toItem(),
      ],
      otherItems: [
        for (final r in _otherRows)
          if (r.name.trim().isNotEmpty ||
              r.unit.trim().isNotEmpty ||
              r.quantity.trim().isNotEmpty)
            CeilingOtherItem(
              name: r.name.trim(),
              unit: r.unit.trim(),
              quantity: double.tryParse(r.quantity.trim()) ?? 0,
            ),
      ],
      finishBoardLayers: [
        for (final l in _boardLayers) l.toLayer(),
      ],
      layers: BoardLayersX.fromCount(
        _boardLayers.isEmpty ? 1 : _boardLayers.length,
      ),
      boardSize: _boardLayers.isEmpty
          ? BoardSize.size36
          : _boardSizeFromFinish(_boardLayers.first),
      mikiriEnabled: _mikiriEnabled,
      mikiriName: _mikiriName.text.trim(),
      mikiriLengthMm: double.tryParse(_mikiriLen.text.trim()) ?? 2000,
      boardOtherItems: [
        for (final r in _boardOtherRows)
          if (r.name.trim().isNotEmpty ||
              r.unit.trim().isNotEmpty ||
              r.quantity.trim().isNotEmpty)
            CeilingOtherItem(
              name: r.name.trim(),
              unit: r.unit.trim(),
              quantity: double.tryParse(r.quantity.trim()) ?? 0,
            ),
      ],
      nutCountOverride: _nutManual ? nut : null,
      hangerCountOverride: _hangerManual ? hanger : null,
      clearNutOverride: !_nutManual,
      clearHangerOverride: !_hangerManual,
    );
  }

  void _syncAutoCounts() {
    final bolts = _boltCount;
    if (!_nutManual) _nut.text = (bolts * 2).toString();
    if (!_hangerManual) _hanger.text = bolts.toString();
  }

  void _pop(CeilingMaterialAction action) {
    Navigator.pop(
      context,
      CeilingMaterialResult(method: _buildMethod(), action: action),
    );
  }

  String get _circled {
    final n = widget.ceilingNumber;
    if (n >= 1 && n <= 20) return String.fromCharCode(0x245F + n);
    return '$n';
  }

  void _onClipUkeChanged(String label) {
    setState(() {
      _clipUke = label;
      final opts = _clipTypeOptions;
      if (!opts.contains(_clipType)) {
        _clipType = opts.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final area = _totalAreaM2;
    final clipOpts = _clipTypeOptions;
    final isSq = _isSq;
    final isZairai = _isZairai;

    return Scaffold(
      appBar: AppBar(title: Text('$_circled ${Ms.of(context).ceilMaterialTitle}')),
      body: SafeArea(
        child: KeyboardDoneScope(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
            _sectionTitle(Ms.of(context).ceilTotalArea),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                '${area.toStringAsFixed(2)} ㎡',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // —— 在来：W/シングルバー → チャンネル → クリップ → ジョイント ——
            if (isZairai) ...[
              _sectionTitle(Ms.of(context).wBar, kind: 'w_bar'),
              LockableCupertinoPicker(
                label: Ms.of(context).height,
                labels: [for (final h in _barHeights) '${h.round()}mm'],
                selectedIndex: _barHeights
                    .indexOf(_wBarHeight)
                    .clamp(0, _barHeights.length - 1),
                onSelected: (i) {
                  setState(() => _syncFromWBar(_barHeights[i]));
                },
              ),
              const SizedBox(height: 8),
              Text(Ms.of(context).lengthMm,
                  style: const TextStyle(fontSize: 13, color: AppTheme.steel)),
              const SizedBox(height: 6),
              _customLengthField(_wBarLen, onChanged: () => setState(() {})),
              const SizedBox(height: 8),
              _stockLengthPicker(_wBarLen),
              _extraRowsFor('w_bar'),
              const SizedBox(height: 20),
              _sectionTitle(Ms.of(context).sBar, kind: 'single_bar'),
              LockableCupertinoPicker(
                label: Ms.of(context).height,
                labels: [for (final h in _barHeights) '${h.round()}mm'],
                selectedIndex: _barHeights
                    .indexOf(_singleBarHeight)
                    .clamp(0, _barHeights.length - 1),
                liveUpdate: false,
                onSelected: (i) {
                  final next = _barHeights[i];
                  _pickOrConfirm(
                    current: _singleBarHeight,
                    next: next,
                    matchTo: _wBarHeight,
                    apply: () {
                      _singleBarHeight = next;
                      _singleBarJointHeight = next;
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(Ms.of(context).lengthMm,
                  style: const TextStyle(fontSize: 13, color: AppTheme.steel)),
              const SizedBox(height: 6),
              _customLengthField(_singleBarLen,
                  onChanged: () => setState(() {})),
              const SizedBox(height: 8),
              _stockLengthPicker(_singleBarLen),
              _extraRowsFor('single_bar'),
              const SizedBox(height: 20),
              ..._channelSectionWidgets(),
              _sectionTitle(Ms.of(context).wClip),
              LockableCupertinoPicker(
                label: Ms.of(context).ukeWidth,
                labels: [for (final w in _clipUkeWidths) '${w.round()}mm'],
                selectedIndex: _clipUkeWidths
                    .indexOf(_wClipUkeWidth)
                    .clamp(0, _clipUkeWidths.length - 1),
                liveUpdate: false,
                onSelected: (i) {
                  final next = _clipUkeWidths[i];
                  _pickOrConfirm(
                    current: _wClipUkeWidth,
                    next: next,
                    matchTo: _ukeWidth,
                    apply: () => _wClipUkeWidth = next,
                  );
                },
              ),
              const SizedBox(height: 20),
              _sectionTitle(Ms.of(context).sClip),
              LockableCupertinoPicker(
                label: Ms.of(context).ukeWidth,
                labels: [for (final w in _clipUkeWidths) '${w.round()}mm'],
                selectedIndex: _clipUkeWidths
                    .indexOf(_singleClipUkeWidth)
                    .clamp(0, _clipUkeWidths.length - 1),
                liveUpdate: false,
                onSelected: (i) {
                  final next = _clipUkeWidths[i];
                  _pickOrConfirm(
                    current: _singleClipUkeWidth,
                    next: next,
                    matchTo: _ukeWidth,
                    apply: () => _singleClipUkeWidth = next,
                  );
                },
              ),
              const SizedBox(height: 20),
              _sectionTitle(Ms.of(context).wBarJoint),
              LockableCupertinoPicker(
                label: Ms.of(context).height,
                labels: [for (final h in _barHeights) '${h.round()}mm'],
                selectedIndex: _barHeights
                    .indexOf(_wBarJointHeight)
                    .clamp(0, _barHeights.length - 1),
                liveUpdate: false,
                onSelected: (i) {
                  final next = _barHeights[i];
                  _pickOrConfirm(
                    current: _wBarJointHeight,
                    next: next,
                    matchTo: _wBarHeight,
                    apply: () => _wBarJointHeight = next,
                  );
                },
              ),
              const SizedBox(height: 20),
              _sectionTitle(Ms.of(context).sBarJoint),
              LockableCupertinoPicker(
                label: Ms.of(context).height,
                labels: [for (final h in _barHeights) '${h.round()}mm'],
                selectedIndex: _barHeights
                    .indexOf(_singleBarJointHeight)
                    .clamp(0, _barHeights.length - 1),
                liveUpdate: false,
                onSelected: (i) {
                  final next = _barHeights[i];
                  _pickOrConfirm(
                    current: _singleBarJointHeight,
                    next: next,
                    matchTo: _wBarHeight,
                    apply: () => _singleBarJointHeight = next,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // —— SQ角スタッド（在来時は非表示）——
            if (isSq) ...[
              _sectionTitle(Ms.of(context).sqStud, kind: 'sq_stud'),
              _stringPicker(
                label: Ms.of(context).sqType,
                items: _sqTypes,
                value: _sqType,
                onChanged: (v) => setState(() => _sqType = v),
              ),
              const SizedBox(height: 8),
              Text(Ms.of(context).lengthMm,
                  style: const TextStyle(fontSize: 13, color: AppTheme.steel)),
              const SizedBox(height: 6),
              _customLengthField(_sqLen, onChanged: () => setState(() {})),
              const SizedBox(height: 8),
              _sqMeasuredLengthPicker(),
              if (_measuredSqLengthsMm.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '実測 ${[for (final v in _measuredSqLengthsMm) '${v.round()}mm'].join(' / ')}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
              ],
              _extraRowsFor('sq_stud'),
              const SizedBox(height: 20),
            ],

            // —— ランナー ——
            _sectionTitle(Ms.of(context).runner, kind: 'runner'),
            LockableCupertinoPicker(
              label: Ms.of(context).typeWidth,
              labels: [for (final w in _runnerWidths) '${w.round()}mm'],
              selectedIndex:
                  _runnerWidths.indexOf(_runnerWidth).clamp(0, _runnerWidths.length - 1),
              liveUpdate: false,
              onSelected: (i) {
                final next = _runnerWidths[i];
                if (_isZairai) {
                  _pickOrConfirm(
                    current: _runnerWidth,
                    next: next,
                    matchTo: _wBarHeight,
                    runnerBarPair: true,
                    apply: () => _runnerWidth = next,
                  );
                } else {
                  setState(() => _runnerWidth = next);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(Ms.of(context).lengthMm,
                style: TextStyle(fontSize: 13, color: AppTheme.steel)),
            const SizedBox(height: 6),
            _customLengthField(_runnerLen, onChanged: () => setState(() {})),
            const SizedBox(height: 8),
            _mmPresetPicker(
              label: Ms.of(context).stockLen,
              presets: _runnerLengthPresets,
              controller: _runnerLen,
              includeCustomLabel: true,
            ),
            _extraRowsFor('runner'),
            const SizedBox(height: 20),

            // —— 角スタクリップ（在来時は非表示）——
            if (isSq) ...[
              _sectionTitle(Ms.of(context).studClip),
              _stringPicker(
                label: Ms.of(context).uke,
                items: _clipUkeLabels,
                value: _clipUke,
                onChanged: _onClipUkeChanged,
              ),
              const SizedBox(height: 8),
              _stringPicker(
                key: ValueKey('clip-$_clipUke'),
                label: Ms.of(context).typeXY,
                items: clipOpts,
                value: clipOpts.contains(_clipType) ? _clipType : clipOpts.first,
                onChanged: (v) => setState(() => _clipType = v),
              ),
              const SizedBox(height: 20),
            ],

            // —— 全ネジボルト ——
            _sectionTitle(Ms.of(context).fullBolt, kind: 'bolt'),
            _stringPicker(
              label: Ms.of(context).width,
              items: _boltWidths,
              value: _boltWidth,
              onChanged: (v) => setState(() {
                _boltWidth = v;
                _hangerBolt = v;
              }),
            ),
            const SizedBox(height: 8),
            Text(Ms.of(context).lengthMm,
                style: TextStyle(fontSize: 13, color: AppTheme.steel)),
            const SizedBox(height: 6),
            _customLengthField(_boltLen),
            const SizedBox(height: 8),
            _mmPresetPicker(
              label: Ms.of(context).stockLen,
              presets: _boltLengthPresets,
              controller: _boltLen,
              includeCustomLabel: true,
            ),
            _extraRowsFor('bolt'),
            const SizedBox(height: 20),

            _sectionTitle(Ms.of(context).nut),
            TextField(
              controller: _nut,
              keyboardType: DoneKeyboard.integer,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                suffixText: '個',
                labelText: Ms.of(context).nutQty,
              ),
              onChanged: (_) => setState(() => _nutManual = true),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _nutManual = false;
                    _syncAutoCounts();
                  });
                },
                child: Text(Ms.of(context).resetAuto),
              ),
            ),
            const SizedBox(height: 8),
            _sectionTitle(Ms.of(context).hangerOpt),
            LockableCupertinoPicker(
              label: Ms.of(context).boltType,
              labels: _boltWidths,
              selectedIndex: _boltWidths
                  .indexOf(_hangerBolt)
                  .clamp(0, _boltWidths.length - 1),
              onSelected: (i) => setState(() => _hangerBolt = _boltWidths[i]),
            ),
            const SizedBox(height: 8),
            LockableCupertinoPicker(
              label: Ms.of(context).uke,
              labels: [for (final w in _ukeWidths) '${w.round()}mm'],
              selectedIndex: _ukeWidths
                  .indexOf(_hangerUke)
                  .clamp(0, _ukeWidths.length - 1),
              liveUpdate: false,
              onSelected: (i) {
                final next = _ukeWidths[i];
                _pickOrConfirm(
                  current: _hangerUke,
                  next: next,
                  matchTo: _ukeWidth,
                  apply: () => _hangerUke = next,
                );
              },
            ),
            const SizedBox(height: 8),
            LockableCupertinoPicker(
              label: Ms.of(context).fittingH,
              labels: [for (final h in _hangerHeights) '${h.round()}mm'],
              selectedIndex: _hangerHeights
                  .indexOf(_hangerHeight)
                  .clamp(0, _hangerHeights.length - 1),
              onSelected: (i) =>
                  setState(() => _hangerHeight = _hangerHeights[i]),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _hanger,
              keyboardType: DoneKeyboard.integer,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                suffixText: '個',
                labelText: Ms.of(context).hangerQty,
              ),
              onChanged: (_) => setState(() => _hangerManual = true),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _hangerManual = false;
                    _syncAutoCounts();
                  });
                },
                child: Text(Ms.of(context).resetAuto),
              ),
            ),
            const SizedBox(height: 12),
            if (isSq) ..._channelSectionWidgets(),
            _sectionTitle(Ms.of(context).other),
            for (var i = 0; i < _otherRows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _otherRowWidget(i),
            ],
            const SizedBox(height: 20),
            for (var li = 0; li < _boardLayers.length; li++) ...[
              if (li > 0) const SizedBox(height: 16),
              _finishBoardLayerSection(li, area),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '見切り',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _mikiriEnabled,
              onChanged: (v) => setState(() => _mikiriEnabled = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: IconButton(
                tooltip: Ms.of(context).extraSizeTooltip,
                onPressed: () => _openExtraDialog('mikiri'),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ),
            _extraRowsFor('mikiri'),
            if (_mikiriEnabled) ...[
              Text(
                '見切り総長 = 図形周長　'
                '${(_totalPerimeterMm / 1000).toStringAsFixed(2)} m'
                '（${_totalPerimeterMm.round()} mm）',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mikiriName,
                textInputAction: DoneKeyboard.action,
                onSubmitted: DoneKeyboard.onSubmitted,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: Ms.of(context).extraNameCode,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mikiriLen,
                keyboardType: DoneKeyboard.integer,
                textInputAction: DoneKeyboard.action,
                onSubmitted: DoneKeyboard.onSubmitted,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: Ms.of(context).length,
                  suffixText: 'mm',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                '見切り数量（自動）= 周長 ÷ 長さ　切上げ　$_mikiriCount 本',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _sectionTitle(Ms.of(context).otherBoard),
            for (var i = 0; i < _boardOtherRows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _boardOtherRowWidget(i),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _pop(CeilingMaterialAction.save),
              child: Text(Ms.of(context).save),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              onPressed: () => _pop(CeilingMaterialAction.estimate),
              child: Text(Ms.of(context).toEstimate),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).cancel,
                  style: const TextStyle(color: AppTheme.steel)),
            ),
          ],
          ),
        ),
      ),
    );
  }

  BoardSize _boardSizeFromFinish(_FinishBoardLayerState layer) {
    for (final s in BoardSize.values) {
      final (w, h) = s.mmSize;
      if ((w - layer.widthMm).abs() < 0.5 &&
          (h - layer.heightMm).abs() < 0.5) {
        return s;
      }
    }
    return BoardSize.size36;
  }

  Widget _finishBoardLayerSection(int index, double area) {
    final layer = _boardLayers[index];
    final sizeIdx = _kBoardSizeOpts.indexWhere(
      (o) =>
          (o.$2 - layer.widthMm).abs() < 0.5 &&
          (o.$3 - layer.heightMm).abs() < 0.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(Ms.of(context).layerBoard(index + 1))),
            if (index == _boardLayers.length - 1)
              IconButton(
                tooltip: Ms.of(context).addLayer,
                onPressed: () {
                  setState(() {
                    _boardLayers.add(_FinishBoardLayerState());
                  });
                },
                icon: const Icon(Icons.add_circle, color: AppTheme.navy),
              ),
            if (_boardLayers.length > 1)
              IconButton(
                tooltip: Ms.of(context).deleteLayer,
                onPressed: () {
                  setState(() {
                    final removed = _boardLayers.removeAt(index);
                    removed.dispose();
                  });
                },
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.steel),
              ),
          ],
        ),
        LockableCupertinoPicker(
          label: Ms.of(context).boardNamePick,
          labels: _kBoardNames,
          selectedIndex: layer.boardNamePickerIndex,
          height: 120,
          onSelected: (i) {
            setState(() {
              if (i == 0) {
                layer.useCustomName = true;
                if (_kBoardNames.contains(layer.nameCtrl.text) ||
                    layer.nameCtrl.text == _kBoardNameCustom) {
                  layer.nameCtrl.clear();
                }
              } else {
                layer.useCustomName = false;
                layer.name = _kBoardNames[i];
                layer.nameCtrl.text = layer.name;
              }
            });
          },
        ),
        if (layer.useCustomName) ...[
          const SizedBox(height: 6),
          TextField(
            controller: layer.nameCtrl,
            textInputAction: DoneKeyboard.action,
            onSubmitted: DoneKeyboard.onSubmitted,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: Ms.of(context).customName,
            ),
          ),
        ],
        const SizedBox(height: 8),
        LockableCupertinoPicker(
          label: Ms.of(context).size,
          labels: [for (final o in _kBoardSizeOpts) o.$1],
          selectedIndex:
              (sizeIdx < 0 ? 4 : sizeIdx).clamp(0, _kBoardSizeOpts.length - 1),
          height: 110,
          onSelected: (i) {
            setState(() {
              layer.widthMm = _kBoardSizeOpts[i].$2;
              layer.heightMm = _kBoardSizeOpts[i].$3;
            });
          },
        ),
        const SizedBox(height: 8),
        LockableCupertinoPicker(
          label: Ms.of(context).thickness,
          labels: [
            for (final t in _kBoardThicknesses)
              t == t.roundToDouble() ? '${t.round()}mm' : '${t}mm',
          ],
          selectedIndex: _kBoardThicknesses
              .indexOf(layer.thicknessMm)
              .clamp(0, _kBoardThicknesses.length - 1),
          onSelected: (i) =>
              setState(() => layer.thicknessMm = _kBoardThicknesses[i]),
        ),
      ],
    );
  }

  Widget _boardOtherRowWidget(int index) {
    final row = _boardOtherRows[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SavedNamePicker(
                label: Ms.of(context).itemName,
                prefsKey: SavedNameCatalog.boardOtherNames,
                value: row.name,
                presets: _kBoardOtherNamePresetsFixed,
                onChanged: (v) {
                  setState(() {
                    row.preset = _kBoardOtherNamePresetsFixed.contains(v)
                        ? v
                        : _kOtherNameCustom;
                    row.nameCtrl.text = v;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.unitCtrl,
                      textInputAction: DoneKeyboard.action,
                      onSubmitted: DoneKeyboard.onSubmitted,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: Ms.of(context).unit,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.qtyCtrl,
                      keyboardType: DoneKeyboard.decimal,
                      inputFormatters: DoneKeyboard.decimalFormatters,
                      textInputAction: DoneKeyboard.action,
                      onSubmitted: DoneKeyboard.onSubmitted,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: Ms.of(context).qty,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Column(
          children: [
            IconButton(
              tooltip: Ms.of(context).addRow,
              onPressed: () {
                setState(() {
                  _boardOtherRows.insert(
                      index + 1, _OtherRowState.boardOther());
                });
              },
              icon: const Icon(Icons.add_circle, color: AppTheme.navy),
            ),
            if (_boardOtherRows.length > 1)
              IconButton(
                tooltip: Ms.of(context).deleteRow,
                onPressed: () {
                  setState(() {
                    final removed = _boardOtherRows.removeAt(index);
                    removed.dispose();
                  });
                },
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.steel),
              ),
          ],
        ),
      ],
    );
  }

  Widget _otherRowWidget(int index) {
    final row = _otherRows[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SavedNamePicker(
                label: Ms.of(context).itemName,
                prefsKey: SavedNameCatalog.ceilingOtherNames,
                value: row.name,
                presets: _kOtherNamePresetsFixed,
                onChanged: (v) {
                  setState(() {
                    row.preset = _kOtherNamePresetsFixed.contains(v)
                        ? v
                        : _kOtherNameCustom;
                    row.nameCtrl.text = v;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.unitCtrl,
                      textInputAction: DoneKeyboard.action,
                      onSubmitted: DoneKeyboard.onSubmitted,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: Ms.of(context).unit,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.qtyCtrl,
                      keyboardType: DoneKeyboard.decimal,
                      inputFormatters: DoneKeyboard.decimalFormatters,
                      textInputAction: DoneKeyboard.action,
                      onSubmitted: DoneKeyboard.onSubmitted,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: Ms.of(context).qty,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Column(
          children: [
            IconButton(
              tooltip: Ms.of(context).addRow,
              onPressed: () {
                setState(() {
                  _otherRows.insert(index + 1, _OtherRowState());
                });
              },
              icon: const Icon(Icons.add_circle, color: AppTheme.navy),
            ),
            if (_otherRows.length > 1)
              IconButton(
                tooltip: Ms.of(context).deleteRow,
                onPressed: () {
                  setState(() {
                    final removed = _otherRows.removeAt(index);
                    removed.dispose();
                  });
                },
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.steel),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _channelSectionWidgets() {
    return [
      _sectionTitle(Ms.of(context).channel, kind: 'channel'),
      LockableCupertinoPicker(
        label: Ms.of(context).width,
        labels: [for (final w in _ukeWidths) '${w.round()}mm'],
        selectedIndex:
            _ukeWidths.indexOf(_ukeWidth).clamp(0, _ukeWidths.length - 1),
        onSelected: (i) {
          setState(() => _syncFromChannel(_ukeWidths[i]));
        },
      ),
      const SizedBox(height: 8),
      Text(Ms.of(context).lengthMm,
          style: TextStyle(fontSize: 13, color: AppTheme.steel)),
      const SizedBox(height: 6),
      _customLengthField(_ukeLen, onChanged: () => setState(() {})),
      const SizedBox(height: 8),
      _stockLengthPicker(_ukeLen),
      _extraRowsFor('channel'),
      const SizedBox(height: 20),
      _sectionTitle(Ms.of(context).channelJoint),
      LockableCupertinoPicker(
        label: Ms.of(context).width,
        labels: [for (final w in _channelJointWidths) '${w.round()}mm'],
        selectedIndex: _channelJointWidths
            .indexOf(_channelJointWidth)
            .clamp(0, _channelJointWidths.length - 1),
        liveUpdate: false,
        onSelected: (i) {
          final next = _channelJointWidths[i];
          _pickOrConfirm(
            current: _channelJointWidth,
            next: next,
            matchTo: _ukeWidth,
            apply: () => _channelJointWidth = next,
          );
        },
      ),
      const SizedBox(height: 20),
    ];
  }

  List<double> _extraWidthsFor(String kind) {
    switch (kind) {
      case 'w_bar':
      case 'single_bar':
        return _barHeights;
      case 'channel':
        return _ukeWidths;
      case 'runner':
        return _runnerWidths;
      default:
        return _runnerWidths;
    }
  }

  ExtraSizedItem _defaultExtra(String kind) {
    switch (kind) {
      case 'w_bar':
        return ExtraSizedItem(
          kind: kind,
          widthMm: _wBarHeight,
          lengthMm: double.tryParse(_wBarLen.text.trim()) ?? 4000,
          qty: 1,
        );
      case 'single_bar':
        return ExtraSizedItem(
          kind: kind,
          widthMm: _singleBarHeight,
          lengthMm: double.tryParse(_singleBarLen.text.trim()) ?? 4000,
          qty: 1,
        );
      case 'channel':
        return ExtraSizedItem(
          kind: kind,
          widthMm: _ukeWidth,
          lengthMm: double.tryParse(_ukeLen.text.trim()) ?? 4000,
          qty: 1,
        );
      case 'runner':
        return ExtraSizedItem(
          kind: kind,
          widthMm: _runnerWidth,
          lengthMm: double.tryParse(_runnerLen.text.trim()) ?? 4000,
          qty: 1,
        );
      case 'sq_stud':
        return ExtraSizedItem(
          kind: kind,
          code: _sqType,
          lengthMm: double.tryParse(_sqLen.text.trim()) ?? 4000,
          qty: 1,
        );
      case 'bolt':
        return ExtraSizedItem(
          kind: kind,
          code: _boltWidth,
          lengthMm: double.tryParse(_boltLen.text.trim()) ?? 1000,
          qty: 1,
        );
      case 'mikiri':
        return ExtraSizedItem(
          kind: kind,
          code: _mikiriName.text.trim(),
          lengthMm: double.tryParse(_mikiriLen.text.trim()) ?? 2000,
          qty: 1,
        );
      default:
        return ExtraSizedItem(kind: kind, qty: 1);
    }
  }

  Future<void> _openExtraDialog(String kind, {int? editIndex}) async {
    final seed = editIndex != null
        ? _extraRows[editIndex].toItem()
        : _defaultExtra(kind);
    ExtraSizedItem? result;
    switch (kind) {
      case 'sq_stud':
        result = await showExtraSizeDialog(
          context: context,
          title: Ms.of(context).extraSizeTitle(kind),
          initial: seed,
          codes: _sqTypes,
          codeLabel: Ms.of(context).sqType,
          lengths: _stockPresets,
        );
        break;
      case 'bolt':
        result = await showExtraSizeDialog(
          context: context,
          title: Ms.of(context).extraSizeTitle(kind),
          initial: seed,
          codes: _boltWidths,
          codeLabel: Ms.of(context).width,
          lengths: _boltLengthPresets,
        );
        break;
      case 'mikiri':
        result = await showExtraSizeDialog(
          context: context,
          title: Ms.of(context).extraSizeTitle(kind),
          initial: seed,
          showName: true,
          lengths: const [2000, 2500, 3000, 4000],
        );
        break;
      default:
        result = await showExtraSizeDialog(
          context: context,
          title: Ms.of(context).extraSizeTitle(kind),
          initial: seed,
          widths: _extraWidthsFor(kind),
          lengths: _stockPresets,
        );
    }
    if (result == null || !mounted) return;
    setState(() {
      final row = _ExtraSizeRow.fromItem(result!);
      if (editIndex != null) {
        final old = _extraRows[editIndex];
        _extraRows[editIndex] = row;
        old.dispose();
      } else {
        _extraRows.add(row);
      }
    });
  }

  Widget _sectionTitle(String t, {String? kind}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            if (kind != null)
              IconButton(
                tooltip: Ms.of(context).extraSizeTooltip,
                onPressed: () => _openExtraDialog(kind),
                icon: const Icon(Icons.add_circle_outline),
              ),
          ],
        ),
      );

  Widget _extraRowsFor(String kind) {
    final rows = [
      for (var i = 0; i < _extraRows.length; i++)
        if (_extraRows[i].kind == kind) i,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        children: [
          for (final i in rows) _extraSummaryTile(i),
        ],
      ),
    );
  }

  String _extraSummaryText(_ExtraSizeRow row) {
    final item = row.toItem();
    final qty = item.qty == item.qty.roundToDouble()
        ? item.qty.toStringAsFixed(0)
        : item.qty.toString();
    switch (item.kind) {
      case 'sq_stud':
        return '${item.code} × ${item.lengthMm.round()}mm　$qty${item.unit}';
      case 'bolt':
        return '${item.code} × ${item.lengthMm.round()}mm　$qty${item.unit}';
      case 'mikiri':
        final name = item.code.trim().isEmpty ? '見切り' : item.code.trim();
        return '$name　${item.lengthMm.round()}mm　$qty${item.unit}';
      default:
        return '${item.widthMm.round()}mm × ${item.lengthMm.round()}mm　'
            '$qty${item.unit}';
    }
  }

  Widget _extraSummaryTile(int index) {
    final row = _extraRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFFE8F0F8),
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          title: Text(
            _extraSummaryText(row),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(Ms.of(context).extraSizeSub),
          onTap: () => _openExtraDialog(row.kind, editIndex: index),
          trailing: IconButton(
            tooltip: Ms.of(context).delete,
            onPressed: () => setState(() {
              final removed = _extraRows.removeAt(index);
              removed.dispose();
            }),
            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.steel),
          ),
        ),
      ),
    );
  }

  Widget _customLengthField(
    TextEditingController c, {
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: c,
      keyboardType: DoneKeyboard.integer,
      textInputAction: DoneKeyboard.action,
      onSubmitted: DoneKeyboard.onSubmitted,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        suffixText: 'mm',
        hintText: Ms.of(context).directInput,
        labelText: Ms.of(context).custom,
      ),
      onChanged: (_) => onChanged?.call(),
    );
  }

  Widget _stringPicker({
    Key? key,
    required String label,
    required List<String> items,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    var idx = items.indexOf(value);
    if (idx < 0) idx = 0;
    return LockableCupertinoPicker(
      key: key,
      label: label,
      labels: items,
      selectedIndex: idx,
      onSelected: (i) => onChanged(items[i]),
    );
  }

  /// 3000/4000/5000 + カスタム（入力欄を維持）
  Widget _stockLengthPicker(TextEditingController controller) {
    return _mmPresetPicker(
      label: Ms.of(context).stockLen,
      presets: _stockPresets,
      controller: controller,
      includeCustomLabel: true,
    );
  }

  /// SQ角スタッド長さ：図面実測値を先頭に表示＋定尺＋カスタム
  Widget _sqMeasuredLengthPicker() {
    final measured = _measuredSqLengthsMm;
    final values = _sqLenPickerValues;
    final labels = <String>[
      for (final v in values)
        measured.any((m) => (m - v).abs() < 0.5)
            ? '実測 ${v.round()}mm'
            : '${v.round()}mm',
      'カスタム（直接入力）',
    ];
    final cur = double.tryParse(_sqLen.text.trim());
    var idx = 0;
    if (cur != null) {
      final found = values.indexWhere((v) => (v - cur).abs() < 0.5);
      idx = found >= 0 ? found : labels.length - 1;
    }
    return LockableCupertinoPicker(
      label: Ms.of(context).lengthPick,
      height: 110,
      labels: labels,
      selectedIndex: idx,
      onSelected: (i) {
        if (i == labels.length - 1) {
          setState(() {});
          return;
        }
        setState(() {
          _sqLen.text = values[i].round().toString();
        });
      },
    );
  }

  Widget _mmPresetPicker({
    required String label,
    required List<double> presets,
    required TextEditingController controller,
    bool includeCustomLabel = false,
  }) {
    final labels = <String>[
      for (final v in presets) '${v.round()}mm',
      if (includeCustomLabel) 'カスタム（直接入力）',
    ];
    final cur = double.tryParse(controller.text.trim());
    var idx = cur == null ? 0 : presets.indexOf(cur);
    if (idx < 0) idx = includeCustomLabel ? labels.length - 1 : 0;
    return LockableCupertinoPicker(
      label: label,
      labels: labels,
      selectedIndex: idx,
      onSelected: (i) {
        if (includeCustomLabel && i == labels.length - 1) {
          setState(() {});
          return;
        }
        setState(() {
          controller.text = presets[i].round().toString();
        });
      },
    );
  }
}

class _FinishBoardLayerState {
  _FinishBoardLayerState({
    this.name = 'タイガーボード',
    this.widthMm = 910,
    this.heightMm = 1820,
    this.thicknessMm = 9.5,
    this.useCustomName = false,
    String customName = '',
  }) : nameCtrl = TextEditingController(
          text: useCustomName
              ? customName
              : (name == _kBoardNameCustom ? '' : name),
        );

  factory _FinishBoardLayerState.fromLayer(CeilingFinishBoardLayer layer) {
    final presets = _kBoardNames.skip(1).toList();
    final isCustom =
        layer.name.isEmpty ||
        layer.name == _kBoardNameCustom ||
        !presets.contains(layer.name);
    final sizeIdx = _kBoardSizeOpts.indexWhere(
      (o) =>
          (o.$2 - layer.widthMm).abs() < 0.5 &&
          (o.$3 - layer.heightMm).abs() < 0.5,
    );
    final size = sizeIdx >= 0 ? _kBoardSizeOpts[sizeIdx] : _kBoardSizeOpts[4];
    final thick = _kBoardThicknesses.contains(layer.thicknessMm)
        ? layer.thicknessMm
        : 9.5;
    return _FinishBoardLayerState(
      name: isCustom ? _kBoardNameCustom : layer.name,
      widthMm: size.$2,
      heightMm: size.$3,
      thicknessMm: thick,
      useCustomName: isCustom,
      customName: isCustom ? layer.name : layer.name,
    );
  }

  String name;
  double widthMm;
  double heightMm;
  double thicknessMm;
  bool useCustomName;
  final TextEditingController nameCtrl;

  int get boardNamePickerIndex {
    if (useCustomName) return 0;
    final i = _kBoardNames.indexOf(name);
    return i < 0 ? 0 : i;
  }

  void dispose() {
    nameCtrl.dispose();
  }

  CeilingFinishBoardLayer toLayer() => CeilingFinishBoardLayer(
        name: useCustomName
            ? nameCtrl.text.trim()
            : (name == _kBoardNameCustom ? nameCtrl.text.trim() : name),
        widthMm: widthMm,
        heightMm: heightMm,
        thicknessMm: thicknessMm,
      );
}

class _OtherRowState {
  _OtherRowState({
    this.preset = _kOtherNameCustom,
    String name = '',
    String unit = '',
    String quantity = '',
  })  : nameCtrl = TextEditingController(text: name),
        unitCtrl = TextEditingController(text: unit),
        qtyCtrl = TextEditingController(text: quantity);

  factory _OtherRowState.fromItem(CeilingOtherItem item) {
    final isPreset =
        _kOtherNamePresets.contains(item.name) && item.name != _kOtherNameCustom;
    return _OtherRowState(
      preset: isPreset ? item.name : _kOtherNameCustom,
      name: item.name,
      unit: item.unit,
      quantity: item.quantity == 0 ? '' : item.quantity.toString(),
    );
  }

  factory _OtherRowState.boardOther({
    String? preset,
    String name = '',
    String unit = '',
    String quantity = '',
  }) {
    final p = preset ?? _kOtherNameCustom;
    return _OtherRowState(
      preset: p,
      name: name.isNotEmpty ? name : (p == _kOtherNameCustom ? '' : p),
      unit: unit,
      quantity: quantity,
    );
  }

  factory _OtherRowState.boardOtherFromItem(CeilingOtherItem item) {
    final isPreset = _kBoardOtherNamePresetsFixed.contains(item.name);
    return _OtherRowState.boardOther(
      preset: isPreset ? item.name : _kOtherNameCustom,
      name: item.name,
      unit: item.unit,
      quantity: item.quantity == 0 ? '' : item.quantity.toString(),
    );
  }

  String preset;
  final TextEditingController nameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController qtyCtrl;

  String get name {
    if (preset == _kOtherNameCustom) return nameCtrl.text.trim();
    if (nameCtrl.text.trim().isNotEmpty) return nameCtrl.text.trim();
    return preset;
  }
  String get unit => unitCtrl.text;
  String get quantity => qtyCtrl.text;

  void dispose() {
    nameCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _ExtraSizeRow {
  _ExtraSizeRow({
    required this.kind,
    required this.widthMm,
    required this.lengthMm,
    required this.unit,
    this.code = '',
    String qty = '1',
  }) : qty = TextEditingController(text: qty);

  factory _ExtraSizeRow.fromItem(ExtraSizedItem e) => _ExtraSizeRow(
        kind: e.kind,
        widthMm: e.widthMm,
        lengthMm: e.lengthMm,
        unit: e.unit,
        code: e.code,
        qty: e.qty == e.qty.roundToDouble()
            ? e.qty.toStringAsFixed(0)
            : e.qty.toString(),
      );

  final String kind;
  double widthMm;
  double lengthMm;
  final String unit;
  final String code;
  final TextEditingController qty;

  ExtraSizedItem toItem() => ExtraSizedItem(
        kind: kind,
        widthMm: widthMm,
        lengthMm: lengthMm,
        qty: double.tryParse(qty.text.trim()) ?? 0,
        unit: unit,
        code: code,
      );

  void dispose() {
    qty.dispose();
  }
}
