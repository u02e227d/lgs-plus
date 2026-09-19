import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../services/board_spec_parse.dart';
import '../../services/lgs_catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/extra_size_dialog.dart';
import '../../widgets/keyboard_done.dart';
import '../../widgets/lockable_picker.dart';
import '../../widgets/measure_painters.dart';
import '../../widgets/saved_name_picker.dart';
import '../../services/saved_name_catalog.dart';

class WallParamsResult {
  WallParamsResult({required this.heightMm, required this.method});
  final double heightMm;
  final WallMethod method;
}

class WallParamsSheet extends StatefulWidget {
  const WallParamsSheet({
    super.key,
    this.initialHeightMm,
    this.initialMethod,
    this.measuredLengthMm,
    this.ironDrawLengthMm,
    this.linePoints,
    this.scalePxPerMm,
    this.measuredCornerCount = 0,
    this.measuredOpeningAreaM2,
    this.autoCheckIronPlate = false,
    this.ironPlateOnly = false,
    this.autoCheckReinforce = false,
    this.autoCheckAngle = false,
    this.reinforceBarCount = 0,
    this.anglePieceCount = 0,
  });

  final double? initialHeightMm;
  final WallMethod? initialMethod;
  final double? measuredLengthMm;
  /// 番号横の黄色いラベルと同じ mm（材料選択では再計算せずこれを出す）
  final double? ironDrawLengthMm;
  /// 画線頂点（鉄板長さを線ラベルと同じ式で出す）
  final List<Point2>? linePoints;
  final double? scalePxPerMm;
  final int measuredCornerCount;
  /// 紐付け済み開口の合計面積 (㎡)
  final double? measuredOpeningAreaM2;
  /// 鉄板専用の測定データがあるとき、鉄板チェックを自動ON
  final bool autoCheckIronPlate;
  /// 鉄板線からの流入：壁高・ボード面積は出さず鉄板欄を先頭に
  final bool ironPlateOnly;
  final bool autoCheckReinforce;
  final bool autoCheckAngle;
  final int reinforceBarCount;
  final int anglePieceCount;

  @override
  State<WallParamsSheet> createState() => _WallParamsSheetState();
}

class _WallParamsSheetState extends State<WallParamsSheet> {
  late final TextEditingController _height;
  final _waste = TextEditingController(text: '10');
  late final TextEditingController _boardNameA;
  late final TextEditingController _boardNameB;

  bool useLgs = true;
  bool useBoard = true;
  bool useCross = false;
  LgsForm form = LgsForm.form65;
  StudProfile profile = StudProfile.channel;
  SquareStudSize squareStud = SquareStudSize.s4065;
  LgsPitch pitch = LgsPitch.p303;
  BoardSize boardSize = BoardSize.size36;
  BoardSize boardSizeB = BoardSize.size36;
  BoardThickness boardThickness = BoardThickness.t12_5;
  BoardLayers layers = BoardLayers.single;
  BoardLayers layersB = BoardLayers.single;
  WallSides sides = WallSides.both;
  bool useSpacer = false;
  bool useFureDome = true;
  bool useBoardFaceA = false;
  bool useBoardFaceB = false;
  double fureDomeWidthMm = 19;
  double fureDomeLengthMm = 4000;
  double runnerSpacerMm = 10;
  double runnerWidthMm = 45;
  double runnerLengthMm = 4000;
  bool useRockFelt = false;
  double rockFeltWidthMm = 12.5;
  bool useTigerUtight = false;
  String tigerUtightType = '320';
  bool useGlassWool = false;
  int glassWoolK = 24;
  final List<_WallOtherRow> _otherBeforeGlass = [];
  final List<_WallOtherRow> _otherAfterUtight = [];
  final List<_WallExtraSizeRow> _extraRows = [];
  bool useIronPlate = false;
  bool _ironUserOff = false;
  bool _ironPlateFromMaterial = false;
  double ironPlateWidthMm = 300;
  double ironPlateLengthMm = 1820;
  int ironPlateSegments = 1;
  bool useReinforceMaterial = false;
  double reinforceWidthMm = 45;
  double reinforceLengthMm = 3000;
  bool _reinforceLengthCustom = false;
  bool useAnglePiece = false;
  double anglePieceMm = 50;
  bool _anglePieceCustom = false;
  late final TextEditingController _studLength;
  late final TextEditingController _reinforceLength;
  late final TextEditingController _anglePiece;
  String? presetId;
  double? detectedThickness;
  double _boardTotalA = 12.5;
  double _boardTotalB = 12.5;
  String _seedStackA = '12.5+';
  String _seedStackB = '12.5+';
  String _seedLgsCore = '45+';
  String? _syncSummary;
  List<double> _layersA = [12.5];
  List<double> _layersB = [12.5];
  List<BoardSize> _sizesA = [BoardSize.size36];
  List<BoardSize> _sizesB = [BoardSize.size36];
  List<String> _savedBoardNames = ['普通PB', '強化石膏ボード', '耐火PB'];
  bool _studLengthCustom = false;

  static const _boardMms = [
    3.0, 4.0, 5.0, 6.0, 8.0, 9.0, 9.5, 10.0, 12.0, 12.5, 15.0, 21.0,
  ];
  static const _studLengthPresets = [2500.0, 3000.0, 3200.0, 3500.0];
  static const _runnerLengths = [3000.0, 4000.0, 5000.0];
  static const _fureDomeWidths = [19.0, 25.0, 38.0];
  static const _fureDomeLengths = [3000.0, 4000.0, 5000.0];
  static const _spacerMms = [10.0, 15.0, 25.0];
  static const _rockFeltWidths = [
    8.0, 12.5, 15.0, 21.0, 27.5, 30.0, 100.0,
  ];
  static const _glassWoolKs = [16, 24, 32];
  static const _ironPlateWidths = [
    100.0, 120.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0, 450.0, 500.0,
  ];
  static const _ironPlateLengths = [
    300.0, 600.0, 910.0, 1200.0, 1500.0, 1820.0,
  ];
  static const _tigerTypes = ['320', '720'];
  static const _kBoardNames = 'wall_board_kind_names';
  static const _namedSizes = [
    BoardSize.size26,
    BoardSize.size36,
    BoardSize.size38,
    BoardSize.size39,
  ];

