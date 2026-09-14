import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
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
    this.areaLabel = '',
  });
  final String measurementId;
  final EstimateSheetKind kind;
  final String name;
  final List<EstimateLine> lines;
  final String areaLabel;

  String get key => '$measurementId:${kind.name}:$areaLabel';
  String get title {
    if (areaLabel.isEmpty) return '${kind.label} — $name';
    return '${kind.label}（$areaLabel）— $name';
  }
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
    List<EstimateLine> wallBoard(Measurement m) =>
        m.boardEstimate.where(EstimateBuilder.isWallAreaKind).toList();
    List<EstimateLine> wallLgs(Measurement m) =>
        m.lgsEstimate.where(EstimateBuilder.isWallAreaKind).toList();
    List<EstimateLine> ceilBoard(Measurement m) =>
        m.ceilingBoardEstimate.isNotEmpty
            ? m.ceilingBoardEstimate
            : m.boardEstimate
                .where((e) => EstimateBuilder.resolveAreaKind(e) == 'ceiling')
                .toList();
    List<EstimateLine> ceilLgs(Measurement m) => m.ceilingLgsEstimate.isNotEmpty
        ? m.ceilingLgsEstimate
        : m.lgsEstimate
            .where((e) => EstimateBuilder.resolveAreaKind(e) == 'ceiling')
            .toList();

    for (final m in items) {
      final wb = wallBoard(m);
      if (wb.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.board,
          name: m.name,
          lines: wb,
          areaLabel: '壁',
        ));
      }
      final cb = ceilBoard(m);
      if (cb.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.board,
          name: m.name,
          lines: cb,
          areaLabel: '天井',
        ));
      }
      final wl = wallLgs(m);
      if (wl.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.lgs,
          name: m.name,
          lines: wl,
          areaLabel: '壁',
        ));
      }
      final cl = ceilLgs(m);
      if (cl.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.lgs,
          name: m.name,
          lines: cl,
          areaLabel: '天井',
        ));
      }
      if (m.crossEstimate.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.cross,
          name: m.name,
          lines: m.crossEstimate,
        ));
      }
      final dropBoard = EstimateBuilder.dropBoardLines(m.dropEstimate);
      if (dropBoard.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.board,
          name: m.name,
          lines: dropBoard,
          areaLabel: '下り',
        ));
      }
      final dropLgs = EstimateBuilder.dropLgsLines(m.dropEstimate);
      if (dropLgs.isNotEmpty) {
        picks.add(_OrderPick(
          measurementId: m.id,
          kind: EstimateSheetKind.lgs,
          name: m.name,
          lines: dropLgs,
          areaLabel: '下り',
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
        SnackBar(content: Text(S.of(context).pickEstimateToOrder)),
      );
      return;
    }
    final state = context.read<AppState>();
    final selected = _picks.where((p) => _selected.contains(p.key)).toList();
    final kinds = selected.map((e) => e.kind).toSet();
    if (kinds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).splitBoardLgsOrder),
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
    for (final e in lines) {
      e.note = '';
    }
    if (lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).selectedEstimateEmpty)),
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
          appBarTitle: '注文書',
          deliveryDate: _delivery,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd');
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).orderSelectTitle)),
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
                            Text(S.of(context).orderDateLabel(fmt.format(DateTime.now()))),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.event),
                              label: Text(
                                S.of(context).deliveryWish(fmt.format(_delivery)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          S.of(context).orderSelectHint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.steel,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _picks.isEmpty
                      ? Center(
                          child: Text(
                            S.of(context).noSavedEstimates,
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
                                switch (p.kind) {
                                  EstimateSheetKind.board => Icons.grid_on,
                                  EstimateSheetKind.lgs => Icons.view_column,
                                  EstimateSheetKind.cross => Icons.wallpaper,
                                  EstimateSheetKind.drop => Icons.vertical_align_bottom,
                                },
                                color: switch (p.kind) {
                                  EstimateSheetKind.board => AppTheme.navy,
                                  EstimateSheetKind.lgs => AppTheme.accent,
                                  EstimateSheetKind.cross =>
                                    const Color(0xFF1E6BD6),
                                  EstimateSheetKind.drop =>
                                    const Color(0xFF6A1B9A),
                                },
                              ),
                              title: Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${Ms.of(context).displaySheetKind(p.kind.shortLabel)} · ${S.of(context).estimateLines(p.lines.length)}',
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
                        child: Text(S.of(context).goOrderDoc),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
