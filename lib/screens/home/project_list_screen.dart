import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'create_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LGS+積算 現場一覧'),
        actions: [
          IconButton(
            tooltip: 'ログアウト',
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
        label: const Text('新規現場'),
      ),
      body: Column(
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
          Expanded(
            child: state.projects.isEmpty
                ? const Center(
                    child: Text(
                      '現場がありません\n右下から新規作成してください',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.steel),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: state.refreshProjects,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = state.projects[i];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.apartment,
                                color: AppTheme.navy,
                              ),
                            ),
                            title: Text(
                              p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text('${p.address}\n${p.contactName} / ${p.phone}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProjectDetailScreen(projectId: p.id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
