import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'activate_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  final String email;
  final bool isPasswordReset;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _resending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).verifyCodeInvalid)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      await state.auth.verifyEmailCode(
        email: widget.email,
        code: code,
        passwordReset: widget.isPasswordReset,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActivateScreen(
            initialEmail: widget.email,
            isPasswordReset: widget.isPasswordReset,
          ),
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

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final state = context.read<AppState>();
      await state.auth.resendEmailCode(
        email: widget.email,
        passwordReset: widget.isPasswordReset,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).resendCodeSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPasswordReset ? s.resetPasswordTitle : s.verifyEmailTitle,
        ),
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
            child: Text(
              widget.isPasswordReset
                  ? s.resetVerifyHint(widget.email)
                  : s.verifyEmailHint(widget.email),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: s.verifyCodeLabel,
              prefixIcon: const Icon(Icons.pin_outlined),
              counterText: '',
            ),
            onSubmitted: (_) => _busy ? null : _verify(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(s.verifyCodeAction),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: (_busy || _resending) ? null : _resend,
            child: _resending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.resendCode),
          ),
        ],
      ),
    );
  }
}
