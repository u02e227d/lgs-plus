import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final project = await context.read<AppState>().createProject(
            name: _name.text,
            address: _address.text,
            contactName: _contact.text,
            phone: _phone.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(project);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規現場')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '現場名称',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '現場名称を入力' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: '住所',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '住所を入力' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: '連絡先担当者',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '連絡先を入力' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '電話番号',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '電話番号を入力' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('作成する'),
            ),
          ],
        ),
      ),
    );
  }
}
