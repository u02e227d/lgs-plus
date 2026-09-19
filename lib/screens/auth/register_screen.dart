import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../services/account_plan.dart';
import '../../services/account_recovery.dart';
import '../../theme/app_theme.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _family = TextEditingController();
  final _given = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  late final TextEditingController _email;
  final _invite = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _family.dispose();
    _given.dispose();
    _company.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final contactName = AccountRecovery.joinFamilyGiven(
        _family.text,
        _given.text,
      );
      final company = _company.text.trim();
      final email = _email.text.trim();
      await state.auth.register(
        companyName: company.isEmpty ? contactName : company,
        address: _address.text.trim(),
        contactName: contactName,
        phone: _phone.text,
        email: email,
        inviteCode: AccountPlan.friendInviteEnabled ? _invite.text : null,
      );
      if (!mounted) return;
      final s = S.of(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.registerDone),
          content: Text(s.registerMailSent(email)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.ok),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: email),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final s = S.of(context);
      final email = _email.text.trim();
      final looksTaken = msg.contains(s.emailTaken) ||
          msg.contains('既に登録') ||
          msg.contains('已被注册') ||
          msg.contains('already registered');
      if (looksTaken && email.isNotEmpty) {
        try {
          await context.read<AppState>().auth.resumeIncompleteRegistration(email);
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(s.resumeRegistrationTitle),
              content: Text(s.resumeRegistrationBody(email)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(s.ok),
                ),
              ],
            ),
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => VerifyEmailScreen(email: email),
            ),
          );
          return;
        } catch (_) {
          // 活性化済みなど再開不可 → 元のエラーを表示
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.registerTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              s.registerIntro,
              style: const TextStyle(color: AppTheme.steel),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    _family,
                    s.familyName,
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _given,
                    s.givenName,
                    Icons.badge_outlined,
                  ),
                ),
              ],
            ),
            _optionalField(_company, s.companyOptional, Icons.business),
            _field(
              _address,
              s.address,
              Icons.location_on_outlined,
              type: TextInputType.streetAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return s.pleaseEnter(s.address);
                if (t.length < 4) return s.invalidAddress;
                return null;
              },
            ),
            _field(
              _phone,
              s.phone,
              Icons.phone_outlined,
              type: TextInputType.phone,
              validator: (v) {
                final key = AccountRecovery.normalizePhone(v ?? '');
                if (key.isEmpty) return s.pleaseEnter(s.phone);
                if (key.length < 10 || key.length > 11) return s.invalidPhone;
                return null;
              },
            ),
            _field(
              _email,
              s.email,
              Icons.email_outlined,
              type: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim().toLowerCase();
                if (t.isEmpty) return s.pleaseEnter(s.email);
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return s.invalidEmail;
                }
                return null;
              },
            ),
            if (AccountPlan.friendInviteEnabled)
              _optionalField(
                _invite,
                s.inviteCodeOptional,
                Icons.card_giftcard,
                capitalizeCharacters: true,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(s.doRegister),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty)
                ? S.of(context).pleaseEnter(label)
                : null,
      ),
    );
  }

  Widget _optionalField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool capitalizeCharacters = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        textCapitalization: capitalizeCharacters
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}
