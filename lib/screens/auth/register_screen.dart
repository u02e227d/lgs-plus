import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _company.dispose();
    _address.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      await state.auth.register(
        companyName: _company.text,
        address: _address.text,
        contactName: _contact.text,
        phone: _phone.text,
        email: _email.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('登録完了'),
          content: Text(
            '活性化メールを ${_email.text.trim()} に送信しました（デモ：ローカル模擬）。\n'
            '次の画面でパスワードを設定してアカウントを有効化してください。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '会社情報を入力してください。登録後、メールでパスワード設定リンクが届きます。',
              style: TextStyle(color: AppTheme.steel),
            ),
            const SizedBox(height: 16),
            _field(_company, '会社名称', Icons.business),
            _field(_address, '住所', Icons.location_on_outlined),
            _field(_contact, '担当者名', Icons.person_outline),
            _field(_phone, '電話番号', Icons.phone_outlined,
                type: TextInputType.phone),
            _field(_email, 'メールアドレス', Icons.email_outlined,
                type: TextInputType.emailAddress),
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
                  : const Text('登録する'),
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
            (v == null || v.trim().isEmpty) ? '$labelを入力してください' : null,
      ),
    );
  }
}
