import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/estimate_builder.dart';
import 'order_document_screen.dart';

class _OrderPick {
  _OrderPick({
    required this.measurementId,
    required this.kind,
    required this.name,
    required this.lines,
  });
  final String measurementId;
  final EstimateSheetKind kind;
  final String name;
  final List<EstimateLine> lines;

  String get key => '$measurementId:${kind.name}';
  String get title => '${kind.label} — $name';
}

class OrderSelectScreen extends StatefulWidget {
  const OrderSelectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<OrderSelectScreen> createState() => _OrderSelectScreenState();
}

class _OrderSelectScreenState extends State<OrderSelectScreen> {
  SiteProject? _project;
  List<_OrderPick> _picks = [];
  final Set<String> _selected = {};
  DateTime _delivery = DateTime.now().add(const Duration(days: 3));
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AppState>().db;
    final project = await db.getProject(widget.projectId);
    final items = await db.listMeasurements(widget.projectId);
    final picks = <_OrderPick>[];
    for (final m in items) {
      if (m.boardEstimate.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.board,
          name: m.name,
          lines: m.boardEstimate,
        ));
      }
      if (m.lgsEstimate.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.lgs,
          name: m.name,
          lines: m.lgsEstimate,
        ));
      }
    }
    if (!mounted) return;
    setState(() {
      _project = project;
      _picks = picks;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _delivery,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _delivery = d);
  }

  Future<void> _next() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注文する試算表を選択してください')),
      );
      return;
    }
    final state = context.read<AppState>();
    final selected = _picks.where((p) => _selected.contains(p.key)).toList();
    final kinds = selected.map((e) => e.kind).toSet();
    if (kinds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ボード試算表と LGS試算表は分けて注文してください'),
        ),
      );
      return;
    }
    final kind = selected.first.kind;
    final raw = <EstimateLine>[];
    for (final p in selected) {
      raw.addAll(p.lines);
    }
    final lines = EstimateBuilder.mergeForOrderDocument(
      raw,
      idGen: () => state.newId(),
    );
    if (lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択した試算表に明細がありません')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDocumentScreen(
          lines: lines,
          projectName: _project?.name,
          siteAddress: _project?.address,
          sitePhone: _project?.phone,
          siteContact: _project?.contactName,
          areaLabel: kind.shortLabel,
          areaM2: null,
          appBarTitle: '注文書（${kind.label}）',
          deliveryDate: _delivery,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd');
    return Scaffold(
      appBar: AppBar(title: const Text('注文 — 試算表選択')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_project != null)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _project!.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text('${_project!.contactName} / ${_project!.phone}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('発注日：${fmt.format(DateTime.now())}'),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.event),
                              label: Text(
                                '納品希望 ${fmt.format(_delivery)}',
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'ボード試算表と LGS試算表は別々に選択できます',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.steel,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _picks.isEmpty
                      ? const Center(
                          child: Text(
                            '保存済みのボード／LGS試算表がありません\n'
                            '測定で試算表を開き、ボードのみ／LGSのみ表示して保存してください',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _picks.length,
                          itemBuilder: (context, i) {
                            final p = _picks[i];
                            final sel = _selected.contains(p.key);
                            return CheckboxListTile(
                              value: sel,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selected.add(p.key);
                                  } else {
                                    _selected.remove(p.key);
                                  }
                                });
                              },
                              secondary: Icon(
                                p.kind == EstimateSheetKind.board
                                    ? Icons.grid_on
                                    : Icons.view_column,
                                color: p.kind == EstimateSheetKind.board
                                    ? AppTheme.navy
                                    : AppTheme.accent,
                              ),
                              title: Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${p.kind.shortLabel} · 明細 ${p.lines.length} 行',
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: const Text('注文書へ'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
