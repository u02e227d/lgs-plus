import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

/// Numbers「注文書」レイアウト（プロジェクト名・ロス率％なし）
class OrderDocumentScreen extends StatefulWidget {
  const OrderDocumentScreen({
    super.key,
    required this.lines,
    this.projectName,
    this.siteAddress,
    this.sitePhone,
    this.siteContact,
    this.areaLabel = '壁',
    this.areaM2,
    this.appBarTitle = '注文書',
    this.deliveryDate,
  });

  final List<EstimateLine> lines;
  final String? projectName;
  final String? siteAddress;
  final String? sitePhone;
  final String? siteContact;
  final String areaLabel;
  final double? areaM2;
  final String appBarTitle;
  final DateTime? deliveryDate;

  @override
  State<OrderDocumentScreen> createState() => _OrderDocumentScreenState();
}

class _OrderDocumentScreenState extends State<OrderDocumentScreen> {
  static const _grid = Color(0xFF333333);
  static const _kCustomer = 'order_doc_customer';
  static const _rowsPerPage = 28;

  late DateTime _issueDate;
  late DateTime _deliveryDate;
  late final TextEditingController _customer;
  late final TextEditingController _siteAddress;
  late final TextEditingController _receiver;
  late final TextEditingController _sitePhone;
  late final TextEditingController _companyName;
  late final TextEditingController _companyAddress;
  late final TextEditingController _companyPhone;
  late final TextEditingController _orderNo;
  late List<EstimateLine> _lines;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final now = DateTime.now();
    _issueDate = DateTime(now.year, now.month, now.day);
    final d = widget.deliveryDate ?? now.add(const Duration(days: 3));
    _deliveryDate = DateTime(d.year, d.month, d.day);
    _customer = TextEditingController();
    _siteAddress = TextEditingController(text: widget.siteAddress ?? '');
    _receiver = TextEditingController(text: widget.siteContact ?? '');
    _sitePhone = TextEditingController(text: widget.sitePhone ?? '');
    _companyName = TextEditingController();
    _companyAddress = TextEditingController();
    _companyPhone = TextEditingController();
    _orderNo = TextEditingController();
    _lines = widget.lines
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
            note: e.note,
          ),
        )
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCustomer = prefs.getString(_kCustomer) ?? '';
    if (!mounted) return;
    AppUser? user;
    try {
      user = context.read<AppState>().user;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (savedCustomer.isNotEmpty) _customer.text = savedCustomer;
      _companyName.text = user?.companyName ?? '';
      _companyAddress.text = user?.address ?? '';
      _companyPhone.text = user?.phone ?? '';
    });
  }

  Future<void> _persistCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCustomer, _customer.text.trim());
  }

  @override
  void dispose() {
    _persistCustomer();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _customer.dispose();
    _siteAddress.dispose();
    _receiver.dispose();
    _sitePhone.dispose();
    _companyName.dispose();
    _companyAddress.dispose();
    _companyPhone.dispose();
    _orderNo.dispose();
    super.dispose();
  }

  Future<void> _pickIssue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _issueDate = d);
  }

  Future<void> _pickDelivery() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _deliveryDate = d);
  }

  String _fmtNum(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  String _sizeOf(EstimateLine e) {
    if (e.lw.isNotEmpty) return e.lw;
    if (e.lengthMm > 0) return e.lengthMm.toStringAsFixed(0);
    return '';
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
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
        _header(dateFmt),
        const SizedBox(height: 14),
        _table(start: start, end: end),
      ],
    );
  }

  Widget _header(DateFormat dateFmt) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const Text(
              '注文書',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 160,
                  child: Row(
                    children: [
                      const Text(
                        'No.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _orderNo,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: UnderlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customer,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '取引先名（履歴あり）',
                            border: UnderlineInputBorder(),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          onChanged: (_) => _persistCustomer(),
                        ),
                      ),
                      const Text(
                        '　様',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '下記の通り注文申し上げます。',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  _labeledField('現場住所', _siteAddress),
                  _labeledField('受取者', _receiver),
                  _labeledField('電話番号', _sitePhone),
                  _dateRow(
                    '納期希望日',
                    dateFmt.format(_deliveryDate),
                    _pickDelivery,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dateRow('発行日', dateFmt.format(_issueDate), _pickIssue),
                  _labeledField('会社名', _companyName),
                  _labeledField('住所', _companyAddress, prefix: '〒 '),
                  _labeledField('電話番号', _companyPhone),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController ctrl, {
    String prefix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          if (prefix.isNotEmpty)
            Text(prefix, style: const TextStyle(fontSize: 12)),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table({required int start, required int end}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _grid, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _h('No', width: 36),
              _h('品名', flex: 3),
              _h('サイズ', width: 64),
              _h('仕様', flex: 3),
              _h('単位', width: 44),
              _h('数量', width: 56),
              _h('合計', width: 56),
              _h('備考', flex: 2),
            ],
          ),
          if (_lines.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: const Text('明細がありません', textAlign: TextAlign.center),
            )
          else
            for (var i = start; i < end; i++) _row(i),
          // 空行でページを埋める
          for (var i = end - start; i < _rowsPerPage; i++)
            _emptyRow(start + i),
        ],
      ),
    );
  }

  Widget _h(String t, {int flex = 1, double? width}) {
    final child = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F4),
        border: Border.all(color: _grid, width: 0.7),
      ),
      child: Text(
        t,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex, child: child);
  }

  Widget _cell({
    required Widget child,
    int flex = 1,
    double? width,
    Color fill = Colors.white,
  }) {
    final box = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: _grid, width: 0.6),
      ),
      child: child,
    );
    if (width != null) return SizedBox(width: width, child: box);
    return Expanded(flex: flex, child: box);
  }

  Widget _row(int i) {
    final e = _lines[i];
    final fill = i.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    final qtyText = _fmtNum(e.qty);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(
            width: 36,
            fill: fill,
            child: Text(
              '${i + 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          _cell(
            flex: 3,
            fill: fill,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _cell(
            width: 64,
            fill: fill,
            child: Text(
              _sizeOf(e),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          _cell(
            flex: 3,
            fill: fill,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e.spec,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          _cell(
            width: 44,
            fill: fill,
            child: Text(
              e.unit,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          _cell(
            width: 56,
            fill: fill,
            child: Text(
              qtyText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          _cell(
            width: 56,
            fill: fill,
            child: Text(
              qtyText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          _cell(
            flex: 2,
            fill: fill,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.steel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRow(int i) {
    final fill = i.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(width: 36, fill: fill, child: const SizedBox(height: 22)),
          _cell(flex: 3, fill: fill, child: const SizedBox(height: 22)),
          _cell(width: 64, fill: fill, child: const SizedBox(height: 22)),
          _cell(flex: 3, fill: fill, child: const SizedBox(height: 22)),
          _cell(width: 44, fill: fill, child: const SizedBox(height: 22)),
          _cell(width: 56, fill: fill, child: const SizedBox(height: 22)),
          _cell(width: 56, fill: fill, child: const SizedBox(height: 22)),
          _cell(flex: 2, fill: fill, child: const SizedBox(height: 22)),
        ],
      ),
    );
  }
}
