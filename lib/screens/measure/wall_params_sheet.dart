import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../services/board_spec_parse.dart';
import '../../services/lgs_catalog.dart';
import '../../theme/app_theme.dart';

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
    this.measuredCornerCount = 0,
  });

  final double? initialHeightMm;
  final WallMethod? initialMethod;
  final double? measuredLengthMm;
  final int measuredCornerCount;

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
  bool useIronPlate = false;
  bool _ironPlateFromMaterial = false;
  double ironPlateWidthMm = 300;
  double ironPlateLengthMm = 1820;
  int ironPlateSegments = 0;
  bool useReinforceMaterial = false;
  double reinforceWidthMm = 45;
  double reinforceLengthMm = 3000;
  late final TextEditingController _studLength;
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
    final seed = widget.initialMethod;
    if (seed != null) {
      _applyInitialMethod(seed);
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
    _ironPlateFromMaterial = m.useIronPlate;
    ironPlateWidthMm =
        _nearestOf(_ironPlateWidths, m.ironPlateWidthMm);
    ironPlateLengthMm =
        _nearestOf(_ironPlateLengths, m.ironPlateLengthMm);
    final seg = m.ironPlateSegments;
    ironPlateSegments = (seg >= 2 && seg <= 7) ? seg : 0;
    useIronPlate = m.useIronPlate;
    useReinforceMaterial = m.useReinforceMaterial;
    reinforceWidthMm = m.reinforceWidthMm > 0
        ? LgsFormX.fromStudWidth(m.reinforceWidthMm).studWidthMm
        : m.studWidthMm;
    reinforceLengthMm = m.reinforceLengthMm > 0
        ? _nearestOf(_studLengthPresets, m.reinforceLengthMm)
        : _nearestOf(
            _studLengthPresets,
            m.studLengthMm > 0
                ? m.studLengthMm
                : (widget.initialHeightMm ?? 3000),
          );
    runnerSpacerMm = _nearestOf(const [10.0, 15.0, 25.0], m.runnerSpacerMm);
    runnerWidthMm = m.runnerWidthMm > 0 ? m.runnerWidthMm : m.studWidthMm;
    runnerWidthMm = LgsFormX.fromStudWidth(runnerWidthMm).studWidthMm;
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

    detectedThickness =
        m.studWidthMm + _boardTotalA + (m.bothSides ? _boardTotalB : 0);

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
    if (m.useIronPlate && !m.useLgs) {
      _applyIronPlateOnlyMode();
      _syncSummary = [
        '線番号の材料寸法から同期（鉄板のみ）',
        '壁高 ${(widget.initialHeightMm ?? 2700).toStringAsFixed(0)} mm',
        '鉄板 幅${ironPlateWidthMm.toStringAsFixed(0)}×長${ironPlateLengthMm.toStringAsFixed(0)}',
        if (ironPlateSegments >= 2) '${ironPlateSegments}段',
      ].join(' ／ ');
    } else {
      _autoCheckRockFelt();
      _syncRunnerStudRules();
      if (_ironPlateFromMaterial && !useBoardFaceA && !useBoardFaceB) {
        useIronPlate = true;
      }
    }
  }

  /// 鉄板のみ：他オプションをすべてオフ／空
  void _applyIronPlateOnlyMode() {
    useLgs = false;
    useBoard = false;
    useBoardFaceA = false;
    useBoardFaceB = false;
    useCross = false;
    useSpacer = false;
    useFureDome = false;
    useRockFelt = false;
    useTigerUtight = false;
    useGlassWool = false;
    useIronPlate = true;
    _layersA = [];
    _layersB = [];
    _sizesA = [];
    _sizesB = [];
    _seedStackA = '';
    _seedStackB = '';
    _boardTotalA = 0;
    _boardTotalB = 0;
    _waste.text = '0';
    detectedThickness = 0;
  }

  /// ランナー幅＞スタッド幅のとき：スペーサーON・振れ止めOFF・ロックフェルト/UタイトON
  void _syncRunnerStudRules() {
    if (profile == StudProfile.square) return;
    if (!_needsRunnerSpacer) return;
    useSpacer = true;
    useFureDome = false;
    useRockFelt = true;
    useTigerUtight = true;
  }

  void _setUseSpacer(bool v) {
    useSpacer = v;
    if (v) {
      useRockFelt = true;
      useTigerUtight = true;
    }
  }

  void _syncIronPlateFromFaces() {
    if (_ironPlateFromMaterial && !useBoardFaceA && !useBoardFaceB && !useLgs) {
      _applyIronPlateOnlyMode();
    } else if (_ironPlateFromMaterial && !useBoardFaceA && !useBoardFaceB) {
      useIronPlate = true;
    }
  }

  Widget _ironPlateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '鉄板',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Checkbox(
                value: useIronPlate,
                onChanged: (v) => setState(() {
                  final on = v ?? false;
                  useIronPlate = on;
                  if (on && _ironPlateFromMaterial) {
                    _applyIronPlateOnlyMode();
                  }
                }),
              ),
            ],
          ),
        ),
        if (useIronPlate)
          _pairedScrollRow(
            leftLabel: '幅',
            leftPicker: _scrollPickBar<double>(
              label: '幅',
              items: _ironPlateWidths,
              value: _nearestOf(_ironPlateWidths, ironPlateWidthMm),
              labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
              onChanged: (v) => setState(() {
                useIronPlate = true;
                ironPlateWidthMm = v;
              }),
            ),
            rightLabel: '長さ',
            rightPicker: _scrollPickBar<double>(
              label: '長さ',
              items: _ironPlateLengths,
              value: _nearestOf(_ironPlateLengths, ironPlateLengthMm),
              labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
              onChanged: (v) => setState(() {
                useIronPlate = true;
                ironPlateLengthMm = v;
              }),
            ),
          ),
      ],
    );
  }

  Widget _reinforceMaterialSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '補強材',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Checkbox(
                value: useReinforceMaterial,
                onChanged: (v) => setState(() {
                  useReinforceMaterial = v ?? false;
                  if (useReinforceMaterial) {
                    final studW = profile == StudProfile.square
                        ? squareStud.studWidthMm
                        : form.studWidthMm;
                    reinforceWidthMm =
                        LgsFormX.fromStudWidth(studW).studWidthMm;
                    final sl = double.tryParse(_studLength.text.trim());
                    if (sl != null && sl > 0) {
                      reinforceLengthMm =
                          _nearestOf(_studLengthPresets, sl);
                    }
                  }
                }),
              ),
            ],
          ),
        ),
        if (useReinforceMaterial)
          _pairedScrollRow(
            leftLabel: '幅',
            leftPicker: _scrollPickBar<double>(
              label: '幅',
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
            rightLabel: '長さ',
            rightPicker: _scrollPickBar<double>(
              label: '長さ',
              items: _studLengthPresets,
              value: _nearestOf(_studLengthPresets, reinforceLengthMm),
              labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
              onChanged: (v) => setState(() {
                useReinforceMaterial = true;
                reinforceLengthMm = v;
              }),
            ),
          ),
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
    final stud = profile == StudProfile.square
        ? squareStud.studWidthMm
        : form.studWidthMm;
    detectedThickness = stud +
        (useBoardFaceA ? _boardTotalA : 0) +
        (useBoardFaceB && sides == WallSides.both ? _boardTotalB : 0);
  }

  @override
  void dispose() {
    _height.dispose();
    _waste.dispose();
    _boardNameA.dispose();
    _boardNameB.dispose();
    _studLength.dispose();
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
      useCross: useCross,
      crossWasteRate: (double.tryParse(_waste.text.trim()) ?? 10) / 100.0,
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
      useIronPlate: useIronPlate,
      ironPlateWidthMm: ironPlateWidthMm,
      ironPlateLengthMm: ironPlateLengthMm,
      ironPlateSegments: ironPlateSegments,
      useReinforceMaterial: useReinforceMaterial,
      reinforceWidthMm: reinforceWidthMm,
      reinforceLengthMm: reinforceLengthMm,
      presetId: null,
      detectedWallThicknessMm: detectedThickness,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD0D5DD)),
          ),
          child: _WheelSelect<T>(
            items: items,
            value: value,
            labelOf: labelOf,
            onChanged: onChanged,
          ),
        ),
      ],
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
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '名称入力',
                    labelText: 'ボード名称',
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
                label: const Text('厚さを追加'),
              ),
            )
          else
          for (var i = 0; i < layerMms.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _scrollPickBar<double>(
                    label: '厚さ（${i + 1}層）',
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
                    label: 'サイズ（${i + 1}層）',
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
                  label: const Text('層を追加'),
                ),
                if (layerMms.length > 1)
                  TextButton.icon(
                    onPressed: () => onLayersChanged(
                      layerMms.sublist(0, layerMms.length - 1),
                    ),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('層を削除'),
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
    final studW = profile == StudProfile.square
        ? squareStud.studWidthMm
        : form.studWidthMm;
    final finishedCalc = studW +
        (useBoardFaceA ? _boardTotalA : 0) +
        (useBoardFaceB && sides == WallSides.both ? _boardTotalB : 0);

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
                '壁工法選択（JIS A 6517）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (_syncSummary != null) ...[
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
              const SizedBox(height: 12),
              TextField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '壁高さ H (mm)',
                  hintText: '2700',
                  helperText: '50形は2.7m以下、65/75形は4.0m以下が目安',
                ),
              ),
              if (widget.measuredLengthMm != null) ...[
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
                      const Text(
                        '測定値',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '壁長 ${(widget.measuredLengthMm! / 1000).toStringAsFixed(3)} m'
                        '（${widget.measuredLengthMm!.toStringAsFixed(0)} mm）',
                      ),
                      if (widget.measuredCornerCount > 0)
                        Text('曲がり角 ${widget.measuredCornerCount}（各LGS 3本）'),
                      if (detectedThickness != null)
                        Text(
                          '壁厚 ${detectedThickness!.toStringAsFixed(0)} mm',
                        ),
                      Builder(
                        builder: (_) {
                          final h =
                              double.tryParse(_height.text.trim()) ?? 2700;
                          final area = (widget.measuredLengthMm! / 1000) *
                              (h / 1000);
                          return Text('壁面積（概算） ${area.toStringAsFixed(2)} m²');
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _ironPlateSection(),
              const SizedBox(height: 8),
              _reinforceMaterialSection(),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: useLgs,
                onChanged: (v) => setState(() => useLgs = v ?? true),
                title: const Text('LGS 下地'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useLgs) ...[
                _pairedScrollRow(
                  leftLabel: 'ランナー幅',
                  leftPicker: _scrollPickBar<double>(
                    label: 'ランナー幅',
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
                  rightLabel: 'ランナー長さ',
                  rightPicker: _scrollPickBar<double>(
                    label: 'ランナー長さ',
                    items: _runnerLengths,
                    value: _nearestOf(_runnerLengths, runnerLengthMm),
                    labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                    onChanged: (v) => setState(() => runnerLengthMm = v),
                  ),
                ),
                _scrollPickBar<StudProfile>(
                  label: 'スタッド種別',
                  items: const [StudProfile.channel, StudProfile.square],
                  value: profile,
                  labelOf: (p) =>
                      p == StudProfile.channel ? 'コの字型' : '角スタッド',
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
                const SizedBox(height: 8),
                _scrollPickBar<String>(
                  label: 'スタッド長さ',
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
                  labelOf: (s) => s == '直接入力' ? '直接入力' : '${s}mm',
                  onChanged: (s) => setState(() {
                    if (s == '直接入力') {
                      _studLengthCustom = true;
                    } else {
                      _studLengthCustom = false;
                      _studLength.text = s;
                    }
                  }),
                ),
                if (_studLengthCustom) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _studLength,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'スタッド長さ（直接入力）',
                      suffixText: 'mm',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (profile == StudProfile.channel)
                  _scrollPickBar<LgsForm>(
                    label: 'スタッド幅',
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
                    label: 'スタッド幅（角スタッド型番）',
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
                  label: 'スタッド間隔',
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
                    title: const Text('振れ止め'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (useFureDome)
                    _pairedScrollRow(
                      leftLabel: '振れ止め幅',
                      leftPicker: _scrollPickBar<double>(
                        label: '振れ止め幅',
                        items: _fureDomeWidths,
                        value: _nearestOf(_fureDomeWidths, fureDomeWidthMm),
                        labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                        onChanged: (v) => setState(() {
                          useFureDome = true;
                          fureDomeWidthMm = v;
                        }),
                      ),
                      rightLabel: '振れ止め長さ',
                      rightPicker: _scrollPickBar<double>(
                        label: '振れ止め長さ',
                        items: _fureDomeLengths,
                        value: _nearestOf(_fureDomeLengths, fureDomeLengthMm),
                        labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                        onChanged: (v) => setState(() {
                          useFureDome = true;
                          fureDomeLengthMm = v;
                        }),
                      ),
                    ),
                  CheckboxListTile(
                    value: useGlassWool,
                    onChanged: (v) =>
                        setState(() => useGlassWool = v ?? false),
                    title: const Text('グラスウール'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (useGlassWool)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _scrollPickBar<int>(
                        label: 'グラスウール密度',
                        items: _glassWoolKs,
                        value: glassWoolK,
                        labelOf: (k) => '${k}K',
                        onChanged: (v) => setState(() {
                          useGlassWool = true;
                          glassWoolK = v;
                        }),
                      ),
                    ),
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
                  if (_needsRunnerSpacer)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'スタッド幅 ＜ ランナー幅のため自動選択（スタッド本数×2）',
                        style: TextStyle(fontSize: 11, color: AppTheme.steel),
                      ),
                    ),
                  _scrollPickBar<double>(
                    label: 'ランナースペーサー種別',
                    items: _spacerMms,
                    value: _nearestOf(_spacerMms, runnerSpacerMm),
                    labelOf: (mm) => '${mm.toStringAsFixed(0)}mm',
                    onChanged: (v) => setState(() => runnerSpacerMm = v),
                  ),
                ] else ...[
                  CheckboxListTile(
                    value: useGlassWool,
                    onChanged: (v) =>
                        setState(() => useGlassWool = v ?? false),
                    title: const Text('グラスウール'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (useGlassWool)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _scrollPickBar<int>(
                        label: 'グラスウール密度',
                        items: _glassWoolKs,
                        value: glassWoolK,
                        labelOf: (k) => '${k}K',
                        onChanged: (v) => setState(() {
                          useGlassWool = true;
                          glassWoolK = v;
                        }),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 8),
              const Text(
                'ボード',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 8),
              _scrollPickBar<WallSides>(
                label: '面構成',
                items: const [WallSides.both, WallSides.single],
                value: sides,
                labelOf: (s) =>
                    s == WallSides.both ? '両面' : '片面（A面のみ）',
                onChanged: (s) => setState(() {
                  sides = s;
                  _syncBoardOffsets();
                }),
              ),
              const SizedBox(height: 10),
              _faceBoardSection(
                title: 'A面ボード',
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
                  title: 'B面ボード',
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
                '仕上壁厚 約 ${finishedCalc.toStringAsFixed(0)}mm'
                '（スタッド${studW.toStringAsFixed(0)}'
                '${(useBoardFaceA || useBoardFaceB) ? ' + ボード' : ''}）',
                style: const TextStyle(fontSize: 12, color: AppTheme.steel),
              ),
              CheckboxListTile(
                value: useRockFelt,
                onChanged: (v) => setState(() => useRockFelt = v ?? false),
                title: const Text('ロックフェルト'),
                subtitle: const Text(
                  'Z・強化・ハイパー・スーパー／厚さ21mmで自動選択',
                  style: TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useRockFelt)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scrollPickBar<double>(
                    label: 'ロックフェルト寸法',
                    items: _rockFeltWidths,
                    value: _nearestOf(_rockFeltWidths, rockFeltWidthMm),
                    labelOf: (mm) {
                      final w = mm == mm.roundToDouble()
                          ? mm.toStringAsFixed(0)
                          : mm.toStringAsFixed(1);
                      return '幅${w}mm×長さ1000mm';
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
                title: const Text('タイガーUタイト'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useTigerUtight)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _scrollPickBar<String>(
                    label: 'タイガーUタイト種類',
                    items: _tigerTypes,
                    value: tigerUtightType,
                    labelOf: (t) => t == '720'
                        ? '720ml15本入りジャンボタイプ'
                        : '320ml30本入りスタンダードタイプ',
                    onChanged: (v) => setState(() {
                      useTigerUtight = true;
                      tigerUtightType = v;
                    }),
                    height: 100,
                  ),
                ),
              CheckboxListTile(
                value: useCross,
                onChanged: (v) => setState(() => useCross = v ?? false),
                title: const Text('クロス（壁紙）'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (useCross)
                TextField(
                  controller: _waste,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ロス率 (%)',
                    hintText: '10',
                    helperText: '門幅 0.9m 想定',
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final h = double.tryParse(_height.text.trim());
                  if (h == null || h <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('高さを正しく入力してください')),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    WallParamsResult(heightMm: h, method: _buildMethod()),
                  );
                },
                child: const Text('積算確定'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppTheme.steel),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final next = _indexOf(widget.value);
    if (_controller.hasClients && _controller.selectedItem != next) {
      _controller.jumpToItem(next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return CupertinoPicker(
      scrollController: _controller,
      itemExtent: 32,
      magnification: 1.08,
      squeeze: 1.1,
      useMagnifier: true,
      onSelectedItemChanged: (i) {
        if (i < 0 || i >= widget.items.length) return;
        widget.onChanged(widget.items[i]);
      },
      children: [
        for (final e in widget.items)
          Center(
            child: Text(
              widget.labelOf(e),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
