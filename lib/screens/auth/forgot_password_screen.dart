import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../services/app_platform.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';
import 'reset_link_flow.dart';
import 'verify_email_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String get _registerSameEmailLabel {
    final s = S.of(context);
    if (AppPlatform.isWindows) return s.registerWindowsWithSameEmail;
    if (AppPlatform.isMacOS) return s.registerMacWithSameEmail;
    return s.registerMacWithSameEmail;
  }

  Future<void> _openLocalRegister(String email) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(initialEmail: email),
      ),
    );
  }

  Future<void> _sendEmail() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = S.of(context).pleaseEnter(S.of(context).email));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final resume = await context
          .read<AppState>()
          .auth
          .requestPasswordResetByEmail(email);
      if (!mounted) return;
      if (resume) {
        final s = S.of(context);
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: email),
          ),
        );
        return;
      }
      await showResetLinkSentAndOpen(
        context: context,
        email: email,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final s = S.of(context);
      final otherPlatformOnDesktop = AppPlatform.usesDesktopLogin &&
          (msg == s.accountForIosOnly ||
              msg == s.accountForMacOnly ||
              msg == s.accountForWindowsOnly ||
              msg.contains('wrong_client_app:') ||
              msg.contains('iPhone / iPad') ||
              msg.contains('Windows') ||
              msg.contains('Mac'));
      if (otherPlatformOnDesktop) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.forgotPasswordTitle),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_registerSameEmailLabel),
              ),
            ],
          ),
        );
        if (go == true && mounted) {
          await _openLocalRegister(_email.text.trim());
          return;
        }
        setState(() => _error = msg);
        return;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.forgotPasswordTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.safetyYellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(s.enterRegisteredEmail),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: s.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.danger),
            ),
            if (AppPlatform.usesDesktopLogin &&
                (_error == s.accountForIosOnly ||
                    _error == s.accountForMacOnly ||
                    _error == s.accountForWindowsOnly)) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openLocalRegister(_email.text.trim()),
                child: Text(_registerSameEmailLabel),
              ),
            ],
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _sendEmail,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(s.sendResetCode),
          ),
        ],
      ),
    );
  }
}
