import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'find_email_screen.dart';
import 'reset_link_flow.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _useEmail = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
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
      final user = await context
          .read<AppState>()
          .auth
          .requestPasswordResetByEmail(_email.text);
      if (!mounted) return;
      await showResetLinkSentAndOpen(
        context: context,
        user: user,
        channel: PasswordResetChannel.email,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.forgotPasswordTitle),
        leading: BackButton(
          onPressed: () {
            if (_useEmail) {
              setState(() {
                _useEmail = false;
                _error = null;
              });
            } else {
              Navigator.of(context).maybePop();
            }
          },
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
              _useEmail ? s.enterRegisteredEmail : s.resetChannelIntro,
            ),
          ),
          const SizedBox(height: 20),
          if (!_useEmail) ...[
            ElevatedButton(
              onPressed: () => setState(() {
                _useEmail = true;
                _error = null;
              }),
              child: Text(s.resetByEmail),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FindEmailScreen(
                      purpose: FindAccountPurpose.resetBySms,
                    ),
                  ),
                );
              },
              child: Text(s.resetBySms),
            ),
          ] else ...[
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
                  : Text(s.sendResetLink),
            ),
          ],
        ],
      ),
    );
  }
}
