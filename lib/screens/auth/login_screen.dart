import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/locale_controller.dart';
import '../../legal/legal_documents.dart';
import '../../providers/app_state.dart';
import '../../services/app_platform.dart';
import '../../services/device_session.dart';
import '../../theme/app_theme.dart';
import 'find_email_screen.dart';
import 'forgot_password_screen.dart';
import 'legal_document_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _savedEmailKey = 'lgsplus_login_email';

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedEmailKey)?.trim() ?? '';
    if (saved.isEmpty || !mounted) return;
    _email.text = saved;
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      await prefs.remove(_savedEmailKey);
    } else {
      await prefs.setString(_savedEmailKey, normalized);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    context.read<AppState>().clearSessionKickNotice();
    try {
      final state = context.read<AppState>();
      final user = await state.auth.login(
        email: _email.text,
        password: _password.text,
      );
      await _saveEmail(user.email);
      await state.setUser(user);
    } on DeviceSwitchCooldownException {
      setState(() => _error = S.of(context).deviceSwitchCooldown);
    } on SessionKickedException {
      setState(() => _error = S.of(context).sessionKicked);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFindEmail() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FindEmailScreen()),
    );
    if (!mounted || email == null || email.trim().isEmpty) return;
    setState(() => _email.text = email.trim());
    await _saveEmail(email);
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _fieldLink(String label, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _legalLink(LegalDocKind kind, String title) {
    return GestureDetector(
      onTap: () => _open(LegalDocumentScreen(kind: kind)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _loginForm(BuildContext context, {required bool compact}) {
    final s = S.of(context);
    final state = context.watch<AppState>();
    final error = _error ?? (state.sessionKicked ? s.sessionKicked : null);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: compact
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.login,
                    style: TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: s.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  _fieldLink(s.forgotEmail, _openFindEmail),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  _fieldLink(s.forgotPassword, () {
                    _open(ForgotPasswordScreen(
                      initialEmail: _email.text.trim(),
                    ));
                  }),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ],
                  SizedBox(height: compact ? 8 : 10),
                  ElevatedButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(s.login),
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      onPressed: () => _open(const RegisterScreen()),
                      child: Text(s.register),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _legalLink(LegalDocKind.privacyPolicy, s.privacyPolicy),
              const Text(
                '・',
                style: TextStyle(color: Colors.black, fontSize: 13),
              ),
              _legalLink(LegalDocKind.terms, s.terms),
              const Text(
                '・',
                style: TextStyle(color: Colors.black, fontSize: 13),
              ),
              _legalLink(LegalDocKind.personalInfo, s.personalInfo),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMac = AppPlatform.usesDesktopLogin;
    // Keep Mac form in the lower band so it never covers banner branding.
    final macFormTop = (size.height * 0.52).clamp(300.0, size.height * 0.60);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: isMac ? AppTheme.navy : Colors.transparent,
            child: Image.asset(
              isMac
                  ? 'assets/images/login_banner_mac.png'
                  : 'assets/images/login_banner.png',
              fit: BoxFit.cover,
              alignment: isMac ? Alignment.topCenter : Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (isMac)
            Positioned(
              left: 0,
              right: 0,
              top: macFormTop,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: _loginForm(context, compact: true),
                  ),
                ),
              ),
            )
          else
            SafeArea(
              child: Align(
                alignment: Alignment(
                  0,
                  size.shortestSide < 600 ? 1.0 : 0.92,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    size.shortestSide < 600 ? 4 : 24,
                  ),
                  child: _loginForm(context, compact: false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
