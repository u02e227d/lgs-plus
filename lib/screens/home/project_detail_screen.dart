import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/locale_controller.dart';
import '../../l10n/s_measure.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/app_share.dart';
import '../../services/estimate_builder.dart';
import '../../services/feature_access.dart';
import '../../services/measure_drawing_exporter.dart';
import '../../widgets/mac_list_delete.dart';
import '../drawing/upload_drawing_screen.dart';
import '../measure/estimate_table_screen.dart';
import '../measure/measure_canvas_screen.dart';
import '../order/order_select_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _shareButtonKey = GlobalKey();
  SiteProject? _project;
  List<DrawingFile> _drawings = [];
  List<Measurement> _measurements = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final db = state.db;
    final project = await db.getProject(widget.projectId);
    var drawings = await db.listDrawings(widget.projectId);
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences に残った比例尺を DB へ復元
    final fixed = <DrawingFile>[];
    for (final d in drawings) {
      if (d.scalePxPerMm != null && d.scalePxPerMm! > 0) {
        fixed.add(d);
        continue;
      }
      final k = prefs.getDouble('drawing_scale_${d.id}');
      if (k != null && k > 0) {
        final updated = d.copyWith(scalePxPerMm: k);
        await state.saveDrawing(updated);
        fixed.add(updated);
      } else {
        fixed.add(d);
      }
    }
    drawings = fixed;
    final measurements = await db.listMeasurements(widget.projectId);
    if (!mounted) return;
    setState(() {
      _project = project;
      _drawings = drawings;
      _measurements = measurements;
      _loading = false;
    });
  }

  Future<void> _openSavedEstimate(
    Measurement m,
    EstimateSheetKind kind, {
    String areaLabel = '壁',
  }) async {
    final lines = switch (kind) {
      EstimateSheetKind.board => areaLabel == '天井'
          ? _ceilingBoardLines(m)
          : _wallBoardLines(m),
      EstimateSheetKind.lgs => areaLabel == '天井'
          ? _ceilingLgsLines(m)
          : _wallLgsLines(m),
      EstimateSheetKind.cross => m.crossEstimate,
      EstimateSheetKind.drop => m.dropEstimate,
    };
    if (!await FeatureAccess.requireFullAccess(context)) return;
    if (!mounted || lines.isEmpty) return;
    final hasWalls = m.walls.any((w) => w.estimateReady);
    final hasCeilings = m.ceilings.isNotEmpty;
    final areas = EstimateBuilder.areasFromMeasurement(
      m,
      includeWalls: areaLabel != '天井',
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: '${Ms.of(context).estimateKindTitle(kind.label)} — ${m.name}',
          initialLines: lines,
          projectName: m.name,
          siteAddress: _project?.address,
          sitePhone: _project?.phone,
          siteContact: _project?.contactName,
          areaLabel: kind == EstimateSheetKind.cross
              ? 'クロス'
              : kind == EstimateSheetKind.drop
                  ? '下り'
                  : areaLabel == '天井'
                      ? '天井'
                      : EstimateBuilder.areaLabelFor(
                          hasWalls: hasWalls,
                          hasCeilings: hasCeilings,
                        ),
          areaM2: kind == EstimateSheetKind.drop
              ? null
              : (areas.lgsM2 > 0 ? areas.lgsM2 : null),
          lgsAreaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsMethodLabel: EstimateBuilder.lgsMethodLabel(
            m,
            areaKind: areaLabel == '天井' ? '天井' : '壁',
          ),
          boardAreaM2: areas.boardM2 > 0 ? areas.boardM2 : null,
          boardAreaParts: EstimateBuilder.boardAreasByName(
            m,
            areaKind: areaLabel == '天井' ? '天井' : '壁',
          ),
          rockFeltM: areas.rockFeltM > 0 ? areas.rockFeltM : null,
          glassWoolM2: areas.glassWoolM2 > 0 ? areas.glassWoolM2 : null,
          initialFilter: kind == EstimateSheetKind.drop ? null : kind,
          lockFilter: kind != EstimateSheetKind.drop,
          onSavePersist: (save) async {
            final ceiling = areaLabel == '天井';
            final drop = areaLabel == '下り' ||
                kind == EstimateSheetKind.drop ||
                save.kind == EstimateSheetKind.drop;
            final updated = drop
                ? m.copyWith(
                    dropEstimate:
                        EstimateBuilder.mergeReplacingLineNumbersOfKind(
                      existing: m.dropEstimate,
                      incoming: save.lines,
                      kind: save.kind,
                    ),
                  )
                : switch (save.kind) {
                    EstimateSheetKind.board => ceiling
                        ? m.copyWith(ceilingBoardEstimate: save.lines)
                        : m.copyWith(boardEstimate: save.lines),
                    EstimateSheetKind.lgs => ceiling
                        ? m.copyWith(ceilingLgsEstimate: save.lines)
                        : m.copyWith(lgsEstimate: save.lines),
                    EstimateSheetKind.cross =>
                      m.copyWith(crossEstimate: save.lines),
                    EstimateSheetKind.drop =>
                      m.copyWith(dropEstimate: save.lines),
                  };
            await context.read<AppState>().saveMeasurement(updated);
            await _reload();
          },
        ),
      ),
    );
  }

  List<EstimateLine> _wallBoardLines(Measurement m) =>
      m.boardEstimate.where(EstimateBuilder.isWallAreaKind).toList();

  List<EstimateLine> _wallLgsLines(Measurement m) =>
      m.lgsEstimate.where(EstimateBuilder.isWallAreaKind).toList();

  List<EstimateLine> _ceilingBoardLines(Measurement m) {
    if (m.ceilingBoardEstimate.isNotEmpty) return m.ceilingBoardEstimate;
    return m.boardEstimate
        .where((e) => EstimateBuilder.resolveAreaKind(e) == 'ceiling')
        .toList();
  }

  List<EstimateLine> _ceilingLgsLines(Measurement m) {
    if (m.ceilingLgsEstimate.isNotEmpty) return m.ceilingLgsEstimate;
    return m.lgsEstimate
        .where((e) => EstimateBuilder.resolveAreaKind(e) == 'ceiling')
        .toList();
  }

  Future<bool> _confirmDeleteItem({
    required String title,
    required String name,
  }) {
    final s = S.of(context);
    return MacListDelete.confirm(
      context: context,
      title: title,
      body: s.deleteNamedConfirm(name),
      sheetActionLabel: s.delete,
    );
  }

  Future<void> _deleteDrawing(DrawingFile d) async {
    final s = S.of(context);
    final ok = await _confirmDeleteItem(
      title: s.deleteDrawing,
      name: d.fileName,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().db.deleteDrawing(d.id);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.deletedItem(d.fileName))),
    );
  }

  Future<void> _deleteMeasurement(Measurement m) async {
    final s = S.of(context);
    final ok = await _confirmDeleteItem(
      title: s.deleteMeasure,
      name: m.name,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().db.deleteMeasurement(m.id);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.deletedItem(m.name))),
    );
  }

  Measurement _clearedEstimate(
    Measurement m,
    EstimateSheetKind kind, {
    required String areaLabel,
  }) {
    final ceiling = areaLabel == '天井';
    switch (kind) {
      case EstimateSheetKind.board:
        if (ceiling) {
          return m.copyWith(
            ceilingBoardEstimate: const [],
            boardEstimate: m.boardEstimate
                .where((e) => EstimateBuilder.resolveAreaKind(e) != 'ceiling')
                .toList(),
          );
        }
        return m.copyWith(
          boardEstimate: m.boardEstimate
              .where((e) => !EstimateBuilder.isWallAreaKind(e))
              .toList(),
        );
      case EstimateSheetKind.lgs:
        if (ceiling) {
          return m.copyWith(
            ceilingLgsEstimate: const [],
            lgsEstimate: m.lgsEstimate
                .where((e) => EstimateBuilder.resolveAreaKind(e) != 'ceiling')
                .toList(),
          );
        }
        return m.copyWith(
          lgsEstimate: m.lgsEstimate
              .where((e) => !EstimateBuilder.isWallAreaKind(e))
              .toList(),
        );
      case EstimateSheetKind.cross:
        return m.copyWith(crossEstimate: const []);
      case EstimateSheetKind.drop:
        return m.copyWith(dropEstimate: const []);
    }
  }

  Future<void> _deleteEstimateCard({
    required Measurement m,
    required EstimateSheetKind kind,
    required String title,
    String areaLabel = '壁',
  }) async {
    final s = S.of(context);
    final ok = await _confirmDeleteItem(title: s.delete, name: title);
    if (!ok || !mounted) return;
    final updated = _clearedEstimate(m, kind, areaLabel: areaLabel);
    await context.read<AppState>().saveMeasurement(updated);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.deletedItem(title))),
    );
  }

  Widget _estimateCard({
    required Measurement m,
    required EstimateSheetKind kind,
    required String title,
    required String subtitle,
    required IconData icon,
    String areaLabel = '壁',
  }) {
    final s = S.of(context);
    final tile = ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openSavedEstimate(m, kind, areaLabel: areaLabel),
    );
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Dismissible(
        key: ValueKey('est_${m.id}_${kind.name}_$areaLabel'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => MacListDelete.confirm(
          context: context,
          title: s.delete,
          body: s.deleteNamedConfirm(title),
        ),
        onDismissed: (_) async {
          final updated = _clearedEstimate(m, kind, areaLabel: areaLabel);
          await context.read<AppState>().saveMeasurement(updated);
          await _reload();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.deletedItem(title))),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: AppTheme.danger,
          child: Text(
            s.delete,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child: MacListDelete.wrap(
          onDelete: () => _deleteEstimateCard(
            m: m,
            kind: kind,
            title: title,
            areaLabel: areaLabel,
          ),
          child: tile,
        ),
      ),
    );
  }

  Future<List<Measurement>?> _pickExportMeasurements(
    List<Measurement> candidates,
  ) async {
    final s = S.of(context);
    final groups = <String, List<Measurement>>{};
    for (final m in candidates) {
      groups.putIfAbsent(m.drawingId, () => []).add(m);
    }
    final drawingIds = groups.keys.toList();
    final selected = drawingIds.toSet();

    String titleOf(String drawingId) =>
        _drawings
            .where((d) => d.id == drawingId)
            .map((d) => d.fileName)
            .firstOrNull ??
        drawingId;

    String subtitleOf(String drawingId) =>
        groups[drawingId]!.map((m) => m.name).join(' / ');

    return showDialog<List<Measurement>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s.selectExportDrawings),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setLocal(() {
                            if (selected.length == drawingIds.length) {
                              selected.clear();
                            } else {
                              selected
                                ..clear()
                                ..addAll(drawingIds);
                            }
                          });
                        },
                        child: Text(
                          selected.length == drawingIds.length
                              ? s.deselectAll
                              : s.selectAll,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final id in drawingIds)
                            CheckboxListTile(
                              value: selected.contains(id),
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    selected.add(id);
                                  } else {
                                    selected.remove(id);
                                  }
                                });
                              },
                              title: Text(titleOf(id)),
                              subtitle: Text(subtitleOf(id)),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(s.cancel),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            ctx,
                            [
                              for (final id in drawingIds)
                                if (selected.contains(id)) ...groups[id]!,
                            ],
                          ),
                  child: Text(s.export),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportMeasuredDrawings() async {
    if (!await FeatureAccess.requireFullAccess(context)) return;
    if (!mounted) return;
    final s = S.of(context);
    final project = _project;
    if (project == null) return;
    final candidates =
        _measurements.where(MeasureDrawingExporter.hasContent).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noMeasuredExport)),
      );
      return;
    }
    final targets = await _pickExportMeasurements(candidates);
    if (targets == null || targets.isEmpty || !mounted) return;
    setState(() => _exporting = true);
    try {
      final drawingsById = {for (final d in _drawings) d.id: d};
      final db = context.read<AppState>().db;
      for (final m in targets) {
        if (drawingsById.containsKey(m.drawingId)) continue;
        final extra = await db.getDrawing(m.drawingId);
        if (extra != null) drawingsById[extra.id] = extra;
      }
      if (!mounted) return;
      final bytes = await MeasureDrawingExporter.build(
        project: project,
        measurements: targets,
        drawingsById: drawingsById,
      );
      if (!mounted) return;
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final safe = project.name.replaceAll(RegExp(r'[/\\:\0]'), '_');
      final fileName = 'measure_${safe}_$stamp.pdf';
      final shareCtx = _shareButtonKey.currentContext ?? context;
      final ok = await AppShare.exportBytes(
        context: shareCtx,
        bytes: bytes,
        fileName: fileName,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportFailed)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.exportFailed)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _startMeasure() async {
    final s = S.of(context);
    if (_drawings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.uploadFirst)),
      );
      return;
    }
    DrawingFile drawing = _drawings.first;
    if (_drawings.length > 1) {
      final picked = await showModalBottomSheet<DrawingFile>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(s.selectDrawing)),
              ..._drawings.map(
                (d) => ListTile(
                  leading: Icon(
                    d.kind == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                  ),
                  title: Text(d.fileName),
                  subtitle: Text(
                    d.scalePxPerMm == null
                        ? s.scaleUnset
                        : s.scaleK(d.scalePxPerMm!.toStringAsFixed(4)),
                  ),
                  onTap: () => Navigator.pop(ctx, d),
                ),
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      drawing = picked;
    }

    if (drawing.scalePxPerMm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.scaleFirst)),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.measureName),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            hintText: s.measureNameHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.start),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    final state = context.read<AppState>();
    final m = await state.createMeasurement(
      projectId: widget.projectId,
      drawingId: drawing.id,
      name: nameCtrl.text.trim(),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeasureCanvasScreen(
          measurementId: m.id,
          drawing: drawing,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final project = _project;
    return SafeArea(
      left: true,
      right: true,
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 6, 0),
      child: Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? s.site),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              key: _shareButtonKey,
              tooltip: s.export,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
              ),
              onPressed: _exporting ? null : _exportMeasuredDrawings,
              icon: _exporting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.ios_share, size: 24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.safetyYellow.withValues(alpha: 0.25),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              onPressed: () async {
                if (!await FeatureAccess.requireFullAccess(context)) return;
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderSelectScreen(projectId: widget.projectId),
                  ),
                );
                await _reload();
              },
              child: Text(s.order),
            ),
          ),
        ],
      ),
      body: _loading || project == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(project.address),
                          Text('${project.contactName} / ${project.phone}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!await FeatureAccess.requireUploadSlot(context)) {
                              return;
                            }
                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UploadDrawingScreen(
                                  projectId: widget.projectId,
                                ),
                              ),
                            );
                            await _reload();
                          },
                          icon: const Icon(Icons.upload_file),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(s.uploadDrawing),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startMeasure,
                          icon: const Icon(Icons.straighten),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(s.measure),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.drawings,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_drawings.isEmpty)
                    Text(s.unregistered, style: const TextStyle(color: AppTheme.steel))
                  else
                    ..._drawings.map((d) {
                      return Card(
                        clipBehavior: Clip.hardEdge,
                        child: Dismissible(
                          key: ValueKey('drawing_${d.id}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteItem(
                            title: s.deleteDrawing,
                            name: d.fileName,
                          ),
                          onDismissed: (_) async {
                            await context
                                .read<AppState>()
                                .db
                                .deleteDrawing(d.id);
                            await _reload();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(s.deletedItem(d.fileName)),
                              ),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppTheme.danger,
                            child: Text(
                              s.delete,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          child: MacListDelete.wrap(
                            onDelete: () => _deleteDrawing(d),
                            child: ListTile(
                              leading: Icon(
                                d.kind == 'pdf'
                                    ? Icons.picture_as_pdf
                                    : Icons.image_outlined,
                                color: AppTheme.navy,
                              ),
                              title: Text(d.fileName),
                              subtitle: Text(
                                d.scalePxPerMm == null
                                    ? s.scaleUnsetTap
                                    : s.scaleK(
                                        d.scalePxPerMm!.toStringAsFixed(4),
                                      ),
                              ),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UploadDrawingScreen(
                                      projectId: widget.projectId,
                                      existing: d,
                                    ),
                                  ),
                                );
                                await _reload();
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  Text(
                    s.measureList,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_measurements.isEmpty)
                    Text(s.unmeasured, style: const TextStyle(color: AppTheme.steel))
                  else
                    ..._measurements.expand((m) {
                      final wallN = m.walls.length;
                      final ceilN = m.ceilings.length;
                      final tiles = <Widget>[
                        Card(
                          clipBehavior: Clip.hardEdge,
                          child: Dismissible(
                            key: ValueKey('measurement_${m.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDeleteItem(
                              title: s.deleteMeasure,
                              name: m.name,
                            ),
                            onDismissed: (_) async {
                              await context
                                  .read<AppState>()
                                  .db
                                  .deleteMeasurement(m.id);
                              await _reload();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(s.deletedItem(m.name)),
                                ),
                              );
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppTheme.danger,
                              child: Text(
                                s.delete,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            child: MacListDelete.wrap(
                              onDelete: () => _deleteMeasurement(m),
                              child: ListTile(
                                leading: const Icon(Icons.architecture),
                                title: Text(m.name),
                                subtitle:
                                    Text(s.wallCeilingCount(wallN, ceilN)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final drawing = await context
                                      .read<AppState>()
                                      .db
                                      .getDrawing(m.drawingId);
                                  if (drawing == null || !mounted) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MeasureCanvasScreen(
                                        measurementId: m.id,
                                        drawing: drawing,
                                      ),
                                    ),
                                  );
                                  await _reload();
                                },
                              ),
                            ),
                          ),
                        ),
                      ];

                      if (_wallBoardLines(m).isNotEmpty) {
                        tiles.add(
                          _estimateCard(
                            m: m,
                            kind: EstimateSheetKind.board,
                            title: s.boardEstimateWall(m.name),
                            subtitle:
                                s.estimateLines(_wallBoardLines(m).length),
                            icon: Icons.grid_on,
                            areaLabel: '壁',
                          ),
                        );
                      }
                      if (_ceilingBoardLines(m).isNotEmpty) {
                        tiles.add(
                          _estimateCard(
                            m: m,
                            kind: EstimateSheetKind.board,
                            title: s.boardEstimateCeil(m.name),
                            subtitle: s
                                .estimateLines(_ceilingBoardLines(m).length),
                            icon: Icons.grid_on,
                            areaLabel: '天井',
                          ),
                        );
                      }
                      if (_wallLgsLines(m).isNotEmpty) {
                        tiles.add(
                          _estimateCard(
                            m: m,
                            kind: EstimateSheetKind.lgs,
                            title: s.lgsEstimateWall(m.name),
                            subtitle:
                                s.estimateLines(_wallLgsLines(m).length),
                            icon: Icons.view_column,
                            areaLabel: '壁',
                          ),
                        );
                      }
                      if (_ceilingLgsLines(m).isNotEmpty) {
                        tiles.add(
                          _estimateCard(
                            m: m,
                            kind: EstimateSheetKind.lgs,
                            title: s.lgsEstimateCeil(m.name),
                            subtitle:
                                s.estimateLines(_ceilingLgsLines(m).length),
                            icon: Icons.view_column,
                            areaLabel: '天井',
                          ),
                        );
                      }
                      if (m.crossEstimate.isNotEmpty) {
                        tiles.add(
                          _estimateCard(
                            m: m,
                            kind: EstimateSheetKind.cross,
                            title: s.crossEstimate(m.name),
                            subtitle:
                                s.estimateLines(m.crossEstimate.length),
                            icon: Icons.wallpaper,
                          ),
                        );
                      }
                      if (m.dropEstimate.isNotEmpty) {
                        tiles.add(
                          _estimateCard(
                            m: m,
                            kind: EstimateSheetKind.drop,
                            title: s.dropEstimate(m.name),
                            subtitle:
                                s.estimateLines(m.dropEstimate.length),
                            icon: Icons.vertical_align_bottom,
                          ),
                        );
                      }
                      return tiles;
                    }),
                ],
              ),
            ),
    ),
    );
  }
}