  @override
  void initState() {
    super.initState();
    _height = TextEditingController(
      text: (widget.initialHeightMm ?? 2700).toStringAsFixed(0),
    );
    _boardNameA = TextEditingController(text: '普通PB');
    _boardNameB = TextEditingController(text: '普通PB');
    final seedH = widget.initialHeightMm ?? 2700;
    _studLength = TextEditingController(text: seedH.toStringAsFixed(0));
    _reinforceLength = TextEditingController(text: '3000');
    _anglePiece = TextEditingController(text: '50');
    final seed = widget.initialMethod;
    if (seed != null) {
      _applyInitialMethod(seed);
    }
    _restoreAutoChecks(seed);
    if (widget.autoCheckIronPlate || widget.ironPlateOnly) {
      useIronPlate = true;
      _ironPlateFromMaterial = true;
    }
    if (widget.ironPlateOnly) {
      useLgs = false;
      useBoard = false;
      useBoardFaceA = false;
      useBoardFaceB = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _restoreAutoChecks(widget.initialMethod);
        if (widget.autoCheckIronPlate) {
          useIronPlate = true;
          _ironPlateFromMaterial = true;
        }
      });
    });
    if (_otherBeforeGlass.isEmpty) {
      _otherBeforeGlass.add(_WallOtherRow());
    }
    if (_otherAfterUtight.isEmpty) {
      _otherAfterUtight.add(_WallOtherRow());
    }
    _loadBoardNames();
  }

  Future<void> _loadBoardNames() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kBoardNames);
    if (!mounted) return;
    if (raw != null && raw.isNotEmpty) {
      setState(() => _savedBoardNames = raw);
    }
  }

  Future<void> _saveBoardName(String name, {bool updateState = true}) async {
    final t = name.trim();
    if (t.isEmpty) return;
    final next = [t, ..._savedBoardNames.where((e) => e != t)];
    if (updateState && mounted) {
      setState(() {
        _savedBoardNames = next;
      });
    } else {
      _savedBoardNames = next;
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kBoardNames, next);
  }

  void _applyInitialMethod(WallMethod m) {
    useLgs = m.useLgs;
    useBoard = m.useBoard;
    useCross = m.useCross;
    form = LgsFormX.fromStudWidth(m.studWidthMm);
    profile =
        m.studProfile == 'square' ? StudProfile.square : StudProfile.channel;
    if (m.squareStudCode.isNotEmpty) {
      squareStud = SquareStudSizeX.fromCode(m.squareStudCode);
    } else if (profile == StudProfile.square) {
      squareStud = SquareStudSizeX.fromCode(m.lgsFormCode);
    }
    pitch = m.pitch == LgsPitch.p300
        ? LgsPitch.p303
        : (m.pitch == LgsPitch.p450 ? LgsPitch.p455 : m.pitch);
    boardSize = _namedSizes.contains(m.boardSize) ? m.boardSize : BoardSize.size36;
    boardSizeB =
        _namedSizes.contains(m.boardSizeB) ? m.boardSizeB : boardSize;
    sides = m.bothSides ? WallSides.both : WallSides.single;
    useSpacer = m.useSpacer;
    useFureDome = m.useFureDome;
    useBoardFaceA = m.useBoardFaceA;
    useBoardFaceB = m.useBoardFaceB;
    fureDomeWidthMm = _nearestOf(const [19.0, 25.0, 38.0], m.fureDomeWidthMm);
    fureDomeLengthMm =
        _nearestOf(const [3000.0, 4000.0, 5000.0], m.fureDomeLengthMm);
    useRockFelt = m.useRockFelt;
    rockFeltWidthMm = _nearestOf(_rockFeltWidths, m.rockFeltWidthMm);
    useTigerUtight = m.useTigerUtight;
    tigerUtightType = m.tigerUtightType == '720' ? '720' : '320';
    useGlassWool = m.useGlassWool;
    glassWoolK = _glassWoolKs.contains(m.glassWoolK)
        ? m.glassWoolK
        : (m.glassWoolK == 36 ? 32 : 24);
    for (final r in _otherBeforeGlass) {
      r.dispose();
    }
    _otherBeforeGlass
      ..clear()
      ..addAll([
        if (m.otherItemsBeforeGlassWool.isEmpty)
          _WallOtherRow()
        else
          for (final e in m.otherItemsBeforeGlassWool)
            _WallOtherRow.fromItem(e),
      ]);
    for (final r in _otherAfterUtight) {
      r.dispose();
    }
    _otherAfterUtight
      ..clear()
      ..addAll([
        if (m.otherItemsAfterUtight.isEmpty)
          _WallOtherRow()
        else
          for (final e in m.otherItemsAfterUtight) _WallOtherRow.fromItem(e),
      ]);
    for (final r in _extraRows) {
      r.dispose();
    }
    _extraRows
      ..clear()
      ..addAll([
        for (final e in m.extraSizedItems) _WallExtraSizeRow.fromItem(e),
      ]);
    _ironPlateFromMaterial = m.useIronPlate || widget.autoCheckIronPlate;
    ironPlateWidthMm =
        _nearestOf(_ironPlateWidths, m.ironPlateWidthMm);
    ironPlateLengthMm =
        _nearestOf(_ironPlateLengths, m.ironPlateLengthMm);
    ironPlateSegments = m.ironPlateSegmentCount;
    useIronPlate = m.useIronPlate || widget.autoCheckIronPlate;
    useReinforceMaterial = m.useReinforceMaterial;
    final defaultReinforceW = m.runnerWidthMm > 0
        ? m.runnerWidthMm
        : (m.reinforceWidthMm > 0 ? m.reinforceWidthMm : m.studWidthMm);
    reinforceWidthMm = LgsFormX.fromStudWidth(defaultReinforceW).studWidthMm;
    final defaultReinforceLen = m.reinforceLengthMm > 0
        ? m.reinforceLengthMm
        : (m.studLengthMm > 0
            ? m.studLengthMm
            : (widget.initialHeightMm ?? 3000));
    _reinforceLengthCustom = !_studLengthPresets.any(
      (e) => (e - defaultReinforceLen).abs() < 0.5,
    );
    reinforceLengthMm = defaultReinforceLen;
    _reinforceLength.text = defaultReinforceLen ==
            defaultReinforceLen.roundToDouble()
        ? defaultReinforceLen.toStringAsFixed(0)
        : defaultReinforceLen.toStringAsFixed(1);
    useAnglePiece = m.useAnglePiece;
    runnerSpacerMm = _nearestOf(const [10.0, 15.0, 25.0], m.runnerSpacerMm);
    runnerWidthMm = m.runnerWidthMm > 0 ? m.runnerWidthMm : m.studWidthMm;
    runnerWidthMm = LgsFormX.fromStudWidth(runnerWidthMm).studWidthMm;
    anglePieceMm = m.anglePieceMm > 0 ? m.anglePieceMm : _defaultAngleMm();
    _clampAnglePieceToRunner();
    _anglePieceCustom =
        !_anglePresetsFit.any((e) => (e - anglePieceMm).abs() < 0.5);
    _anglePiece.text = anglePieceMm == anglePieceMm.roundToDouble()
        ? anglePieceMm.toStringAsFixed(0)
        : anglePieceMm.toStringAsFixed(1);
    runnerLengthMm =
        _nearestOf(const [3000.0, 4000.0, 5000.0], m.runnerLengthMm);
    if (m.studLengthMm > 0) {
      _studLength.text = m.studLengthMm == m.studLengthMm.roundToDouble()
          ? m.studLengthMm.toStringAsFixed(0)
          : m.studLengthMm.toStringAsFixed(1);
      _studLengthCustom = !_studLengthPresets.any(
        (e) => (e - m.studLengthMm).abs() < 0.5,
      );
    } else {
      final h = widget.initialHeightMm ?? 2700;
      final nearest = _nearestOf(_studLengthPresets, h);
      _studLength.text = nearest.toStringAsFixed(0);
      _studLengthCustom = false;
    }
    presetId = m.presetId;
    _boardNameA.text = _cleanBoardKind(
      m.boardKindA.isNotEmpty ? m.boardKindA : '普通PB',
    );
    _boardNameB.text = _cleanBoardKind(
      m.boardKindB.isNotEmpty ? m.boardKindB : _boardNameA.text,
    );
    _seedStackA = m.boardStackA;
    _seedStackB = m.boardStackB;
    _seedLgsCore = m.lgsCoreSpec.isNotEmpty ? m.lgsCoreSpec : '45+';

    final layersAMm = BoardSpecParse.layers(_seedStackA);
    final layersBMm = BoardSpecParse.layers(_seedStackB);
    _layersA = layersAMm.isEmpty
        ? <double>[]
        : layersAMm.map((e) => _nearestOf(_boardMms, e)).toList();
    _layersB = layersBMm.isEmpty
        ? <double>[]
        : layersBMm.map((e) => _nearestOf(_boardMms, e)).toList();
    layers = BoardLayersX.fromCount(_layersA.isEmpty ? 1 : _layersA.length);
    layersB = BoardLayersX.fromCount(_layersB.isEmpty ? 1 : _layersB.length);
    boardThickness = _layersA.isEmpty
        ? BoardThickness.t12_5
        : _thicknessFromMm(_layersA.first);
    _seedStackA =
        _layersA.isEmpty ? '' : '${_layersA.map(_mmLabel).join('+')}+';
    _seedStackB =
        _layersB.isEmpty ? '' : '${_layersB.map(_mmLabel).join('+')}+';
    _boardTotalA = _layersA.fold(0.0, (s, e) => s + e);
    _boardTotalB = _layersB.fold(0.0, (s, e) => s + e);

    final resolvedA = m.resolvedLayerSizesA(
      _layersA.isEmpty ? 1 : _layersA.length,
    );
    final resolvedB = m.resolvedLayerSizesB(
      _layersB.isEmpty ? 1 : _layersB.length,
    );
    _sizesA = _layersA.isEmpty
        ? <BoardSize>[]
        : resolvedA
            .map((s) => _namedSizes.contains(s) ? s : BoardSize.size36)
            .toList();
    _sizesB = _layersB.isEmpty
        ? <BoardSize>[]
        : resolvedB
            .map((s) => _namedSizes.contains(s) ? s : BoardSize.size36)
            .toList();
    if (_layersA.isNotEmpty) {
      _applyDefaultBoardSizes(_layersA, _sizesA);
      boardSize = _sizesA.first;
    }
    if (_layersB.isNotEmpty) {
      _applyDefaultBoardSizes(_layersB, _sizesB);
      boardSizeB = _sizesB.first;
    }

    detectedThickness = _finishedWallThicknessMm(
      runnerWidthMm: m.runnerWidthMm > 0 ? m.runnerWidthMm : m.studWidthMm,
      boardA: _boardTotalA,
      boardB: m.bothSides ? _boardTotalB : 0,
    );

    final extras = BoardSpecParse.namedExtras(_seedLgsCore);
    _syncSummary = [
      '線番号の材料寸法から同期',
      '壁高 ${(widget.initialHeightMm ?? 2700).toStringAsFixed(0)} mm',
      'ランナー ${runnerWidthMm.toStringAsFixed(0)}mm',
      'スタッド ${m.studWidthMm.toStringAsFixed(0)}形',
      if (extras.isNotEmpty) extras.join('+'),
      '面A ${_layersA.isEmpty ? 'なし' : _fmtStack(_layersA)}（${layers.label}）',
      if (m.bothSides)
        '面B ${_layersB.isEmpty ? 'なし' : _fmtStack(_layersB)}（${layersB.label}）'
      else
        '片面',
    ].join(' ／ ');

    _waste.text = ((m.crossWasteRate * 100).clamp(0, 50)).toStringAsFixed(0);
    _autoCheckRockFelt();
    _syncRunnerStudRules();
    _restoreAutoChecks(m);
  }

  /// 鉄板測定・開口補強の自動チェックを、他初期化の後で必ず戻す
  void _restoreAutoChecks(WallMethod? m) {
    final iron = widget.autoCheckIronPlate ||
        widget.ironPlateOnly ||
        (m?.useIronPlate ?? false);
    _ironPlateFromMaterial = iron || _ironPlateFromMaterial;
    if (iron) useIronPlate = true;
    if (widget.autoCheckReinforce || (m?.useReinforceMaterial ?? false)) {
      useReinforceMaterial = true;
    }
    if (widget.autoCheckAngle || (m?.useAnglePiece ?? false)) {
      useAnglePiece = true;
    }
  }

  /// ランナー幅＞スタッド幅のとき：スペーサーON・振れ止めOFF・ロックフェルト/UタイトON
  void _syncRunnerStudRules() {
    _clampAnglePieceToRunner();
    if (profile == StudProfile.square) return;
    if (!_needsRunnerSpacer) return;
    useSpacer = true;
    useFureDome = false;
    useRockFelt = true;
    useTigerUtight = true;
  }

  List<double> get _anglePresetsFit {
    const all = [30.0, 50.0, 90.0];
    return [for (final p in all) if (p <= runnerWidthMm + 0.01) p];
  }

  double _defaultAngleMm() {
    final fit = _anglePresetsFit;
    if (fit.isNotEmpty) return fit.last;
    return runnerWidthMm > 0 ? runnerWidthMm : 30;
  }

  void _clampAnglePieceToRunner() {
    if (runnerWidthMm <= 0) return;
    if (anglePieceMm <= runnerWidthMm + 0.01) return;
    final next = _defaultAngleMm();
    anglePieceMm = next;
    _anglePiece.text = next == next.roundToDouble()
        ? next.toStringAsFixed(0)
        : next.toStringAsFixed(1);
    _anglePieceCustom = !_anglePresetsFit.any((e) => (e - next).abs() < 0.5);
  }

  void _setUseSpacer(bool v) {
    useSpacer = v;
    if (v) {
      useRockFelt = true;
      useTigerUtight = true;
    }
  }

  bool get _ironChecked =>
      (widget.autoCheckIronPlate || widget.ironPlateOnly)
          ? !_ironUserOff
          : useIronPlate;

  void _syncIronPlateFromFaces() {
    if (_ironPlateFromMaterial ||
        (widget.autoCheckIronPlate && !_ironUserOff)) {
      useIronPlate = true;
    }
  }

  Widget _ironPlateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: _ironChecked,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            Ms.of(context).ironPlate,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          subtitle: widget.autoCheckIronPlate
              ? Text(
                  widget.ironPlateOnly
                      ? Ms.of(context).ironAutoDraw
                      : Ms.of(context).ironAutoT,
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          secondary: _extraAddButton('iron'),
          onChanged: (v) => setState(() {
            final on = v ?? false;
            useIronPlate = on;
            _ironUserOff = !on;
            _ironPlateFromMaterial = on;
          }),
        ),
        if (_ironChecked)
          _pairedScrollRow(
            leftLabel: Ms.of(context).width,
            leftPicker: _scrollPickBar<double>(
              label: Ms.of(context).width,
              items: _ironPlateWidths,
              value: _nearestOf(_ironPlateWidths, ironPlateWidthMm),
              labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
              onChanged: (v) => setState(() {
                useIronPlate = true;
                ironPlateWidthMm = v;
              }),
            ),
            rightLabel: Ms.of(context).stockLenFull,
            rightPicker: _scrollPickBar<double>(
              label: Ms.of(context).stockLen,
              items: _ironPlateLengths,
              value: _nearestOf(_ironPlateLengths, ironPlateLengthMm),
              labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
              onChanged: (v) => setState(() {
                useIronPlate = true;
                ironPlateLengthMm = v;
              }),
            ),
          ),
        if (_ironChecked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _scrollPickBar<int>(
              label: Ms.of(context).tiers,
              items: List<int>.generate(20, (i) => i + 1),
              value: ironPlateSegments.clamp(1, 20),
              labelOf: (n) => Ms.of(context).nTiers(n),
              onChanged: (v) => setState(() {
                useIronPlate = true;
                ironPlateSegments = v;
              }),
            ),
          ),
        if (_ironChecked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ironMeasureMm > 0
                      ? '画線長さ ${distanceLabelText(_ironMeasureMm)}'
                          '（鉄板Tの全長）'
                      : '画線長さ —（Tの測定値がありません）',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _ironMeasureMm > 0
                      ? '数量 ${_ironPlateSheetCount()} 枚'
                      : '数量 —',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ),
          ),
        _extraRowsFor('iron'),
      ],
    );
  }

  double get _ironMeasureMm {
    // T 横の全長だけを使う。壁の wall_length / 最終区間は使わない
    final passed = widget.ironDrawLengthMm ?? 0;
    if (passed > 0) return passed;
    return 0;
  }

  int _ironPlateSheetCount() {
    final lengthMm = _ironMeasureMm;
    if (ironPlateLengthMm <= 0 || lengthMm <= 0) return 0;
    final seg = ironPlateSegments < 1
        ? 1
        : (ironPlateSegments > 20 ? 20 : ironPlateSegments);
    final sheets = (lengthMm * seg / ironPlateLengthMm).ceil();
    return sheets < 1 ? 1 : sheets;
  }

  Widget _reinforceMaterialSection() {
    double syncLenFromStud() {
      final sl = double.tryParse(_studLength.text.trim());
      if (sl != null && sl > 0) return sl;
      return reinforceLengthMm > 0 ? reinforceLengthMm : 3000;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Ms.of(context).reinforce,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              _extraAddButton('reinforce'),
              Checkbox(
                value: useReinforceMaterial,
                onChanged: (v) => setState(() {
                  useReinforceMaterial = v ?? false;
                  if (useReinforceMaterial) {
                    final runnerW = runnerWidthMm > 0
                        ? runnerWidthMm
                        : (profile == StudProfile.square
                            ? squareStud.studWidthMm
                            : form.studWidthMm);
                    reinforceWidthMm =
                        LgsFormX.fromStudWidth(runnerW).studWidthMm;
                    final sl = syncLenFromStud();
                    reinforceLengthMm = sl;
                    _reinforceLengthCustom = !_studLengthPresets.any(
                      (e) => (e - sl).abs() < 0.5,
                    );
                    _reinforceLength.text = sl == sl.roundToDouble()
                        ? sl.toStringAsFixed(0)
                        : sl.toStringAsFixed(1);
                  }
                }),
              ),
            ],
          ),
        ),
        if (useReinforceMaterial)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.reinforceBarCount > 0
                  ? '数量 ${widget.reinforceBarCount} 本（開口補強の割付）'
                  : '数量 —（開口の補強割付がありません）',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
          ),
        if (useReinforceMaterial) ...[
          _pairedScrollRow(
            leftLabel: Ms.of(context).width,
            leftPicker: _scrollPickBar<double>(
              label: Ms.of(context).width,
              items: [for (final f in LgsForm.values) f.studWidthMm],
              value: _nearestOf(
                [for (final f in LgsForm.values) f.studWidthMm],
                reinforceWidthMm,
              ),
              labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
              onChanged: (v) => setState(() {
                useReinforceMaterial = true;
                reinforceWidthMm = v;
              }),
            ),
            rightLabel: Ms.of(context).length,
            rightPicker: _scrollPickBar<String>(
              label: Ms.of(context).length,
              items: const [
                '2500',
                '3000',
                '3200',
                '3500',
                '直接入力',
              ],
              value: _reinforceLengthCustom
                  ? '直接入力'
                  : () {
                      final v =
                          double.tryParse(_reinforceLength.text.trim());
                      if (v == null) return '3000';
                      for (final p in _studLengthPresets) {
                        if ((p - v).abs() < 0.5) {
                          return p.toStringAsFixed(0);
                        }
                      }
                      return '直接入力';
                    }(),
              labelOf: (s) => s == '直接入力' ? Ms.of(context).directInput : '${s}mm',
              onChanged: (s) => setState(() {
                useReinforceMaterial = true;
                if (s == '直接入力') {
                  _reinforceLengthCustom = true;
                } else {
                  _reinforceLengthCustom = false;
                  _reinforceLength.text = s;
                  reinforceLengthMm = double.tryParse(s) ?? reinforceLengthMm;
                }
              }),
            ),
          ),
          if (_reinforceLengthCustom) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _reinforceLength,
              keyboardType: DoneKeyboard.decimal,
              inputFormatters: DoneKeyboard.decimalFormatters,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              decoration: InputDecoration(
                labelText: Ms.of(context).reinforceLenDirect,
                suffixText: 'mm',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (t) {
                final v = double.tryParse(t.trim());
                if (v != null && v > 0) {
                  reinforceLengthMm = v;
                }
              },
            ),
          ],
        ],
        _extraRowsFor('reinforce'),
      ],
    );
  }

  Widget _anglePieceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Ms.of(context).anglePiece,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Checkbox(
                value: useAnglePiece,
                onChanged: (v) => setState(() {
                  useAnglePiece = v ?? false;
                  if (useAnglePiece &&
                      double.tryParse(_anglePiece.text.trim()) == null) {
                    final d = _defaultAngleMm();
                    anglePieceMm = d;
                    _anglePiece.text = d == d.roundToDouble()
                        ? d.toStringAsFixed(0)
                        : d.toStringAsFixed(1);
                    _anglePieceCustom =
                        !_anglePresetsFit.any((e) => (e - d).abs() < 0.5);
                  }
                }),
              ),
            ],
          ),
        ),
        if (useAnglePiece)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.anglePieceCount > 0
                  ? '数量 ${widget.anglePieceCount} 個'
                  : '数量 —',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
          ),
        if (useAnglePiece) ...[
          _scrollPickBar<String>(
            label: Ms.of(context).size,
            items: [
              for (final p in _anglePresetsFit) p.toStringAsFixed(0),
              '直接入力',
            ],
            value: _anglePieceCustom
                ? '直接入力'
                : () {
                    final v = double.tryParse(_anglePiece.text.trim());
                    if (v == null) {
                      return _defaultAngleMm() == _defaultAngleMm().roundToDouble()
                          ? _defaultAngleMm().toStringAsFixed(0)
                          : '直接入力';
                    }
                    for (final p in _anglePresetsFit) {
                      if ((p - v).abs() < 0.5) {
                        return p.toStringAsFixed(0);
                      }
                    }
                    return '直接入力';
                  }(),
            labelOf: (s) => s == '直接入力' ? Ms.of(context).directInput : '${s}mm',
            onChanged: (s) => setState(() {
              useAnglePiece = true;
              if (s == '直接入力') {
                _anglePieceCustom = true;
              } else {
                _anglePieceCustom = false;
                _anglePiece.text = s;
                anglePieceMm = double.tryParse(s) ?? _defaultAngleMm();
                _clampAnglePieceToRunner();
              }
            }),
          ),
          if (_anglePieceCustom) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _anglePiece,
              keyboardType: DoneKeyboard.decimal,
              inputFormatters: DoneKeyboard.decimalFormatters,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              decoration: InputDecoration(
                labelText: Ms.of(context).angleDirect,
                suffixText: 'mm',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (t) {
                final v = double.tryParse(t.trim());
                if (v == null || v <= 0) return;
                if (runnerWidthMm > 0 && v > runnerWidthMm + 0.01) {
                  final d = _defaultAngleMm();
                  anglePieceMm = d;
                  _anglePiece.text = d == d.roundToDouble()
                      ? d.toStringAsFixed(0)
                      : d.toStringAsFixed(1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        Ms.of(context).angleMax(runnerWidthMm.round()),
                      ),
                    ),
                  );
                  return;
                }
                anglePieceMm = v;
              },
            ),
          ],
        ],
      ],
    );
  }

  /// ボード名称に Z／強化／ハイパー／スーパー、または厚さ 21mm → ロックフェルト自動ON
  bool _boardSuggestsRockFelt() {
    final names = '${_boardNameA.text} ${_boardNameB.text}';
    final n = names.toUpperCase();
    if (n.contains('Z') ||
        names.contains('強化') ||
        names.contains('强化') ||
        names.contains('ハイパー') ||
        names.contains('スーパー')) {
      return true;
    }
    for (final mm in [..._layersA, if (sides == WallSides.both) ..._layersB]) {
      if ((mm - 21).abs() < 0.05) return true;
    }
    return false;
  }

  void _autoCheckRockFelt() {
    if (_boardSuggestsRockFelt()) {
      useRockFelt = true;
    }
  }

  String _fmtStack(List<double> mms) {
    if (mms.isEmpty) return '—';
    return mms
        .map((e) =>
            e == e.roundToDouble() ? e.toStringAsFixed(0) : e.toStringAsFixed(1))
        .join('+');
  }

  static BoardThickness _thicknessFromMm(double mm) {
    if (mm >= 18) return BoardThickness.t21;
    if (mm >= 14) return BoardThickness.t15;
    if (mm <= 10.5) return BoardThickness.t9_5;
    return BoardThickness.t12_5;
  }

  String _mmLabel(double mm) =>
      mm == mm.roundToDouble() ? mm.toStringAsFixed(0) : mm.toStringAsFixed(1);

  /// 品名から厚さ表記を除く（厚さはスタック／試算の仕様欄で管理）
  static String _cleanBoardKind(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*mm', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*PB\s*', caseSensitive: false), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isEmpty ? '普通PB' : t;
  }

  static double _nearestOf(List<double> opts, double v) {
    var best = opts.first;
    var d = (v - best).abs();
    for (final o in opts) {
      final dd = (o - v).abs();
      if (dd < d) {
        d = dd;
        best = o;
      }
    }
    return best;
  }

  bool get _needsRunnerSpacer {
    if (profile == StudProfile.square) return false;
    final stud = form.studWidthMm;
    return stud < runnerWidthMm;
  }

  void _applyLayers(List<double> next, {required bool faceA}) {
    setState(() {
      useBoard = true;
      if (faceA) {
        useBoardFaceA = true;
        _layersA = next.isEmpty ? [12.5] : next;
        _sizesA = _alignSizes(_sizesA, _layersA.length, boardSize);
        _seedStackA = '${_layersA.map(_mmLabel).join('+')}+';
        _boardTotalA = _layersA.fold(0.0, (s, e) => s + e);
        layers = BoardLayersX.fromCount(_layersA.length);
        boardThickness = _thicknessFromMm(_layersA.first);
        _applyDefaultBoardSizes(_layersA, _sizesA);
        boardSize = _sizesA.first;
      } else {
        useBoardFaceB = true;
        _layersB = next.isEmpty ? [12.5] : next;
        _sizesB = _alignSizes(_sizesB, _layersB.length, boardSizeB);
        _seedStackB = '${_layersB.map(_mmLabel).join('+')}+';
        _boardTotalB = _layersB.fold(0.0, (s, e) => s + e);
        layersB = BoardLayersX.fromCount(_layersB.length);
        _applyDefaultBoardSizes(_layersB, _sizesB);
        boardSizeB = _sizesB.first;
      }
      _syncBoardOffsets();
      _autoCheckRockFelt();
    });
  }

  List<BoardSize> _alignSizes(
    List<BoardSize> current,
    int len,
    BoardSize fallback,
  ) {
    if (len <= 0) return [fallback];
    final out = <BoardSize>[];
    for (var i = 0; i < len; i++) {
      out.add(i < current.length
          ? current[i]
          : (current.isNotEmpty ? current.last : fallback));
    }
    return out;
  }

  void _applyLayerSizes(List<BoardSize> next, {required bool faceA}) {
    setState(() {
      useBoard = true;
      if (faceA) {
        _sizesA = _alignSizes(next, _layersA.length, BoardSize.size36);
        boardSize = _sizesA.first;
      } else {
        _sizesB = _alignSizes(next, _layersB.length, BoardSize.size36);
        boardSizeB = _sizesB.first;
      }
    });
  }

  /// 厚さ 21mm → 2×6、それ以外 → 3×6
  void _applyDefaultBoardSizes(List<double> layers, List<BoardSize> sizes) {
    for (var i = 0; i < layers.length && i < sizes.length; i++) {
      sizes[i] = (layers[i] - 21).abs() < 0.05
          ? BoardSize.size26
          : BoardSize.size36;
    }
  }

  void _syncBoardOffsets() {
    detectedThickness = _finishedWallThicknessMm(
      runnerWidthMm: runnerWidthMm > 0
          ? runnerWidthMm
          : (profile == StudProfile.square
              ? squareStud.studWidthMm
              : form.studWidthMm),
      boardA: useBoardFaceA ? _boardTotalA : 0,
      boardB: useBoardFaceB && sides == WallSides.both ? _boardTotalB : 0,
    );
  }

  /// 仕上壁厚 = ランナー幅 + ボード（面A/B）。スタッド幅ではない。
  static double _finishedWallThicknessMm({
    required double runnerWidthMm,
    required double boardA,
    required double boardB,
  }) {
    final runner = runnerWidthMm > 0 ? runnerWidthMm : 0.0;
    return runner + boardA + boardB;
  }

  @override
  void dispose() {
    _height.dispose();
    _waste.dispose();
    _boardNameA.dispose();
    _boardNameB.dispose();
    _studLength.dispose();
    _reinforceLength.dispose();
    _anglePiece.dispose();
    for (final r in _otherBeforeGlass) {
      r.dispose();
    }
    for (final r in _otherAfterUtight) {
      r.dispose();
    }
    for (final r in _extraRows) {
      r.dispose();
    }
    super.dispose();
  }

  WallMethod _buildMethod() {
    final nameA = _cleanBoardKind(
      _boardNameA.text.trim().isEmpty ? '普通PB' : _boardNameA.text.trim(),
    );
    final nameB = _cleanBoardKind(
      _boardNameB.text.trim().isEmpty ? nameA : _boardNameB.text.trim(),
    );
    _boardNameA.text = nameA;
    _boardNameB.text = nameB;
    _saveBoardName(nameA, updateState: false);
    if (nameB != nameA) _saveBoardName(nameB, updateState: false);

    final isSquare = profile == StudProfile.square;
    final studW = isSquare ? squareStud.studWidthMm : form.studWidthMm;
    final formCode = studW.toInt().toString();
    final studLen = double.tryParse(_studLength.text.trim()) ?? 0;
    final faceA = useBoardFaceA && _layersA.isNotEmpty;
    final faceB =
        useBoardFaceB && sides == WallSides.both && _layersB.isNotEmpty;
    _seedStackA =
        faceA ? '${_layersA.map(_mmLabel).join('+')}+' : '';
    _seedStackB =
        faceB ? '${_layersB.map(_mmLabel).join('+')}+' : '';
    _boardTotalA = faceA ? _layersA.fold(0.0, (s, e) => s + e) : 0;
    _boardTotalB = faceB ? _layersB.fold(0.0, (s, e) => s + e) : 0;

    return WallMethod(
      useLgs: useLgs,
      lgsType: isSquare
          ? (studW >= 100 ? LgsType.type100 : LgsType.type65)
          : form.toLegacyType(),
      pitch: pitch,
      useBoard: faceA || faceB,
      useBoardFaceA: faceA,
      useBoardFaceB: faceB,
      boardSize: boardSize,
      boardSizeB: boardSizeB,
      layers: BoardLayersX.fromCount(faceA ? _layersA.length : 1),
      useCross: widget.initialMethod?.crossDedicated.enabled ?? false,
      crossWasteRate: 0.1,
      crossDedicated: widget.initialMethod?.crossDedicated ??
          const CrossDedicatedConfig(),
      lgsFormCode: formCode,
      studProfile: isSquare ? 'square' : 'channel',
      squareStudCode: isSquare ? squareStud.code : '',
      lgsCoreSpec: () {
        final extras = BoardSpecParse.namedExtras(_seedLgsCore);
        if (extras.isEmpty) return '$formCode+';
        return '$formCode+${extras.join('+')}';
      }(),
      boardThicknessMm: faceA ? _layersA.first : boardThickness.mm,
      boardThicknessAMm: faceA ? _boardTotalA : 0,
      boardThicknessBMm: faceB ? _boardTotalB : null,
      boardKindA: nameA,
      boardKindB: nameB,
      boardStackA: _seedStackA,
      boardStackB: _seedStackB,
      bothSides: faceB,
      runnerWidthMm: runnerWidthMm > 0 ? runnerWidthMm : studW,
      runnerLengthMm: runnerLengthMm,
      studLengthMm: studLen > 0 ? studLen : 0,
      useSpacer: useSpacer,
      useFureDome: useFureDome,
      fureDomeWidthMm: fureDomeWidthMm,
      fureDomeLengthMm: fureDomeLengthMm,
      runnerSpacerMm: runnerSpacerMm,
      boardLayerSizesA: faceA ? List<BoardSize>.from(_sizesA) : const [],
      boardLayerSizesB: faceB ? List<BoardSize>.from(_sizesB) : const [],
      useKeikal: false,
      keikalThicknessMm: 0,
      keikalBoardSize: BoardSize.size36,
      useRockFelt: useRockFelt,
      rockFeltWidthMm: rockFeltWidthMm,
      useTigerUtight: useTigerUtight,
      tigerUtightType: tigerUtightType,
      useGlassWool: useGlassWool,
      glassWoolK: glassWoolK,
      otherItemsBeforeGlassWool: [
        for (final r in _otherBeforeGlass)
          if (r.name.trim().isNotEmpty ||
              r.unit.trim().isNotEmpty ||
              r.quantity.trim().isNotEmpty)
            CeilingOtherItem(
              name: r.name.trim(),
              unit: r.unit.trim(),
              quantity: double.tryParse(r.quantity.trim()) ?? 0,
            ),
      ],
      otherItemsAfterUtight: [
        for (final r in _otherAfterUtight)
          if (r.name.trim().isNotEmpty ||
              r.unit.trim().isNotEmpty ||
              r.quantity.trim().isNotEmpty)
            CeilingOtherItem(
              name: r.name.trim(),
              unit: r.unit.trim(),
              quantity: double.tryParse(r.quantity.trim()) ?? 0,
            ),
      ],
      extraSizedItems: [
        for (final r in _extraRows) r.toItem(),
      ],
      useIronPlate: _ironChecked,
      ironPlateWidthMm: ironPlateWidthMm,
      ironPlateLengthMm: ironPlateLengthMm,
      ironPlateSegments: ironPlateSegments,
      useReinforceMaterial: useReinforceMaterial,
      reinforceWidthMm: reinforceWidthMm,
      reinforceLengthMm: () {
        final v = double.tryParse(_reinforceLength.text.trim());
        if (v != null && v > 0) return v;
        return reinforceLengthMm > 0 ? reinforceLengthMm : 3000.0;
      }(),
      useAnglePiece: useAnglePiece,
      anglePieceMm: () {
        final v = double.tryParse(_anglePiece.text.trim());
        if (v != null && v > 0) return v;
        return anglePieceMm > 0 ? anglePieceMm : 50.0;
      }(),
      presetId: null,
      detectedWallThicknessMm: detectedThickness,
    );
  }

  List<double> get _lgsWidths =>
      [for (final f in LgsForm.values) f.studWidthMm];

  List<double> _extraWidthsFor(String kind) {
    switch (kind) {
      case 'iron':
        return _ironPlateWidths;
      case 'fure_dome':
        return _fureDomeWidths;
      default:
        return _lgsWidths;
    }
  }

  List<double> _extraLengthsFor(String kind) {
    switch (kind) {
      case 'iron':
        return _ironPlateLengths;
      case 'fure_dome':
        return _fureDomeLengths;
      case 'runner':
        return _runnerLengths;
      case 'stud':
      case 'reinforce':
        return _studLengthPresets;
      default:
        return _runnerLengths;
    }
  }

  ExtraSizedItem _defaultExtra(String kind) {
    switch (kind) {
      case 'runner':
        return ExtraSizedItem(
          kind: kind,
          widthMm: runnerWidthMm,
          lengthMm: runnerLengthMm,
          qty: 1,
        );
      case 'stud':
        return ExtraSizedItem(
          kind: kind,
          widthMm: profile == StudProfile.square
              ? squareStud.studWidthMm
              : form.studWidthMm,
          lengthMm: double.tryParse(_studLength.text.trim()) ?? 3000,
          qty: 1,
        );
      case 'reinforce':
        return ExtraSizedItem(
          kind: kind,
          widthMm: reinforceWidthMm,
          lengthMm: double.tryParse(_reinforceLength.text.trim()) ??
              reinforceLengthMm,
          qty: 1,
        );
      case 'fure_dome':
        return ExtraSizedItem(
          kind: kind,
          widthMm: fureDomeWidthMm,
          lengthMm: fureDomeLengthMm,
          qty: 1,
        );
      case 'iron':
        return ExtraSizedItem(
          kind: kind,
          widthMm: ironPlateWidthMm,
          lengthMm: ironPlateLengthMm,
          qty: 1,
          unit: '枚',
        );
      default:
        return ExtraSizedItem(kind: kind, qty: 1);
    }
  }

  Future<void> _openExtraDialog(String kind, {int? editIndex}) async {
    final seed = editIndex != null
        ? _extraRows[editIndex].toItem()
        : _defaultExtra(kind);
    final result = await showExtraSizeDialog(
      context: context,
      title: Ms.of(context).extraSizeTitle(kind),
      initial: seed,
      widths: _extraWidthsFor(kind),
      lengths: _extraLengthsFor(kind),
      widthLabel: kind == 'iron' ? '幅' : '寸法',
    );
    if (result == null || !mounted) return;
    setState(() {
      final row = _WallExtraSizeRow.fromItem(result);
      if (editIndex != null) {
        final old = _extraRows[editIndex];
        _extraRows[editIndex] = row;
        old.dispose();
      } else {
        _extraRows.add(row);
      }
    });
  }

  Widget _extraAddButton(String kind) => IconButton(
        tooltip: '別寸法を追加',
        visualDensity: VisualDensity.compact,
        onPressed: () => _openExtraDialog(kind),
        icon: const Icon(Icons.add_circle_outline),
      );

  Widget _extraRowsFor(String kind) {
    final rows = [
      for (var i = 0; i < _extraRows.length; i++)
        if (_extraRows[i].kind == kind) i,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        children: [
          for (final i in rows) _extraSummaryTile(i),
        ],
      ),
    );
  }

  Widget _extraSummaryTile(int index) {
    final row = _extraRows[index];
    final item = row.toItem();
    final qty = item.qty == item.qty.roundToDouble()
        ? item.qty.toStringAsFixed(0)
        : item.qty.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFFE8F0F8),
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          title: Text(
            '${item.widthMm.round()}mm × ${item.lengthMm.round()}mm　'
            '$qty${item.unit}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(Ms.of(context).extraSizeSub),
          onTap: () => _openExtraDialog(row.kind, editIndex: index),
          trailing: IconButton(
            tooltip: '削除',
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

  Widget _sectionTitleInline(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
      );

  Widget _wallOtherRow(List<_WallOtherRow> rows, int index) {
    final row = rows[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              SavedNamePicker(
                label: Ms.of(context).itemName,
                prefsKey: SavedNameCatalog.wallOtherNames,
                value: row.nameCtrl.text,
                onChanged: (v) {
                  setState(() => row.nameCtrl.text = v);
                },
              ),
              const SizedBox(height: 6),
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
              tooltip: '行を追加',
              onPressed: () {
                setState(() {
                  rows.insert(index + 1, _WallOtherRow());
                });
              },
              icon: const Icon(Icons.add_circle, color: AppTheme.navy),
            ),
            if (rows.length > 1)
              IconButton(
                tooltip: '行を削除',
                onPressed: () {
                  setState(() {
                    final removed = rows.removeAt(index);
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

  Widget _scrollPickBar<T>({
    required String label,
    required List<T> items,
    required T value,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
    double height = 88,
  }) {
    return LockableWheel(
      label: label,
      height: height,
      child: _WheelSelect<T>(
        items: items,
        value: value,
        labelOf: labelOf,
        onChanged: onChanged,
      ),
    );
  }

  Widget _pairedScrollRow({
    required String leftLabel,
    required Widget leftPicker,
    required String rightLabel,
    required Widget rightPicker,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: leftPicker),
          const SizedBox(width: 12),
          Expanded(child: rightPicker),
        ],
      ),
    );
  }

  Widget _faceBoardSection({
    required String title,
    required bool faceEnabled,
    required ValueChanged<bool> onFaceEnabled,
    required TextEditingController nameCtrl,
    required List<double> layerMms,
    required List<BoardSize> layerSizes,
    required ValueChanged<List<double>> onLayersChanged,
    required ValueChanged<List<BoardSize>> onSizesChanged,
    required bool showName,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Checkbox(
                value: faceEnabled,
                onChanged: (v) => onFaceEnabled(v ?? false),
              ),
            ],
          ),
          if (faceEnabled) ...[
          if (showName) ...[
            const SizedBox(height: 6),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: nameCtrl.text),
              optionsBuilder: (v) {
                final q = v.text.trim();
                if (q.isEmpty) return _savedBoardNames;
                return _savedBoardNames.where((e) => e.contains(q)).toList();
              },
              onSelected: (v) {
                nameCtrl.text = v;
                _saveBoardName(v);
                setState(() {
                  useBoard = true;
                  _autoCheckRockFelt();
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                if (controller.text != nameCtrl.text && !focusNode.hasFocus) {
                  controller.text = nameCtrl.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '名称入力',
                    labelText: Ms.of(context).boardName,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) {
                    nameCtrl.text = v;
                    setState(_autoCheckRockFelt);
                  },
                  onSubmitted: (v) {
                    _saveBoardName(v);
                    setState(_autoCheckRockFelt);
                    onSubmit();
                  },
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          if (layerMms.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onLayersChanged([12.5]),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(Ms.of(context).addThickness),
              ),
            )
          else
          for (var i = 0; i < layerMms.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _scrollPickBar<double>(
                    label: Ms.of(context).thicknessLayer(i + 1),
                    items: _boardMms,
                    value: _nearestOf(_boardMms, layerMms[i]),
                    labelOf: (mm) => '${_mmLabel(mm)}mm',
                    onChanged: (v) {
                      final next = [...layerMms];
                      next[i] = v;
                      onLayersChanged(next);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _scrollPickBar<BoardSize>(
                    label: Ms.of(context).sizeLayer(i + 1),
                    items: _namedSizes,
                    value: () {
                      final s = i < layerSizes.length
                          ? layerSizes[i]
                          : BoardSize.size36;
                      return _namedSizes.contains(s) ? s : BoardSize.size36;
                    }(),
                    labelOf: (s) => s.label,
                    onChanged: (v) {
                      final next = _alignSizes(
                        layerSizes,
                        layerMms.length,
                        BoardSize.size36,
                      );
                      next[i] = v;
                      onSizesChanged(next);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (layerMms.isNotEmpty)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      onLayersChanged([...layerMms, layerMms.last]),
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: Text(Ms.of(context).addLayer),
                ),
                if (layerMms.length > 1)
                  TextButton.icon(
                    onPressed: () => onLayersChanged(
                      layerMms.sublist(0, layerMms.length - 1),
                    ),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(Ms.of(context).deleteLayer),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                  ),
              ],
            ),
          ], // faceEnabled
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final runnerW = runnerWidthMm > 0
        ? runnerWidthMm
        : (profile == StudProfile.square
            ? squareStud.studWidthMm
            : form.studWidthMm);
    final finishedCalc = _finishedWallThicknessMm(
      runnerWidthMm: runnerW,
      boardA: useBoardFaceA ? _boardTotalA : 0,
      boardB: useBoardFaceB && sides == WallSides.both ? _boardTotalB : 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
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
              Text(
                widget.ironPlateOnly
                    ? Ms.of(context).materialsIron
                    : Ms.of(context).materials,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (!widget.ironPlateOnly && _syncSummary != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.safetyYellow),
                  ),
                  child: Text(
                    '材料寸法から同期\n$_syncSummary',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (!widget.ironPlateOnly) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _height,
                textInputAction: DoneKeyboard.action,
                onSubmitted: DoneKeyboard.onSubmitted,
                keyboardType: DoneKeyboard.integer,
                inputFormatters: DoneKeyboard.integerFormatters,
                decoration: InputDecoration(
                  labelText: Ms.of(context).wallHeight,
                  hintText: '2700',
                ),
              ),
              ],
              if (!widget.ironPlateOnly && widget.measuredLengthMm != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF59D).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFBC02D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Ms.of(context).measuredValue,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Ms.of(context).wallLenM(
                          (widget.measuredLengthMm! / 1000).toStringAsFixed(3),
                        ),
                      ),
                      if (detectedThickness != null)
                        Text(
                          Ms.of(context).wallThick(
                            detectedThickness!.toStringAsFixed(0),
                          ),
                        ),
                      Builder(
                        builder: (_) {
                          final h =
                              double.tryParse(_height.text.trim()) ?? 2700;
                          final gross = (widget.measuredLengthMm! / 1000) *
                              (h / 1000);
                          final opening = (widget.measuredOpeningAreaM2 ?? 0)
                              .clamp(0.0, gross);
                          final net = (gross - opening)
                              .clamp(0.0, double.infinity);
                          if (opening > 0) {
                            return Text(
                              '壁面積 ${net.toStringAsFixed(2)} m²'
                              '（総 ${gross.toStringAsFixed(2)}'
                              ' − 開口 ${opening.toStringAsFixed(2)}）',
                            );
                          }
                          return Text(
                            '壁面積（概算） ${net.toStringAsFixed(2)} m²',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _ironPlateSection(),
              if (!widget.ironPlateOnly) ...[
              const SizedBox(height: 8),
              _reinforceMaterialSection(),
              const SizedBox(height: 8),
              _anglePieceSection(),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: useLgs,
                onChanged: (v) => setState(() => useLgs = v ?? true),
                title: Text(Ms.of(context).lgsBase),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useLgs) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Ms.of(context).runner,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _extraAddButton('runner'),
                    ],
                  ),
                ),
                _pairedScrollRow(
                  leftLabel: Ms.of(context).runnerW,
                  leftPicker: _scrollPickBar<double>(
                    label: Ms.of(context).runnerW,
                    items: [
                      for (final f in LgsForm.values) f.studWidthMm,
                    ],
                    value: runnerWidthMm,
                    labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                    onChanged: (v) => setState(() {
                      runnerWidthMm = v;
                      _syncRunnerStudRules();
                      _syncBoardOffsets();
                    }),
                  ),
                  rightLabel: Ms.of(context).runnerL,
                  rightPicker: _scrollPickBar<double>(
                    label: Ms.of(context).runnerL,
                    items: _runnerLengths,
                    value: _nearestOf(_runnerLengths, runnerLengthMm),
                    labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                    onChanged: (v) => setState(() => runnerLengthMm = v),
                  ),
                ),
                _extraRowsFor('runner'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Ms.of(context).studType,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _extraAddButton('stud'),
                    ],
                  ),
                ),
                _scrollPickBar<StudProfile>(
                  label: Ms.of(context).studType,
                  items: const [StudProfile.channel, StudProfile.square],
                  value: profile,
                  labelOf: (p) =>
                      p == StudProfile.channel
                          ? Ms.of(context).channelType
                          : Ms.of(context).squareStud,
                  onChanged: (p) => setState(() {
                    profile = p;
                    if (p == StudProfile.square) {
                      useFureDome = false;
                      useSpacer = false;
                    } else {
                      useFureDome = !_needsRunnerSpacer;
                      _syncRunnerStudRules();
                    }
                    _syncBoardOffsets();
                  }),
                ),
                _extraRowsFor('stud'),
                const SizedBox(height: 8),
                _scrollPickBar<String>(
                  label: Ms.of(context).studLen,
                  items: const [
                    '2500',
                    '3000',
                    '3200',
                    '3500',
                    '直接入力',
                  ],
                  value: _studLengthCustom
                      ? '直接入力'
                      : () {
                          final v = double.tryParse(_studLength.text.trim());
                          if (v == null) return '3000';
                          for (final p in _studLengthPresets) {
                            if ((p - v).abs() < 0.5) {
                              return p.toStringAsFixed(0);
                            }
                          }
                          return '直接入力';
                        }(),
                  labelOf: (s) => s == '直接入力' ? Ms.of(context).directInput : '${s}mm',
                  onChanged: (s) => setState(() {
                    if (s == '直接入力') {
                      _studLengthCustom = true;
                    } else {
                      _studLengthCustom = false;
                      _studLength.text = s;
                    }
                    if (useReinforceMaterial && !_reinforceLengthCustom) {
                      final sl = double.tryParse(
                            s == '直接入力'
                                ? _studLength.text.trim()
                                : s,
                          ) ??
                          reinforceLengthMm;
                      if (s != '直接入力') {
                        reinforceLengthMm = sl;
                        _reinforceLength.text = s;
                        _reinforceLengthCustom = false;
                      }
                    }
                  }),
                ),
                if (_studLengthCustom) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _studLength,
                    keyboardType: DoneKeyboard.decimal,
                    inputFormatters: DoneKeyboard.decimalFormatters,
                    textInputAction: DoneKeyboard.action,
                    onSubmitted: DoneKeyboard.onSubmitted,
                    decoration: InputDecoration(
                      labelText: Ms.of(context).studLenDirect,
                      suffixText: 'mm',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (profile == StudProfile.channel)
                  _scrollPickBar<LgsForm>(
                    label: Ms.of(context).studW,
                    items: LgsForm.values,
                    value: form,
                    labelOf: (f) =>
                        '${f.label} ${f.studWidthMm.toStringAsFixed(0)}mm',
                    onChanged: (f) => setState(() {
                      form = f;
                      presetId = null;
                      final extras =
                          BoardSpecParse.namedExtras(_seedLgsCore);
                      final w = f.studWidthMm.toInt().toString();
                      _seedLgsCore = extras.isEmpty
                          ? '$w+'
                          : '$w+${extras.join('+')}';
                      _syncRunnerStudRules();
                      _syncBoardOffsets();
                    }),
                  )
                else
                  _scrollPickBar<SquareStudSize>(
                    label: Ms.of(context).studWSquare,
                    items: SquareStudSize.values,
                    value: squareStud,
                    labelOf: (s) => s.code,
                    onChanged: (s) => setState(() {
                      squareStud = s;
                      presetId = null;
                      form = LgsFormX.fromStudWidth(s.studWidthMm);
                      final extras =
                          BoardSpecParse.namedExtras(_seedLgsCore);
                      final w = s.studWidthMm.toInt().toString();
                      _seedLgsCore = extras.isEmpty
                          ? '$w+'
                          : '$w+${extras.join('+')}';
                      _syncBoardOffsets();
                    }),
                  ),
                const SizedBox(height: 8),
                _scrollPickBar<LgsPitch>(
                  label: Ms.of(context).studPitch,
                  items: const [LgsPitch.p227, LgsPitch.p303, LgsPitch.p455],
                  value: pitch == LgsPitch.p300
                      ? LgsPitch.p303
                      : (pitch == LgsPitch.p450 ? LgsPitch.p455 : pitch),
                  labelOf: (p) {
                    switch (p) {
                      case LgsPitch.p227:
                        return '@227';
                      case LgsPitch.p303:
                      case LgsPitch.p300:
                        return '@303';
                      case LgsPitch.p455:
                      case LgsPitch.p450:
                        return '@455';
                    }
                  },
                  onChanged: (p) => setState(() => pitch = p),
                ),
                if (profile != StudProfile.square) ...[
                  CheckboxListTile(
                    value: useFureDome,
                    onChanged: (v) => setState(() => useFureDome = v ?? true),
                    title: Text(Ms.of(context).nuki),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    secondary: _extraAddButton('fure_dome'),
                  ),
                  if (useFureDome)
                    _pairedScrollRow(
                      leftLabel: Ms.of(context).nukiW,
                      leftPicker: _scrollPickBar<double>(
                        label: Ms.of(context).nukiW,
                        items: _fureDomeWidths,
                        value: _nearestOf(_fureDomeWidths, fureDomeWidthMm),
                        labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                        onChanged: (v) => setState(() {
                          useFureDome = true;
                          fureDomeWidthMm = v;
                        }),
                      ),
                      rightLabel: Ms.of(context).nukiL,
                      rightPicker: _scrollPickBar<double>(
                        label: Ms.of(context).nukiL,
                        items: _fureDomeLengths,
                        value: _nearestOf(_fureDomeLengths, fureDomeLengthMm),
                        labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                        onChanged: (v) => setState(() {
                          useFureDome = true;
                          fureDomeLengthMm = v;
                        }),
                      ),
                    ),
                  _extraRowsFor('fure_dome'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ランナースペーサー',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Checkbox(
                          value: useSpacer,
                          onChanged: (v) =>
                              setState(() => _setUseSpacer(v ?? false)),
                        ),
                      ],
                    ),
                  ),
                  _scrollPickBar<double>(
                    label: Ms.of(context).runnerSpacerType,
                    items: _spacerMms,
                    value: _nearestOf(_spacerMms, runnerSpacerMm),
                    labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                    onChanged: (v) => setState(() => runnerSpacerMm = v),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _sectionTitleInline(Ms.of(context).otherLgs),
              for (var i = 0; i < _otherBeforeGlass.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _wallOtherRow(_otherBeforeGlass, i),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: useGlassWool,
                onChanged: (v) => setState(() => useGlassWool = v ?? false),
                title: Text(Ms.of(context).glassWool),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useGlassWool)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scrollPickBar<int>(
                    label: Ms.of(context).glassWoolDensity,
                    items: _glassWoolKs,
                    value: glassWoolK,
                    labelOf: (k) => '${k}K',
                    onChanged: (v) => setState(() {
                      useGlassWool = true;
                      glassWoolK = v;
                    }),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                Ms.of(context).board,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 8),
              _scrollPickBar<WallSides>(
                label: Ms.of(context).faceLayout,
                items: const [WallSides.both, WallSides.single],
                value: sides,
                labelOf: (s) =>
                    s == WallSides.both ? Ms.of(context).bothSides : Ms.of(context).oneSideA,
                onChanged: (s) => setState(() {
                  sides = s;
                  _syncBoardOffsets();
                }),
              ),
              const SizedBox(height: 10),
              _faceBoardSection(
                title: Ms.of(context).faceA,
                faceEnabled: useBoardFaceA,
                onFaceEnabled: (v) => setState(() {
                  useBoardFaceA = v;
                  useBoard = useBoardFaceA || useBoardFaceB;
                  if (v && _layersA.isEmpty) {
                    _layersA = [12.5];
                    _sizesA = [BoardSize.size36];
                    _boardTotalA = 12.5;
                    _seedStackA = '12.5+';
                  }
                  _syncIronPlateFromFaces();
                  _syncBoardOffsets();
                }),
                nameCtrl: _boardNameA,
                layerMms: _layersA,
                layerSizes: _sizesA,
                onLayersChanged: (v) => _applyLayers(v, faceA: true),
                onSizesChanged: (v) => _applyLayerSizes(v, faceA: true),
                showName: true,
              ),
              if (sides == WallSides.both)
                _faceBoardSection(
                  title: Ms.of(context).faceB,
                  faceEnabled: useBoardFaceB,
                  onFaceEnabled: (v) => setState(() {
                    useBoardFaceB = v;
                    useBoard = useBoardFaceA || useBoardFaceB;
                    if (v && _layersB.isEmpty) {
                      _layersB = [12.5];
                      _sizesB = [BoardSize.size36];
                      _boardTotalB = 12.5;
                      _seedStackB = '12.5+';
                    }
                    _syncIronPlateFromFaces();
                    _syncBoardOffsets();
                  }),
                  nameCtrl: _boardNameB,
                  layerMms: _layersB,
                  layerSizes: _sizesB,
                  onLayersChanged: (v) => _applyLayers(v, faceA: false),
                  onSizesChanged: (v) => _applyLayerSizes(v, faceA: false),
                  showName: true,
                ),
              const SizedBox(height: 6),
              Text(
                Ms.of(context).finishWallThick(
                  finishedCalc.toStringAsFixed(0),
                  runnerW.toStringAsFixed(0),
                  useBoardFaceA || useBoardFaceB,
                ),
                style: const TextStyle(fontSize: 12, color: AppTheme.steel),
              ),
              CheckboxListTile(
                value: useRockFelt,
                onChanged: (v) => setState(() => useRockFelt = v ?? false),
                title: Text(Ms.of(context).rockFelt),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useRockFelt)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scrollPickBar<double>(
                    label: Ms.of(context).rockFeltSize,
                    items: _rockFeltWidths,
                    value: _nearestOf(_rockFeltWidths, rockFeltWidthMm),
                    labelOf: (mm) {
                      final w = mm == mm.roundToDouble()
                          ? mm.toStringAsFixed(0)
                          : mm.toStringAsFixed(1);
                      return Ms.of(context).rockFeltWxL(w);
                    },
                    onChanged: (v) => setState(() {
                      useRockFelt = true;
                      rockFeltWidthMm = v;
                    }),
                    height: 100,
                  ),
                ),
              CheckboxListTile(
                value: useTigerUtight,
                onChanged: (v) =>
                    setState(() => useTigerUtight = v ?? false),
                title: Text(Ms.of(context).tigerU),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useTigerUtight)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scrollPickBar<String>(
                    label: Ms.of(context).tigerUType,
                    items: _tigerTypes,
                    value: tigerUtightType,
                    labelOf: (t) => t == '720'
                        ? Ms.of(context).tiger720jumbo
                        : Ms.of(context).tiger320std,
                    onChanged: (v) => setState(() {
                      useTigerUtight = true;
                      tigerUtightType = v;
                    }),
                    height: 100,
                  ),
                ),
              const SizedBox(height: 8),
              _sectionTitleInline(Ms.of(context).otherBoard),
              for (var i = 0; i < _otherAfterUtight.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _wallOtherRow(_otherAfterUtight, i),
              ],
              const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (widget.ironPlateOnly) {
                    final h = double.tryParse(_height.text.trim()) ??
                        widget.initialHeightMm ??
                        2700;
                    Navigator.pop(
                      context,
                      WallParamsResult(heightMm: h, method: _buildMethod()),
                    );
                    return;
                  }
                  final h = double.tryParse(_height.text.trim());
                  if (h == null || h <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(Ms.of(context).invalidHeight)),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    WallParamsResult(heightMm: h, method: _buildMethod()),
                  );
                },
                child: Text(Ms.of(context).confirmEstimate),
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
        ),
        if (bottom > 0)
          Material(
            color: const Color(0xFFEEF1F5),
            child: SizedBox(
              height: 44,
              width: double.infinity,
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
        SizedBox(height: bottom),
      ],
    );
  }
}

