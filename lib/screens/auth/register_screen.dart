import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'activate_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _invite = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
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
      final name = _company.text.trim();
      final user = await state.auth.register(
        companyName: name,
        address: _address.text.trim(),
        contactName: name,
        phone: _phone.text,
        email: _email.text,
        inviteCode: _invite.text,
      );
      if (!mounted) return;
      final s = S.of(context);
      final bonus = user.pendingNotice;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.registerDone),
          content: Text(
            [
              s.registerMailDemo(_email.text.trim()),
              if (bonus != null && bonus.isNotEmpty) bonus,
            ].join('\n'),
          ),
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
          builder: (_) => ActivateScreen(initialEmail: _email.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
            _field(_company, s.companyOrName, Icons.business),
            _field(
              _address,
              s.address,
              Icons.location_on_outlined,
              type: TextInputType.streetAddress,
            ),
            _field(_phone, s.phone, Icons.phone_outlined,
                type: TextInputType.phone),
            _field(_email, s.email, Icons.email_outlined,
                type: TextInputType.emailAddress),
            _optionalField(_invite, s.inviteCodeOptional, Icons.card_giftcard),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? S.of(context).pleaseEnter(label) : null,
      ),
    );
  }

  Widget _optionalField(
    TextEditingController c,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}
