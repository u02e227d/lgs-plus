import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_lang.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/account_plan.dart';
import '../../services/device_session.dart';
import '../../services/lgsplus_cloud.dart';
import '../../services/store_billing.dart';
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
  final _inviteEmail = TextEditingController();
  OrgTeamSnapshot _team = OrgTeamSnapshot.empty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      if (state.user != null) {
        await state.checkDeviceSession();
        await _loadMembers();
      }
      await _showNoticeIfNeeded();
    });
  }

  @override
  void dispose() {
    _inviteEmail.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final user = context.read<AppState>().user;
    if (user == null || !user.isPaid) return;
    final team = await LgsplusCloud.orgMembers(user.id);
    if (mounted) setState(() => _team = team);
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

  Future<void> _startPaid(AppUser user, SeatPack pack) async {
    if (!DeviceSession.enforceFor(user.email)) {
      await _run((u) => context.read<AppState>().auth.startPaidPlan(
            u,
            productId: pack.productId,
          ));
      return;
    }
    if (!StoreBilling.isStorePlatform) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).storePlatformOnly)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().startStorePurchase(pack.productId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_storeError(S.of(context), e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restorePaid() async {
    final user = context.read<AppState>().user;
    if (user == null || !DeviceSession.enforceFor(user.email)) return;
    if (!StoreBilling.isStorePlatform) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).storePlatformOnly)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().restoreStorePurchases();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_storeError(S.of(context), e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelPaid(AppUser user) async {
    if (!DeviceSession.enforceFor(user.email) || !StoreBilling.isStorePlatform) {
      await _run((u) => context.read<AppState>().auth.cancelPaidPlan(u));
      return;
    }
    await StoreBilling.openManageSubscriptions();
  }

  Future<void> _inviteColleague() async {
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) return;
    final email = _inviteEmail.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    try {
      await LgsplusCloud.inviteOrgMember(userId: user.id, email: email);
      _inviteEmail.clear();
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).orgInviteSent)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final s = S.of(context);
      final shown = msg == 'seat_limit' ? s.orgSeatFull : msg;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(shown)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeOwnerEmail(AppUser user) async {
    final s = S.of(context);
    final auth = context.read<AppState>().auth;
    final appState = context.read<AppState>();
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    var step = 0; // 0: email, 1: code
    var pendingEmail = '';
    var dialogBusy = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> sendCode() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              setLocal(() => dialogBusy = true);
              try {
                await auth.requestOwnerEmailChange(
                  user: user,
                  newEmail: email,
                );
                pendingEmail = email;
                setLocal(() {
                  step = 1;
                  dialogBusy = false;
                });
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(s.changeEmailCodeSent)),
                  );
                }
              } catch (e) {
                setLocal(() => dialogBusy = false);
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            }

            Future<void> confirm() async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty || pendingEmail.isEmpty) return;
              setLocal(() => dialogBusy = true);
              try {
                final next = await auth.confirmOwnerEmailChange(
                  user: user,
                  newEmail: pendingEmail,
                  code: code,
                );
                await appState.setUser(next);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                setLocal(() => dialogBusy = false);
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(s.changeOwnerEmail),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.changeOwnerEmailHint),
                  const SizedBox(height: 14),
                  if (step == 0)
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      enabled: !dialogBusy,
                      decoration: InputDecoration(
                        labelText: s.newOwnerEmailLabel,
                        border: const OutlineInputBorder(),
                      ),
                    )
                  else ...[
                    Text(
                      s.verifyEmailHint(pendingEmail),
                      style: const TextStyle(color: AppTheme.steel, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      enabled: !dialogBusy,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: s.verifyCodeLabel,
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ],
                  if (dialogBusy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogBusy ? null : () => Navigator.pop(ctx, false),
                  child: Text(s.cancel),
                ),
                if (step == 1)
                  TextButton(
                    onPressed: dialogBusy ? null : sendCode,
                    child: Text(s.resendCode),
                  ),
                TextButton(
                  onPressed: dialogBusy
                      ? null
                      : () {
                          if (step == 0) {
                            sendCode();
                          } else {
                            confirm();
                          }
                        },
                  child: Text(step == 0 ? s.sendChangeEmailCode : s.verifyCodeAction),
                ),
              ],
            );
          },
        );
      },
    );
    emailCtrl.dispose();
    codeCtrl.dispose();
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.changeEmailSuccess)),
      );
    }
  }

  Future<void> _replaceColleague(AppUser owner, String oldEmail) async {
    final s = S.of(context);
    final emailCtrl = TextEditingController();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.replaceColleagueTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.replaceColleagueHint(oldEmail)),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.newColleagueEmailLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
            child: Text(s.replaceColleagueAction),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
    if (newEmail == null || newEmail.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<AppState>().auth.replaceOrgSeatColleague(
            owner: owner,
            oldEmail: oldEmail,
            newEmail: newEmail,
          );
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.replaceColleagueSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final shown = msg == 'seat_limit' ? s.orgSeatFull : msg;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(shown)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _storeError(S s, Object e) {
    final code = e is StoreBillingException
        ? e.code
        : e.toString().replaceFirst('Exception: ', '');
    return switch (code) {
      'store_platform' => s.storePlatformOnly,
      'store_unavailable' => s.storeUnavailable,
      'store_product_missing' => s.storeProductMissing,
      'store_buy_failed' => s.storeBuyFailed,
      _ => s.storeBuyFailed,
    };
  }

  Future<void> _run(Future<AppUser> Function(AppUser user) action) async {
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await state.setUser(await action(user));
      await _loadMembers();
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
          if (user.isPaid) ...[
            const SizedBox(height: 16),
            _teamCard(user, s),
          ],
          // 友達紹介は iPhone / iPad のみ（Mac 無料は毎月1枚・紹介なし）
          if (!user.isPaid && AccountPlan.friendInviteEnabled) ...[
            const SizedBox(height: 16),
            _inviteCard(user, s),
          ],
          const SizedBox(height: 16),
          _feedbackCard(s),
          const SizedBox(height: 16),
          _settingsCard(s),
          const SizedBox(height: 16),
          _dangerCard(user, s),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(AppUser user, S s) {
    final quotaLabel = user.uploadUnlimited
        ? s.uploadUnlimited
        : s.uploadRemainingLabel(user.uploadRemaining, user.uploadLimit);
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
            _row(s.contactNameLabel, user.contactName),
            _row(
              s.companyNameLabel,
              user.companyName.trim().isEmpty ||
                      user.companyName.trim() == user.contactName.trim()
                  ? '—'
                  : user.companyName,
            ),
            _row(s.address, user.address),
            _row(s.email, user.email),
            _row(s.phone, user.phone),
            _row(s.uploadQuotaLabel, quotaLabel),
            if (user.isPaid && user.seatLimit > 0)
              _row(
                s.seatLimitLabel,
                _team.seatLimit > 0
                    ? s.seatsUsageLabel(
                        _team.seatsUsed,
                        _team.seatLimit,
                        _team.remaining,
                      )
                    : s.seatsUnit(user.seatLimit),
              ),
            if (user.isPaid && user.isOrgOwner) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _changeOwnerEmail(user),
                icon: const Icon(Icons.alternate_email),
                label: Text(s.changeOwnerEmail),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              user.isPaid ? s.fullAccessHint : s.freeAccessHint,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(AppUser user, S s) {
    final packs = AccountPlan.storeSeatPacks
        .where((p) => p.seats >= 5 || p.seats == 1)
        .toList();
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
            const SizedBox(height: 8),
            Text(
              user.isPaid
                  ? s.paidSeatSummary(
                      user.seatLimit > 0 ? user.seatLimit : 1,
                    )
                  : s.free,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
            if (!user.isPaid) ...[
              const SizedBox(height: 14),
              Text(
                s.chooseSeatPack,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ...packs.map((pack) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _startPaid(user, pack),
                    child: Text(
                      s.buySeatPack(pack.labelJa, pack.priceYen),
                    ),
                  ),
                );
              }),
              if (DeviceSession.enforceFor(user.email))
                TextButton(
                  onPressed: _busy ? null : _restorePaid,
                  child: Text(s.restorePurchases),
                ),
            ] else ...[
              const SizedBox(height: 14),
              if (user.isOrgOwner)
                OutlinedButton(
                  onPressed: _busy ? null : () => _cancelPaid(user),
                  child: Text(s.cancelPlan),
                )
              else
                Text(
                  s.teamMemberSeatHint,
                  style: const TextStyle(color: AppTheme.steel, height: 1.5),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamCard(AppUser user, S s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.teamMembersTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              user.isOrgOwner
                  ? s.teamMembersHint(user.seatLimit)
                  : s.teamMemberSeatHint,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
            if (_team.seatLimit > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.safetyYellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.seatsUsageLabel(
                    _team.seatsUsed,
                    _team.seatLimit,
                    _team.remaining,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (user.isOrgOwner) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _inviteEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: s.colleagueEmail,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _busy ? null : _inviteColleague,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(s.inviteColleague),
              ),
            ],
            if (_team.members.isNotEmpty || _team.pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 14),
              ..._team.members.map((m) {
                final email = '${m['email'] ?? m['user_id'] ?? ''}';
                final role = '${m['role'] ?? 'member'}';
                final isOwnerRole = role == 'owner';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text('$email（$role）')),
                      if (user.isOrgOwner && !isOwnerRole && email.contains('@'))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _replaceColleague(user, email),
                          child: Text(s.replaceColleague),
                        ),
                    ],
                  ),
                );
              }),
              ..._team.pendingInvites.map((inv) {
                final email = '${inv['email'] ?? ''}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '$email（${s.seatInvitePending}）',
                          style: const TextStyle(color: AppTheme.steel),
                        ),
                      ),
                      if (user.isOrgOwner && email.contains('@'))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _replaceColleague(user, email),
                          child: Text(s.replaceColleague),
                        ),
                    ],
                  ),
                );
              }),
            ],
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

  Widget _dangerCard(AppUser user, S s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.deleteAccountTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFFC62828),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.deleteAccountBody,
              style: const TextStyle(color: AppTheme.steel, height: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _busy ? null : () => _confirmDeleteAccount(user),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFC62828)),
              ),
              child: Text(s.deleteAccount),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(AppUser user) async {
    final s = S.of(context);
    final passwordCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.deleteAccountBody),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.deleteAccountPasswordHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
            child: Text(s.deleteAccountConfirm),
          ),
        ],
      ),
    );
    final password = passwordCtrl.text;
    passwordCtrl.dispose();
    if (ok != true || !mounted) return;
    if (password.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.wrongPassword)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      await state.auth.deleteAccount(password);
      await state.setUser(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.deleteAccountDone)),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final msg = switch (raw) {
        'wrong_password' || 'パスワードが違います' => s.wrongPassword,
        'delete_account_need_network' => s.deleteAccountNeedNetwork,
        'not_logged_in' => s.notLoggedIn,
        _ => raw,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
