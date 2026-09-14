import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_controller.dart';
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
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.newSite)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: s.siteName,
                prefixIcon: const Icon(Icons.flag_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? s.enterShort(s.siteName)
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: InputDecoration(
                labelText: s.address,
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? s.enterShort(s.address)
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              decoration: InputDecoration(
                labelText: s.contactPerson,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? s.enterShort(s.contactPerson)
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: s.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.enterShort(s.phone) : null,
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
                  : Text(s.create),
            ),
          ],
        ),
      ),
    );
  }
}
