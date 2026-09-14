import 'package:flutter/material.dart';

import '../../l10n/locale_controller.dart';
import '../../legal/legal_documents.dart';
import '../../theme/app_theme.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocKind kind;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  List<LegalDocSection>? _sections;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final html = await LegalDocuments.htmlOf(widget.kind);
      if (!mounted) return;
      setState(() {
        _sections = LegalDocuments.parse(html);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final s = S.of(context);
    final title = switch (widget.kind) {
      LegalDocKind.privacyPolicy => s.privacyPolicy,
      LegalDocKind.terms => s.terms,
      LegalDocKind.personalInfo => s.personalInfo,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: sections == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(
                      s.legalLoadFailed,
                      style: const TextStyle(color: AppTheme.steel),
                    ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                if (section.isHeading) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 22,
                      bottom: 8,
                    ),
                    child: Text(
                      section.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    section.text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Color(0xFF333333),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
