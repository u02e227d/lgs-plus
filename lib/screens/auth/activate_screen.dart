import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

class ActivateScreen extends StatefulWidget {
  const ActivateScreen({
    super.key,
    this.initialEmail,
    this.isPasswordReset = false,
  });

  final String? initialEmail;
  final bool isPasswordReset;

  @override
  State<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends State<ActivateScreen> {
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).passwordMismatch)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final user = await state.auth.activateWithPassword(
        email: _email.text,
        password: _password.text,
      );
      await state.setUser(user);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
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
      appBar: AppBar(
        title: Text(widget.isPasswordReset ? s.resetPasswordTitle : s.activateTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.safetyYellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(widget.isPasswordReset ? s.resetHint : s.activateHint),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            readOnly: widget.isPasswordReset &&
                (widget.initialEmail?.isNotEmpty ?? false),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: s.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.passwordMin6,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.passwordConfirm,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _activate,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isPasswordReset
                    ? s.resetPasswordAction
                    : s.setPasswordActivate),
          ),
        ],
      ),
    );
  }
}