/// 縦スクロール選択（CupertinoPicker）
class _WheelSelect<T> extends StatefulWidget {
  const _WheelSelect({
    required this.items,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> items;
  final T value;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  State<_WheelSelect<T>> createState() => _WheelSelectState<T>();
}

class _WheelSelectState<T> extends State<_WheelSelect<T>> {
  late FixedExtentScrollController _controller;

  int _indexOf(T value) {
    final i = widget.items.indexOf(value);
    if (i >= 0) return i;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: _indexOf(widget.value),
    );
  }

  @override
  void didUpdateWidget(covariant _WheelSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      final next = _indexOf(widget.value);
      _emitted = next;
      _controller.dispose();
      _controller = FixedExtentScrollController(initialItem: next);
      return;
    }
    final next = _indexOf(widget.value);
    if (_controller.hasClients && _controller.selectedItem != next) {
      _emitted = next;
      _controller.jumpToItem(next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _emitted = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification) {
          final i = _controller.hasClients
              ? _controller.selectedItem
              : _indexOf(widget.value);
          if (i >= 0 && i < widget.items.length && i != _emitted) {
            _emitted = i;
            widget.onChanged(widget.items[i]);
          }
        }
        return true;
      },
      child: CupertinoPicker(
        scrollController: _controller,
        backgroundColor: Colors.white,
        itemExtent: 32,
        diameterRatio: 1.2,
        magnification: 1.08,
        squeeze: 1.0,
        useMagnifier: true,
        onSelectedItemChanged: (i) {
          // 値の確定は ScrollEnd で親へ通知（スクロール中の setState を避ける）
        },
        children: [
          for (final e in widget.items)
            Center(
              child: Text(
                widget.labelOf(e),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WallOtherRow {
  _WallOtherRow({
    String name = '',
    String unit = '',
    String quantity = '',
  })  : nameCtrl = TextEditingController(text: name),
        unitCtrl = TextEditingController(text: unit),
        qtyCtrl = TextEditingController(text: quantity);

  factory _WallOtherRow.fromItem(CeilingOtherItem item) => _WallOtherRow(
        name: item.name,
        unit: item.unit,
        quantity: item.quantity == 0 ? '' : item.quantity.toString(),
      );

  final TextEditingController nameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController qtyCtrl;

  String get name => nameCtrl.text;
  String get unit => unitCtrl.text;
  String get quantity => qtyCtrl.text;

  void dispose() {
    nameCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _WallExtraSizeRow {
  _WallExtraSizeRow({
    required this.kind,
    required this.widthMm,
    required this.lengthMm,
    required this.unit,
    String qty = '1',
  }) : qty = TextEditingController(text: qty);

  factory _WallExtraSizeRow.fromItem(ExtraSizedItem e) => _WallExtraSizeRow(
        kind: e.kind,
        widthMm: e.widthMm,
        lengthMm: e.lengthMm,
        unit: e.unit,
        qty: e.qty == e.qty.roundToDouble()
            ? e.qty.toStringAsFixed(0)
            : e.qty.toString(),
      );

  final String kind;
  double widthMm;
  double lengthMm;
  final String unit;
  final TextEditingController qty;

  ExtraSizedItem toItem() => ExtraSizedItem(
        kind: kind,
        widthMm: widthMm,
        lengthMm: lengthMm,
        qty: double.tryParse(qty.text.trim()) ?? 0,
        unit: unit,
      );

  void dispose() {
    qty.dispose();
  }
}
