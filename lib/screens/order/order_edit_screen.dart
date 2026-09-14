import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/pdf_order_exporter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/keyboard_done.dart';

class OrderEditScreen extends StatefulWidget {
  const OrderEditScreen({
    super.key,
    required this.projectId,
    required this.orderId,
  });

  final String projectId;
  final String orderId;

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  MaterialOrder? _order;
  SiteProject? _project;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AppState>().db;
    final orders = await db.listOrders(widget.projectId);
    final order = orders.where((o) => o.id == widget.orderId).firstOrNull;
    final project = await db.getProject(widget.projectId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _project = project;
    });
  }

  Future<void> _editLine(OrderLine line) async {
    final qtyCtrl = TextEditingController(text: line.qty.toString());
    final nameCtrl = TextEditingController(text: line.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).editLineTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: S.of(ctx).itemName)),
            TextField(
              controller: qtyCtrl,
              keyboardType: DoneKeyboard.integer,
              inputFormatters: DoneKeyboard.integerFormatters,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              decoration: InputDecoration(labelText: S.of(ctx).qtyWithUnit(line.unit)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.of(ctx).cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.of(ctx).save)),
        ],
      ),
    );
    if (ok != true || _order == null) return;
    final qty = double.tryParse(qtyCtrl.text.trim());
    if (qty == null) return;
    final lines = _order!.lines
        .map((l) => l.id == line.id
            ? l.copyWith(qty: qty, name: nameCtrl.text.trim())
            : l)
        .toList();
    final updated = MaterialOrder(
      id: _order!.id,
      projectId: _order!.projectId,
      measurementIds: _order!.measurementIds,
      orderDate: _order!.orderDate,
      deliveryDate: _order!.deliveryDate,
      lines: lines,
      createdAt: _order!.createdAt,
    );
    await context.read<AppState>().updateOrder(updated);
    setState(() => _order = updated);
  }

  Future<void> _addManual() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: '個');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).addItemTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: S.of(ctx).addItemNameHint)),
            TextField(
              controller: qtyCtrl,
              keyboardType: DoneKeyboard.integer,
              inputFormatters: DoneKeyboard.integerFormatters,
              textInputAction: DoneKeyboard.action,
              onSubmitted: DoneKeyboard.onSubmitted,
              decoration: InputDecoration(labelText: S.of(ctx).qty),
            ),
            TextField(controller: unitCtrl, decoration: InputDecoration(labelText: S.of(ctx).unit)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.of(ctx).cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.of(ctx).add)),
        ],
      ),
    );
    if (ok != true || _order == null) return;
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
    final line = OrderLine(
      id: context.read<AppState>().newId(),
      name: nameCtrl.text.trim().isEmpty ? '追加材料' : nameCtrl.text.trim(),
      unit: unitCtrl.text.trim().isEmpty ? '個' : unitCtrl.text.trim(),
      qty: qty,
      isManual: true,
    );
    final updated = MaterialOrder(
      id: _order!.id,
      projectId: _order!.projectId,
      measurementIds: _order!.measurementIds,
      orderDate: _order!.orderDate,
      deliveryDate: _order!.deliveryDate,
      lines: [..._order!.lines, line],
      createdAt: _order!.createdAt,
    );
    await context.read<AppState>().updateOrder(updated);
    setState(() => _order = updated);
  }

  Future<void> _confirmExport() async {
    final order = _order;
    final project = _project;
    final user = context.read<AppState>().user;
    if (order == null || project == null || user == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await PdfOrderExporter.build(
        company: user,
        project: project,
        order: order,
      );
      if (!mounted) return;

      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(S.of(ctx).exportOrder)),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(S.of(ctx).shareLineEmail),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.print),
                title: Text(S.of(ctx).printSystemShare),
                onTap: () => Navigator.pop(ctx, 'print'),
              ),
              ListTile(
                leading: const Icon(Icons.preview),
                title: Text(S.of(ctx).preview),
                onTap: () => Navigator.pop(ctx, 'preview'),
              ),
            ],
          ),
        ),
      );

      if (action == 'share') {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/LGS+_注文_${project.name}.pdf');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            subject: '材料注文書 — ${project.name}',
            text: '${project.name} の材料注文書です（LGS+）',
          ),
        );
      } else if (action == 'print') {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else if (action == 'preview') {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(S.of(context).orderPreview)),
              body: PdfPreview(build: (_) async => bytes),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).orderLinesTitle),
        actions: [
          TextButton(
            onPressed: _busy ? null : _confirmExport,
            child: Text(S.of(context).orderConfirm, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add),
        label: Text(S.of(context).addItemTitle),
      ),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.safetyYellow.withValues(alpha: 0.2),
                  child: const Text(
                    '数量は自動積算です。タップで修正できます。追加項目で接着剤・養生材なども補録可能。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: order.lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final line = order.lines[i];
                      return ListTile(
                        title: Text(line.name),
                        subtitle: Text(
                          line.isManual ? '手動追加' : '自動積算',
                          style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                        ),
                        trailing: Text(
                          '${line.qty} ${line.unit}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () => _editLine(line),
                      );
                    },
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
    );
  }
}
