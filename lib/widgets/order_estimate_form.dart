import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_lang.dart';
import '../l10n/locale_controller.dart';
import '../l10n/s_measure.dart';
import '../models/models.dart';
import '../services/estimate_builder.dart';
import '../theme/app_theme.dart';
import 'keyboard_done.dart';
import 'mac_list_delete.dart';

/// 試算表レイアウト（横画面固定・複数ページ）
class OrderEstimateForm extends StatefulWidget {
  const OrderEstimateForm({
    super.key,
    required this.lines,
    required this.editable,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
    this.appBarTitle = '試算表',
    this.areaLabel = '壁',
    this.areaM2,
    this.lgsAreaM2,
    this.lgsMethodLabel,
    this.boardAreaM2,
    this.boardAreaParts = const [],
    this.rockFeltM,
    this.glassWoolM2,
    this.dropLengthMm,
    this.dropWidthMm,
    this.dropHeightMm,
    this.dropShapeLabel,
    this.dropTurnWidths = const [],
    this.initialFilter,
    this.lockFilter = false,
    this.onSavePersist,
  });

  final List<EstimateLine> lines;
  final bool editable;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;
  final String appBarTitle;
  /// 壁 / 天井 / 下り
  final String areaLabel;
  /// 平米数（互換・未使用時は LGS/ボードに分解表示）
  final double? areaM2;
  /// LGS 下地面積 (㎡)
  final double? lgsAreaM2;
  /// LGS 工法（SQ工法 / 在来工法 / コの字45 等）
  final String? lgsMethodLabel;
  /// 石膏ボード面積 (㎡)＝壁面積×層数（両面なら合算）
  final double? boardAreaM2;
  /// 品名ごとのボード面積
  final List<({String name, double m2})> boardAreaParts;
  /// ロックフェルト総延長 (m)
  final double? rockFeltM;
  /// グラスウール総面積 (㎡)
  final double? glassWoolM2;
  final double? dropLengthMm;
  final double? dropWidthMm;
  final double? dropHeightMm;
  final String? dropShapeLabel;
  final List<DropTurnWidth> dropTurnWidths;
  /// 初期フィルタ（保存済み表を開くとき）
  final EstimateSheetKind? initialFilter;
  /// フィルタ切替不可（保存済み単票）
  final bool lockFilter;
  /// 指定時は保存しても画面を閉じず、ここで永続化する
  final Future<void> Function(EstimateSaveResult result)? onSavePersist;

  @override
  State<OrderEstimateForm> createState() => _OrderEstimateFormState();
}

class _OrderEstimateFormState extends State<OrderEstimateForm> {
  /// Excel 試算表1枚あたりの明細行数
  static const _rowsPerPage = 17;

  late DateTime _issueDate;
  late List<EstimateLine> _allLines;
  late List<EstimateLine> _lines;
  EstimateSheetKind? _filter;

  static const _kCompany = 'order_est_company';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final now = DateTime.now();
    _issueDate = DateTime(now.year, now.month, now.day);
    _allLines = widget.lines
        .map(
          (e) => EstimateLine(
            id: e.id,
            name: EstimateBuilder.catalogItemName(e.name),
            spec: e.spec,
            lw: e.lw,
            lengthMm: e.lengthMm,
            qty: e.qty,
            unit: e.unit,
            subtotal: e.subtotal,
            wastePercent: e.wastePercent,
            note: e.note,
            wallHeightMm: e.wallHeightMm,
            wallLineNumber: e.wallLineNumber,
            wallLineColorArgb: e.wallLineColorArgb,
            areaKind: e.areaKind.isNotEmpty
                ? e.areaKind
                : EstimateBuilder.resolveAreaKind(e),
          ),
        )
        .toList();
    _filter = widget.initialFilter;
    _lines = _visibleLines();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  List<EstimateLine> _visibleLines() {
    if (_filter == null) return List<EstimateLine>.from(_allLines);
    // クロス専用など単票で渡された行は、再分類で落とさない
    if (widget.lockFilter) return List<EstimateLine>.from(_allLines);
    return EstimateBuilder.filterByKind(_allLines, _filter!);
  }

