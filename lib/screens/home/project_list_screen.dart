import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/app_platform.dart';
import '../../services/notice_unread_controller.dart';
import '../../theme/app_theme.dart';
import '../account/account_screen.dart';
import 'create_project_screen.dart';
import 'notices_screen.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  static bool get _isMac => AppPlatform.usesDesktopPointer;

  /// 左スワイプ／右クリック共通の削除確認
  Future<bool> _confirmDelete(BuildContext context, SiteProject p) async {
    final s = S.of(context);
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
              title: Text(s.deleteSite),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.cancel),
              onTap: () => Navigator.pop(ctx, 'cancel'),
            ),
          ],
        ),
      ),
    );
    if (action != 'delete') return false;
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteSite),
        content: Text(s.deleteNamedConfirm(p.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirmDelete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _performDelete(BuildContext context, SiteProject p) async {
    final s = S.of(context);
    final name = p.name;
    await context.read<AppState>().deleteProject(p.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.deletedItem(name))),
    );
  }

  Future<void> _macSecondaryDelete(BuildContext context, SiteProject p) async {
    final ok = await _confirmDelete(context, p);
    if (!ok || !context.mounted) return;
    await _performDelete(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        clipBehavior: Clip.none,
        leadingWidth: 72,
        leading: const NoticeBellButton(),
        title: ListenableBuilder(
          listenable: NoticeUnreadController.instance,
          builder: (context, _) {
            final n = NoticeUnreadController.instance.unread;
            if (n <= 0) return Text(s.sitesTitle);
            return Text('${s.sitesTitle}（未読$n）');
          },
        ),
        actions: [
          IconButton(
            tooltip: s.logout,
            onPressed: () async {
              await state.auth.logout();
              await state.setUser(null);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
          );
          if (context.mounted) {
            await context.read<AppState>().refreshProjects();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(s.newSite),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (user != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.navy,
                        child: Text(
                          user.companyName.isNotEmpty
                              ? user.companyName.characters.first
                              : 'L',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.companyName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              user.contactName,
                              style: const TextStyle(
                                color: AppTheme.steel,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (user != null && !user.hasFullAccess())
                Container(
                  width: double.infinity,
                  color: AppTheme.safetyYellow.withValues(alpha: 0.35),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    s.freeBanner,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              if (_isMac && state.projects.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    s.macDeleteHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.steel,
                      height: 1.35,
                    ),
                  ),
                ),
              Expanded(
                child: state.projects.isEmpty
                    ? Center(
                        child: Text(
                          s.noSites,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.steel),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: state.refreshProjects,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: state.projects.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final p = state.projects[i];
                            return Card(
                              clipBehavior: Clip.hardEdge,
                              child: Dismissible(
                                key: ValueKey('project_${p.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) =>
                                    _confirmDelete(context, p),
                                onDismissed: (_) =>
                                    _performDelete(context, p),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppTheme.danger,
                                  child: Text(
                                    s.deleteSite,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                child: GestureDetector(
                                  // Mac：トラックパッド二本指クリック／マウス右クリック
                                  onSecondaryTap: _isMac
                                      ? () => _macSecondaryDelete(context, p)
                                      : null,
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.navy
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.apartment,
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${p.address}\n${p.contactName} / ${p.phone}',
                                    ),
                                    isThreeLine: true,
                                    trailing:
                                        const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProjectDetailScreen(
                                            projectId: p.id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton.extended(
                heroTag: 'account',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navy,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_accounts_outlined),
                label: Text(s.goAccount),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
