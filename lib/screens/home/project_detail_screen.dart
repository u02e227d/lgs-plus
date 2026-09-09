import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/estimate_builder.dart';
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
  SiteProject? _project;
  List<DrawingFile> _drawings = [];
  List<Measurement> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final db = context.read<AppState>().db;
    final project = await db.getProject(widget.projectId);
    final drawings = await db.listDrawings(widget.projectId);
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
    EstimateSheetKind kind,
  ) async {
    final lines =
        kind == EstimateSheetKind.board ? m.boardEstimate : m.lgsEstimate;
    if (lines.isEmpty) return;
    final hasWalls = m.walls.any((w) => w.estimateReady);
    final hasCeilings = m.ceilings.isNotEmpty;
    final areas = EstimateBuilder.areasFromMeasurement(m);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateTableScreen(
          title: '${kind.label} — ${m.name}',
          initialLines: lines,
          projectName: _project?.name,
          siteAddress: _project?.address,
          sitePhone: _project?.phone,
          siteContact: _project?.contactName,
          areaLabel: EstimateBuilder.areaLabelFor(
            hasWalls: hasWalls,
            hasCeilings: hasCeilings,
          ),
          areaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          lgsAreaM2: areas.lgsM2 > 0 ? areas.lgsM2 : null,
          boardAreaM2: areas.boardM2 > 0 ? areas.boardM2 : null,
          rockFeltM: areas.rockFeltM > 0 ? areas.rockFeltM : null,
          glassWoolM2: areas.glassWoolM2 > 0 ? areas.glassWoolM2 : null,
          initialFilter: kind,
          lockFilter: true,
          onSavePersist: (save) async {
            final updated = save.kind == EstimateSheetKind.board
                ? m.copyWith(boardEstimate: save.lines)
                : m.copyWith(lgsEstimate: save.lines);
            await context.read<AppState>().saveMeasurement(updated);
            await _reload();
          },
        ),
      ),
    );
  }

  Future<void> _startMeasure() async {
    if (_drawings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に図面をアップロードしてください')),
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
              const ListTile(title: Text('測定する図面を選択')),
              ..._drawings.map(
                (d) => ListTile(
                  leading: Icon(
                    d.kind == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                  ),
                  title: Text(d.fileName),
                  subtitle: Text(
                    d.scalePxPerMm == null
                        ? 'スケール未設定'
                        : 'K=${d.scalePxPerMm!.toStringAsFixed(4)} px/mm',
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
        const SnackBar(content: Text('先に比例尺（スケール）を設定してください')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('測定プロジェクト名'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            hintText: '例：1F 飲食エリア 壁と天井積算',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('開始'),
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
    final project = _project;
    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? '現場'),
        actions: [
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
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderSelectScreen(projectId: widget.projectId),
                  ),
                );
                await _reload();
              },
              child: const Text('注文'),
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
                          label: const Text('図面アップロード'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startMeasure,
                          icon: const Icon(Icons.straighten),
                          label: const Text('測定'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '図面',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_drawings.isEmpty)
                    const Text('未登録', style: TextStyle(color: AppTheme.steel))
                  else
                    ..._drawings.map((d) {
                      return Card(
                        clipBehavior: Clip.hardEdge,
                        child: Dismissible(
                          key: ValueKey('drawing_${d.id}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            final action = await showModalBottomSheet<String>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.danger,
                                      ),
                                      title: const Text('削除'),
                                      onTap: () => Navigator.pop(ctx, 'delete'),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.close),
                                      title: const Text('キャンセル'),
                                      onTap: () =>
                                          Navigator.pop(ctx, 'cancel'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (action != 'delete') return false;
                            if (!mounted) return false;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('図面を削除'),
                                content: Text(
                                  '「${d.fileName}」を削除しますか？',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('キャンセル'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.danger,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('削除する'),
                                  ),
                                ],
                              ),
                            );
                            return ok == true;
                          },
                          onDismissed: (_) async {
                            await context
                                .read<AppState>()
                                .db
                                .deleteDrawing(d.id);
                            await _reload();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('「${d.fileName}」を削除しました')),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppTheme.danger,
                            child: const Text(
                              '削除',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
                                  ? 'スケール未設定 → タップして設定'
                                  : 'スケール K=${d.scalePxPerMm!.toStringAsFixed(4)} px/mm',
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
                      );
                    }),
                  const SizedBox(height: 20),
                  const Text(
                    '測定一覧',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_measurements.isEmpty)
                    const Text('未測定', style: TextStyle(color: AppTheme.steel))
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
                            confirmDismiss: (direction) async {
                              final action = await showModalBottomSheet<String>(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.delete_outline,
                                          color: AppTheme.danger,
                                        ),
                                        title: const Text('削除'),
                                        onTap: () =>
                                            Navigator.pop(ctx, 'delete'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.close),
                                        title: const Text('キャンセル'),
                                        onTap: () =>
                                            Navigator.pop(ctx, 'cancel'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (action != 'delete') return false;
                              if (!mounted) return false;
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('測定を削除'),
                                  content: Text('「${m.name}」を削除しますか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('キャンセル'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.danger,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('削除する'),
                                    ),
                                  ],
                                ),
                              );
                              return ok == true;
                            },
                            onDismissed: (_) async {
                              await context
                                  .read<AppState>()
                                  .db
                                  .deleteMeasurement(m.id);
                              await _reload();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('「${m.name}」を削除しました')),
                              );
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppTheme.danger,
                              child: const Text(
                                '削除',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.architecture),
                              title: Text(m.name),
                              subtitle: Text('壁 $wallN / 天井 $ceilN'),
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
                      ];

                      if (m.boardEstimate.isNotEmpty) {
                        tiles.add(
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.grid_on),
                              title: Text('ボード試算表 — ${m.name}'),
                              subtitle: Text('明細 ${m.boardEstimate.length} 行'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openSavedEstimate(
                                m,
                                EstimateSheetKind.board,
                              ),
                            ),
                          ),
                        );
                      }
                      if (m.lgsEstimate.isNotEmpty) {
                        tiles.add(
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.view_column),
                              title: Text('LGS試算表 — ${m.name}'),
                              subtitle: Text('明細 ${m.lgsEstimate.length} 行'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openSavedEstimate(
                                m,
                                EstimateSheetKind.lgs,
                              ),
                            ),
                          ),
                        );
                      }
                      return tiles;
                    }),
                ],
              ),
            ),
    );
  }
}
