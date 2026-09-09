import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/estimate_builder.dart';
import '../theme/app_theme.dart';

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
    this.boardAreaM2,
    this.rockFeltM,
    this.glassWoolM2,
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
  /// 壁 / 天井
  final String areaLabel;
  /// 平米数（互換・未使用時は LGS/ボードに分解表示）
  final double? areaM2;
  /// LGS 下地面積 (㎡)
  final double? lgsAreaM2;
  /// 石膏ボード面積 (㎡)＝壁面積×層数（両面なら合算）
  final double? boardAreaM2;
  /// ロックフェルト総延長 (m)
  final double? rockFeltM;
  /// グラスウール総面積 (㎡)
  final double? glassWoolM2;
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
            name: e.name,
            spec: e.spec,
            lw: e.lw,
            lengthMm: e.lengthMm,
            qty: e.qty,
            unit: e.unit,
            subtotal: e.subtotal,
            wastePercent: e.wastePercent,
            note: '',
            wallHeightMm: e.wallHeightMm,
            wallLineNumber: e.wallLineNumber,
            wallLineColorArgb: e.wallLineColorArgb,
          ),
        )
        .toList();
    _filter = widget.initialFilter;
    _lines = _visibleLines();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  List<EstimateLine> _visibleLines() {
    if (_filter == null) return List<EstimateLine>.from(_allLines);
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
        const SnackBar(
          content: Text('「ボードのみ表示」または「LGSのみ表示」を選んでから保存してください'),
        ),
      );
      return;
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
          content: Text('${result.kind.label}を保存しました'),
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
  String _areaKindLabel(String raw) {
    final t = raw.trim();
    if (t == '天井' || t.startsWith('天井')) return '天井';
    if (t == '壁' || t.startsWith('壁')) return '壁';
    if (t.contains('天井') && t.contains('壁')) return '壁/天井';
    return t.isEmpty ? '壁' : t;
  }

  String _fmtArea(double? m2) {
    if (m2 == null) return '—';
    return m2 == m2.roundToDouble()
        ? m2.toStringAsFixed(0)
        : m2.toStringAsFixed(2);
  }

  Widget _areaMetersBlock() {
    final lgs = widget.lgsAreaM2;
    final board = widget.boardAreaM2;
    final rock = widget.rockFeltM;
    final gw = widget.glassWoolM2;
    final hasSplit = (lgs != null && lgs > 0) || (board != null && board > 0);
    if (!hasSplit) {
      return Text(
        '平米数　${_fmtArea(widget.areaM2)}　㎡',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    Widget cell(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.navy.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$label　$value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        cell('LGS', '${_fmtArea(lgs)}㎡'),
        cell(
          'ボード',
          '${_fmtArea(board)}㎡'
          '${(board != null && lgs != null && lgs > 0 && board > lgs + 0.01) ? '（層数×面）' : ''}',
        ),
        if (rock != null && rock > 0) cell('ロックフェルト', '${_fmtArea(rock)}m'),
        if (gw != null && gw > 0) cell('グラスウール', '${_fmtArea(gw)}㎡'),
      ],
    );
  }

  String _sizeOf(EstimateLine e) {
    if (e.lw.isNotEmpty) return e.lw;
    if (e.lengthMm > 0) return e.lengthMm.toStringAsFixed(0);
    return '';
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
      inputFormatters: keyboard ==
              const TextInputType.numberWithOptions(decimal: true)
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
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
    final dateFmt = DateFormat('yyyy年M月d日');
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        actions: [
          if (widget.editable && !widget.lockFilter) ...[
            TextButton(
              onPressed: () => _applyFilter(EstimateSheetKind.board),
              child: Text(
                'ボードのみ表示',
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
                'LGSのみ表示',
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
                child: const Text(
                  'すべて',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
          TextButton(
            onPressed: widget.editable ? _save : () => Navigator.pop(context),
            child: Text(
              widget.editable ? '保存' : '閉じる',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView.builder(
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
    );
  }

  Widget _buildPage({
    required int pageIndex,
    required int start,
    required int end,
    required DateFormat dateFmt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pageIndex > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '— ${pageIndex + 1} 枚目 —',
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
                    ? '表示: ボードのみ（${_lines.length}件）'
                    : _filter == EstimateSheetKind.lgs
                        ? '表示: LGSのみ（${_lines.length}件）'
                        : '表示: すべて（${_lines.length}件）',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.steel,
                ),
              ),
            ),
            const Text(
              '試算表',
              style: TextStyle(
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
                    const Text(
                      '日付',
                      style: TextStyle(
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
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  color: Colors.white,
                  child: Text(
                    _areaKindLabel(widget.areaLabel),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
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
                  _headerCell('プロジェクト名', flex: 2),
                  _headerCell('品名', flex: 3),
                  _headerCell('サイズ', width: 56),
                  _headerCell('仕様', flex: 3),
                  _headerCell('単位', width: 44),
                  _headerCell('数量', width: 52),
                  _headerCell('ロス率％', width: 68),
                  _headerCell('合計', flex: 2),
                ],
              ),
              if (_lines.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: _gridLine, width: 0.8),
                  ),
                  child: const Text('明細がありません', textAlign: TextAlign.center),
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

    return IntrinsicHeight(
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
              initial: e.spec,
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
              keyboard: const TextInputType.numberWithOptions(decimal: true),
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
              keyboard: const TextInputType.numberWithOptions(decimal: true),
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
  }
}
