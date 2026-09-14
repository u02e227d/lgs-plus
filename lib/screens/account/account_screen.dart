import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_lang.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'feedback_screen.dart';
import 'invite_compose_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      if (state.user != null) {
        await state.checkDeviceSession();
      }
      await _showNoticeIfNeeded();
    });
  }

  Future<void> _showNoticeIfNeeded() async {
    final state = context.read<AppState>();
    final user = state.user;
    final notice = user?.pendingNotice;
    if (notice == null || notice.isEmpty) return;
    if (!mounted) return;
    final s = S.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.notice),
        content: Text(notice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.ok),
          ),
        ],
      ),
    );
    final latest = state.user;
    if (latest == null) return;
    await state.setUser(await state.auth.clearPendingNotice(latest));
  }

  Future<void> _run(Future<AppUser> Function(AppUser user) action) async {
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await state.setUser(await action(user));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<AppState>().user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.accountTitle)),
        body: Center(child: Text(s.notLoggedIn)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(user, s),
          const SizedBox(height: 16),
          _planCard(user, s),
          const SizedBox(height: 16),
          _inviteCard(user, s),
          const SizedBox(height: 16),
          _feedbackCard(s),
          const SizedBox(height: 16),
          _settingsCard(s),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(AppUser user, S s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.accountInfo,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _row(s.accountName, user.companyName),
            _row(s.address, user.address),
            _row(s.email, user.email),
            _row(s.phone, user.phone),
            _row(s.remainingDays, s.daysUnit(user.remainingDays())),
            const SizedBox(height: 8),
            Text(
              user.hasFullAccess() ? s.fullAccessHint : s.freeAccessHint,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(AppUser user, S s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.planVersion,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _planChip(s.free, !user.isPaid),
                const SizedBox(width: 8),
                _planChip(s.paid, user.isPaid),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.safetyYellow.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(s.paidNotice),
            ),
            const SizedBox(height: 14),
            if (!user.isPaid)
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _run((u) => context.read<AppState>().auth.startPaidPlan(u)),
                child: Text(s.startPaid),
              )
            else
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run((u) => context.read<AppState>().auth.cancelPaidPlan(u)),
                child: Text(s.cancelPlan),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inviteCard(AppUser user, S s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.inviteFriends,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              s.inviteCodeLabel(user.inviteCode),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              s.inviteHint,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        InviteComposeScreen(inviteCode: user.inviteCode),
                  ),
                );
              },
              icon: const Icon(Icons.mail_outline),
              label: Text(s.inviteFriends),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackCard(S s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.feedbackTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              s.feedbackHint,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                );
              },
              icon: const Icon(Icons.feedback_outlined),
              label: Text(s.feedbackTitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(S s) {
    final current = LocaleController.instance.lang;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.appSettings,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              s.displayLanguage,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              s.languageNote,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
            const SizedBox(height: 8),
            ...AppLang.values.map(
              (lang) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lang.nativeLabel),
                trailing: Icon(
                  lang == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppTheme.navy,
                ),
                onTap: () => LocaleController.instance.setLang(lang),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.navy : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.navy),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppTheme.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppTheme.steel)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
