import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'reset_link_flow.dart';

enum FindAccountPurpose { findEmail, resetBySms }

class FindEmailScreen extends StatefulWidget {
  const FindEmailScreen({
    super.key,
    this.purpose = FindAccountPurpose.findEmail,
  });

  final FindAccountPurpose purpose;

  @override
  State<FindEmailScreen> createState() => _FindEmailScreenState();
}

class _FindEmailScreenState extends State<FindEmailScreen> {
  final _phone = TextEditingController();
  final _family = TextEditingController();
  final _given = TextEditingController();
  bool _askName = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _family.dispose();
    _given.dispose();
    super.dispose();
  }

  void _goToName() {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = S.of(context).enterPhone);
      return;
    }
    setState(() {
      _askName = true;
      _error = null;
    });
  }

  Future<void> _lookup() async {
    if (_family.text.trim().isEmpty || _given.text.trim().isEmpty) {
      setState(() => _error = S.of(context).enterFamilyGiven);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await context.read<AppState>().auth.findAccountByPhoneAndName(
            phone: _phone.text,
            name: '${_family.text.trim()} ${_given.text.trim()}',
          );
      if (!mounted) return;
      final extra = widget.purpose == FindAccountPurpose.findEmail
          ? S.of(context).foundEmail(user.email)
          : null;
      await showResetLinkSentAndOpen(
        context: context,
        user: user,
        channel: PasswordResetChannel.sms,
        extraMessage: extra,
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
        title: Text(
          _askName
              ? s.confirmNameTitle
              : (widget.purpose == FindAccountPurpose.findEmail
                  ? s.findEmailTitle
                  : s.resetBySms),
        ),
        leading: BackButton(
          onPressed: () {
            if (_askName) {
              setState(() {
                _askName = false;
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
              _askName ? s.enterFamilyGivenHint : s.enterRegisteredPhone,
            ),
          ),
          const SizedBox(height: 16),
          if (!_askName)
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: s.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _family,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: s.familyName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _given,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: s.givenName,
                    ),
                    onSubmitted: (_) {
                      if (!_busy) _lookup();
                    },
                  ),
                ),
              ],
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
            onPressed: _busy
                ? null
                : (_askName ? _lookup : _goToName),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_askName ? s.confirmAction : s.next),
          ),
        ],
      ),
    );
  }
}
