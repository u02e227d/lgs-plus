import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/app_platform.dart';
import '../../services/app_share.dart';
import '../../services/pdf_order_exporter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mac_list_delete.dart';
import 'order_document_screen.dart';

/// 注文書の送信履历（タップで内容表示・共有ボタン・左スワイプ／デスクトップ右クリック削除）
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderHistoryEntry> _items = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await context.read<AppState>().db.listOrderHistory(widget.projectId);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _openEntry(OrderHistoryEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDocumentScreen.fromHistory(entry),
      ),
    );
  }

  Future<void> _share(OrderHistoryEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final meta = entry.meta;
      final bytes = await PdfOrderExporter.buildOrderDocument(
        title: entry.title,
        customer: '${meta['customer'] ?? ''}',
        siteName: '${meta['siteName'] ?? ''}',
        siteAddress: '${meta['siteAddress'] ?? ''}',
        receiver: '${meta['receiver'] ?? ''}',
        sitePhone: '${meta['sitePhone'] ?? ''}',
        companyName: '${meta['companyName'] ?? ''}',
        companyAddress: '${meta['companyAddress'] ?? ''}',
        companyPhone: '${meta['companyPhone'] ?? ''}',
        orderNo: '${meta['orderNo'] ?? ''}',
        issueDateLabel: '${meta['issueDateLabel'] ?? entry.dateLabel}',
        deliveryDateLabel: '${meta['deliveryDateLabel'] ?? ''}',
        lines: entry.lines,
      );
      if (!mounted) return;
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final name = ('${meta['projectName'] ?? meta['siteName'] ?? 'order'}')
          .replaceAll(RegExp(r'[/\\:\0]'), '_');
      final ok = await AppShare.exportBytes(
        context: context,
        bytes: bytes,
        fileName: 'order_${name}_$stamp.pdf',
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).exportFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDelete(OrderHistoryEntry entry) {
    final s = S.of(context);
    return MacListDelete.confirmDialogOnly(
      context: context,
      title: s.orderHistoryDeleteTitle,
      body: s.orderHistoryDeleteBody,
    );
  }

  Future<void> _delete(OrderHistoryEntry entry) async {
    await context.read<AppState>().db.deleteOrderHistory(entry.id);
    if (!mounted) return;
    setState(() => _items = _items.where((e) => e.id != entry.id).toList());
  }

  Future<void> _macDelete(OrderHistoryEntry entry) async {
    final ok = await _confirmDelete(entry);
    if (!ok || !mounted) return;
    await _delete(entry);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.orderHistoryTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.orderHistoryEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.steel, height: 1.5),
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (AppPlatform.usesDesktopPointer)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.macDeleteHint,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.steel,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = _items[i];
                          return Dismissible(
                            key: ValueKey(e.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: AppTheme.danger,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) => _confirmDelete(e),
                            onDismissed: (_) => _delete(e),
                            child: MacListDelete.wrap(
                              onDelete: () => _macDelete(e),
                              child: ListTile(
                                leading:
                                    const Icon(Icons.description_outlined),
                                title: Text(
                                  e.dateLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(e.subtitle),
                                trailing: IconButton(
                                  tooltip: s.export,
                                  icon: const Icon(Icons.ios_share),
                                  onPressed:
                                      _busy ? null : () => _share(e),
                                ),
                                onTap: () => _openEntry(e),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