  void _applyFilter(EstimateSheetKind? kind) {
    if (widget.lockFilter) return;
    setState(() {
      _filter = kind;
      if (kind == null) {
        _lines = List<EstimateLine>.from(_allLines);
      } else if (kind == EstimateSheetKind.board) {
        _lines = _allLines.where(EstimateBuilder.isBoardLine).toList();
      } else if (kind == EstimateSheetKind.cross) {
        _lines = _allLines.where(EstimateBuilder.isCrossLine).toList();
      } else if (kind == EstimateSheetKind.drop) {
        _lines = _allLines.where(EstimateBuilder.isDropLine).toList();
      } else {
        _lines = _allLines.where(EstimateBuilder.isLgsLine).toList();
      }
    });
  }

  bool _showLineBadge(int index, int pageStart) {
    if (index < 0 || index >= _lines.length) return false;
    if (index == pageStart) return true;
    return _lines[index].wallLineNumber != _lines[index - 1].wallLineNumber;
  }

  Color _lineBadgeColor(EstimateLine e) {
    final argb = e.wallLineColorArgb;
    if (argb == null) return AppTheme.navy;
    return Color(argb);
  }

  Future<void> _save() async {
    if (_filter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Ms.of(context).pickKindFirst),
        ),
      );
      return;
    }
    for (final e in _lines) {
      e.name = EstimateBuilder.catalogItemName(e.name);
    }
    final result = EstimateSaveResult(
      kind: _filter!,
      lines: List.from(_lines),
    );
    final persist = widget.onSavePersist;
    if (persist != null) {
      await persist(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Ms.of(context).savedKind(
            Ms.of(context).estimateKindTitle(result.kind.label),
          )),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pop(context, result);
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    p.getString(_kCompany);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _pickIssueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _issueDate = d);
  }

  String _fmtNum(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  /// 合計 = 数量×(1+ロス率/100) を切り上げた整数
  int _qtyTotalInt(EstimateLine e) {
    final v = e.qty * (1 + e.wastePercent / 100.0);
    if (v <= 0) return 0;
    return v.ceil();
  }

  /// 画ペンに対応：壁マウス→「壁」、天井マウス→「天井」
  String _areaKindLabel(String raw) => Ms.of(context).displayArea(raw);

  String _fmtArea(double? m2) {
    if (m2 == null) return '—';
    return m2 == m2.roundToDouble()
        ? m2.toStringAsFixed(0)
        : m2.toStringAsFixed(2);
  }

  Widget _areaMetersBlock() {
    if (_filter == EstimateSheetKind.drop ||
        (widget.dropLengthMm != null && widget.dropLengthMm! > 0)) {
      final L = widget.dropLengthMm ?? 0;
      final W = widget.dropWidthMm ?? 0;
      final H = widget.dropHeightMm ?? 0;
      final shape = Ms.of(context).displayDropShape(widget.dropShapeLabel ?? '下り');
      final widthParts = <String>[
        if (W > 0) '${dropWidthCircleLabel(1)} ${W.round()} mm',
        for (final t in widget.dropTurnWidths)
          if (t.widthMm > 0)
            '${dropWidthCircleLabel(t.turnIndex)} ${t.widthMm.round()} mm',
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shape,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${Ms.of(context).dropLenH} ${L.round()} mm　${Ms.of(context).height} ${H.round()} mm',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (widthParts.isNotEmpty)
            Text(
              widthParts.join('　'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          Text(
            '${widthParts.length > 1 ? Ms.of(context).dropAreaMulti : Ms.of(context).dropAreaSimple}　${_fmtArea(widget.areaM2)} ㎡',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    final lgs = widget.lgsAreaM2;
    final board = widget.boardAreaM2;
    final rock = widget.rockFeltM;
    final gw = widget.glassWoolM2;
    final hasSplit = (lgs != null && lgs > 0) || (board != null && board > 0);
    if (!hasSplit) {
      return Text(
        Ms.of(context).areaSq(_fmtArea(widget.areaM2)),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    Widget cell(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.navy.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          softWrap: false,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final ms = Ms.of(context);
    final method = ms.displayMethod((widget.lgsMethodLabel ?? '').trim());
    final lgsText = method.isEmpty
        ? 'LGS　${_fmtArea(lgs)}㎡'
        : 'LGS　$method　${_fmtArea(lgs)}㎡';
    final boards = widget.boardAreaParts.where((e) => e.m2 > 0).toList();

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        if (lgs != null && lgs > 0) cell(lgsText),
        if (boards.isNotEmpty)
          for (final b in boards) cell('${b.name}　${_fmtArea(b.m2)}㎡')
        else if (board != null && board > 0)
          cell(
            '${ms.board}　${_fmtArea(board)}㎡'
            '${(lgs != null && lgs > 0 && board > lgs + 0.01) ? ms.layersTimesFaces : ''}',
          ),
        if (rock != null && rock > 0) cell('${ms.rockFelt}　${_fmtArea(rock)}m'),
        if (gw != null && gw > 0) cell('${ms.glassWool}　${_fmtArea(gw)}㎡'),
      ],
    );
  }

  String _sizeOf(EstimateLine e) {
    if (e.lw.isNotEmpty) return e.lw;
    if (e.lengthMm > 0) return e.lengthMm.toStringAsFixed(0);
    return '';
  }

  /// クロス試算表では仕様に「クロス専用」を出さない
  String _displaySpec(EstimateLine e) {
    var s = e.spec.trim();
    if (_filter == EstimateSheetKind.cross ||
        EstimateBuilder.isCrossLine(e)) {
      s = s.replaceFirst(RegExp(r'^クロス専用[・･\s]*'), '');
    }
    return s;
  }

  /// ページ先頭、または直前行と線番号が違うときだけ表示
  bool _showProjectName(int index, int pageStart) {
    return _showLineBadge(index, pageStart);
  }

  static const _gridLine = Color(0xFF5A6470);

  Widget _headerCell(String text, {int flex = 1, double? width}) {
    final child = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        border: Border.all(color: _gridLine, width: 0.8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex, child: child);
  }

  Widget _dataCell({
    required Widget child,
    int flex = 1,
    double? width,
    Color? fill,
  }) {
    final box = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: fill ?? Colors.white,
        border: Border.all(color: _gridLine, width: 0.8),
      ),
      child: child,
    );
    if (width != null) return SizedBox(width: width, child: box);
    return Expanded(flex: flex, child: box);
  }

  Widget _input({
    required String initial,
    required ValueChanged<String> onChanged,
    TextAlign align = TextAlign.left,
    TextInputType? keyboard,
    TextEditingController? controller,
    bool enabled = true,
    Key? fieldKey,
  }) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: enabled ? Colors.black87 : Colors.transparent,
    );
    if (controller != null) {
      return TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        textAlign: align,
        style: style,
        keyboardType: keyboard,
        textInputAction: DoneKeyboard.action,
        onSubmitted: DoneKeyboard.onSubmitted,
        inputFormatters: keyboard != null
            ? DoneKeyboard.decimalFormatters
            : null,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        ),
        onChanged: onChanged,
      );
    }
    // initialValue は初回のみ有効なため、行切替時は Key で State を破棄する
    return TextFormField(
      key: fieldKey ?? ValueKey(initial),
      initialValue: initial,
      enabled: enabled,
      textAlign: align,
      style: style,
      keyboardType: keyboard,
      textInputAction: DoneKeyboard.action,
      onFieldSubmitted: DoneKeyboard.onSubmitted,
      inputFormatters: keyboard != null
          ? DoneKeyboard.decimalFormatters
          : null,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      ),
      onChanged: onChanged,
    );
  }

  int get _pageCount {
    if (_lines.isEmpty) return 1;
    return ((_lines.length - 1) ~/ _rowsPerPage) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final ms = Ms.of(context);
    final s = S.of(context);
    final dateFmt = DateFormat(ms.datePattern(), switch (ms.lang) {
      AppLang.ja => 'ja',
      AppLang.en => 'en',
      AppLang.zh => 'zh',
      AppLang.vi => 'vi',
    });
    return SafeArea(
      left: true,
      right: true,
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(6, 0, 14, 0),
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        actions: [
          if (widget.editable && !widget.lockFilter) ...[
            TextButton(
              onPressed: () => _applyFilter(EstimateSheetKind.board),
              child: Text(
                ms.boardOnlyView,
                style: TextStyle(
                  color: _filter == EstimateSheetKind.board
                      ? AppTheme.safetyYellow
                      : Colors.white,
                  fontWeight: _filter == EstimateSheetKind.board
                      ? FontWeight.w900
                      : FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _applyFilter(EstimateSheetKind.lgs),
              child: Text(
                ms.lgsOnlyView,
                style: TextStyle(
                  color: _filter == EstimateSheetKind.lgs
                      ? AppTheme.safetyYellow
                      : Colors.white,
                  fontWeight: _filter == EstimateSheetKind.lgs
                      ? FontWeight.w900
                      : FontWeight.w600,
                ),
              ),
            ),
            if (_filter != null)
              TextButton(
                onPressed: () => _applyFilter(null),
                child: Text(
                  ms.allItems,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
          TextButton(
            onPressed: widget.editable ? _save : () => Navigator.pop(context),
            child: Text(
              widget.editable ? ms.save : s.close,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: KeyboardDoneScope(
        child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _pageCount,
        itemBuilder: (context, page) {
          final start = page * _rowsPerPage;
          final end = (_lines.length < start + _rowsPerPage)
              ? _lines.length
              : start + _rowsPerPage;
          return Padding(
            padding: EdgeInsets.only(bottom: page < _pageCount - 1 ? 28 : 0),
            child: _buildPage(
              pageIndex: page,
              start: start,
              end: end,
              dateFmt: dateFmt,
            ),
          );
        },
      ),
      ),
    ),
    );
  }

  Widget _buildPage({
    required int pageIndex,
    required int start,
    required int end,
    required DateFormat dateFmt,
  }) {
    final ms = Ms.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pageIndex > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              ms.pageN(pageIndex + 1),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.steel,
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                _filter == EstimateSheetKind.board
                    ? ms.viewBoard(_lines.length)
                    : _filter == EstimateSheetKind.lgs
                        ? ms.viewLgs(_lines.length)
                        : _filter == EstimateSheetKind.cross
                            ? ms.viewCross(_lines.length)
                            : ms.viewAll(_lines.length),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.steel,
                ),
              ),
            ),
            Text(
              _filter == EstimateSheetKind.cross
                  ? ms.estimateCross
                  : _filter == EstimateSheetKind.drop
                      ? ms.estimateDrop
                      : ms.estimate,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: AppTheme.navy,
              ),
            ),
            const Spacer(flex: 2),
            InkWell(
              onTap: _pickIssueDate,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ms.date,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFmt.format(_issueDate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.navy.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                child: Text(
                  EstimateBuilder.placeLabel(
                    widget.projectName ?? '',
                    _areaKindLabel(widget.areaLabel),
                  ),
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.navy.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: _areaMetersBlock(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _gridLine, width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _headerCell('No', width: 36),
                  _headerCell(ms.projectName, flex: 2),
                  _headerCell(
                    _filter == EstimateSheetKind.cross ? ms.nameOrCode : ms.itemName,
                    flex: 3,
                  ),
                  _headerCell(ms.size, width: 56),
                  _headerCell(ms.spec, flex: 3),
                  _headerCell(ms.unit, width: 44),
                  _headerCell(ms.qty, width: 52),
                  _headerCell(ms.wastePct, width: 68),
                  _headerCell(ms.total, flex: 2),
                ],
              ),
              if (_lines.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: _gridLine, width: 0.8),
                  ),
                  child: Text(ms.noLines, textAlign: TextAlign.center),
                )
              else
                for (var i = start; i < end; i++)
                  _lineRow(i, pageStart: start),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lineRow(int i, {required int pageStart}) {
    final e = _lines[i];
    final showProject = _showProjectName(i, pageStart);
    final fill = i.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    // フィルタ切替で行が入れ替わっても古い TextFormFieldを再利用しない
    final rowKey = '$_filter-${e.id}-$i-${e.name}-${e.spec}-${e.lw}';

    final row = IntrinsicHeight(
      key: ValueKey(rowKey),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dataCell(
            width: 36,
            fill: fill,
            child: Text(
              '${i + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _dataCell(
            flex: 2,
            fill: fill,
            child: showProject
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: () {
                              final base = (widget.projectName ?? '').trim();
                              final circled = EstimateLine.circledLineNumber(
                                e.wallLineNumber,
                              );
                              if (base.isEmpty) return '';
                              return circled.isEmpty ? base : '$base ';
                            }(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (e.wallLineNumber > 0)
                            TextSpan(
                              text: EstimateLine.circledLineNumber(
                                e.wallLineNumber,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: _lineBadgeColor(e),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          _dataCell(
            flex: 3,
            fill: fill,
            child: _input(
              fieldKey: ValueKey('$rowKey-name'),
              initial: e.name,
              onChanged: (v) => e.name = v,
            ),
          ),
          _dataCell(
            width: 56,
            fill: fill,
            child: _input(
              fieldKey: ValueKey('$rowKey-size'),
              initial: _sizeOf(e),
              align: TextAlign.center,
              onChanged: (v) {
                e.lw = v;
                final n = double.tryParse(v);
                if (n != null) e.lengthMm = n;
              },
            ),
          ),
          _dataCell(
            flex: 3,
            fill: fill,
            child: _input(
              fieldKey: ValueKey('$rowKey-spec'),
              initial: _displaySpec(e),
              onChanged: (v) => e.spec = v,
            ),
          ),
          _dataCell(
            width: 44,
            fill: fill,
            child: _input(
              fieldKey: ValueKey('$rowKey-unit'),
              initial: e.unit,
              align: TextAlign.center,
              onChanged: (v) => e.unit = v,
            ),
          ),
          _dataCell(
            width: 52,
            fill: fill,
            child: _input(
              fieldKey: ValueKey('$rowKey-qty'),
              initial: _fmtNum(e.qty),
              align: TextAlign.right,
              keyboard: DoneKeyboard.decimal,
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null) {
                  setState(() {
                    e.qty = n;
                    if (e.lengthMm > 0) {
                      e.subtotal = (e.lengthMm / 1000.0) * e.qty;
                    } else {
                      e.subtotal = e.qty;
                    }
                  });
                }
              },
            ),
          ),
          _dataCell(
            width: 68,
            fill: fill,
            child: _input(
              fieldKey: ValueKey('$rowKey-waste'),
              initial: _fmtNum(e.wastePercent),
              align: TextAlign.right,
              keyboard: DoneKeyboard.decimal,
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null) setState(() => e.wastePercent = n);
              },
            ),
          ),
          _dataCell(
            flex: 2,
            fill: fill,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${_qtyTotalInt(e)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.editable || !MacListDelete.isMac) return row;

    return MacListDelete.wrap(
      onDelete: () async {
        final ms = Ms.of(context);
        final s = S.of(context);
        final label = e.name.trim().isEmpty ? 'No.${i + 1}' : e.name.trim();
        final ok = await MacListDelete.confirm(
          context: context,
          title: ms.deleteRow,
          body: s.deleteNamedConfirm(label),
          sheetActionLabel: ms.deleteRow,
        );
        if (!ok || !mounted) return;
        setState(() => _lines.removeAt(i));
      },
      child: row,
    );
  }
}
