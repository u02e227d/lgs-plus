import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../services/lgsplus_cloud.dart';
import '../../services/notice_unread_controller.dart';
import '../../theme/app_theme.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  bool _loading = true;
  List<OpsNotice> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await LgsplusCloud.listNotices();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
    // 一覧を見たら既読（件数はホームに戻ったときに消える）
    await NoticeUnreadController.markAllRead(list);
    await NoticeUnreadController.instance.refreshNow();
  }

  String _formatTime(DateTime? dt, S s) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.notice),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: AppTheme.steel.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            s.noticeEmpty,
                            style: const TextStyle(color: AppTheme.steel),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(n.title),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(n.publishedAt, s),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.steel,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          n.body.isEmpty ? '—' : n.body,
                                          style: const TextStyle(height: 1.45),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(s.close),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title.isEmpty ? '—' : n.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(n.publishedAt, s),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.steel,
                                    ),
                                  ),
                                  if (n.body.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      n.body,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// ホーム左上ベル（未読は [NoticeUnreadController] が常時監視）
/// Mac の AppBar では Material Badge が静的時に欠けやすいので Stack で描画する。
class NoticeBellButton extends StatelessWidget {
  const NoticeBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: NoticeUnreadController.instance,
      builder: (context, _) {
        final unread = NoticeUnreadController.instance.unread;
        final label = unread > 99 ? '99+' : '$unread';
        return Center(
          child: SizedBox(
            width: 56,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: unread > 0 ? '${s.notice} ($label)' : s.notice,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NoticesScreen()),
                    );
                    await NoticeUnreadController.instance.refreshNow();
                  },
                  icon: Icon(
                    unread > 0
                        ? Icons.notifications_active
                        : Icons.notifications_outlined,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
