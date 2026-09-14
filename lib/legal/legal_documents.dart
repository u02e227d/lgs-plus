import 'dart:convert';

import 'package:flutter/services.dart';

/// InfCMS と同種の規約類
enum LegalDocKind {
  privacyPolicy,
  terms,
  personalInfo,
}

class LegalDocSection {
  const LegalDocSection(this.text, {this.isHeading = false});

  final String text;
  final bool isHeading;
}

/// InfCMS（株式会社インフィニティ）CMS の規約本文を端末に同梱して表示する
class LegalDocuments {
  LegalDocuments._();

  static const String assetPath = 'assets/legal/legal_docs.json';
  static const String _headingMark = '\u0001';

  static Map<String, String>? _memoryCache;

  static String titleOf(LegalDocKind kind) {
    switch (kind) {
      case LegalDocKind.privacyPolicy:
        return 'プライバシーポリシー';
      case LegalDocKind.terms:
        return '利用規約';
      case LegalDocKind.personalInfo:
        return '個人情報保護方針';
    }
  }

  static String apiKeyOf(LegalDocKind kind) {
    switch (kind) {
      case LegalDocKind.privacyPolicy:
        return 'privacy_policy';
      case LegalDocKind.terms:
        return 'terms';
      case LegalDocKind.personalInfo:
        return 'personal_info';
    }
  }

  static Future<String> htmlOf(LegalDocKind kind) async {
    var docs = _memoryCache;
    if (docs == null) {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return '';
      }
      docs = decoded.map((k, v) => MapEntry('$k', '${v ?? ''}'));
      _memoryCache = docs;
    }
    return docs[apiKeyOf(kind)] ?? '';
  }

  static List<LegalDocSection> parse(String html) {
    var text = html;
    text = text.replaceAll(
      RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false),
      '\n',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'<\s*(h[1-6]|strong)\b[^>]*>(.*?)<\s*/\s*\1\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) {
        final inner = m[2]!.replaceAll(RegExp(r'\s+'), ' ');
        return '\n$_headingMark$inner$_headingMark\n';
      },
    );
    text = text.replaceAll(
      RegExp(
        r'<\s*/\s*(p|div|li|ul|ol|tr|table|h[1-6])\s*>',
        caseSensitive: false,
      ),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = _decodeEntities(text);

    final sections = <LegalDocSection>[];
    for (var line in text.split('\n')) {
      final isHeading = line.contains(_headingMark);
      line = line.replaceAll(_headingMark, '');
      line = line.replaceAll(RegExp(r'[ \t\u00a0\u3000]+'), ' ').trim();
      if (line.isEmpty) continue;
      sections.add(LegalDocSection(line, isHeading: isHeading));
    }
    return sections;
  }

  static String _decodeEntities(String input) {
    var out = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&emsp;', ' ')
        .replaceAll('&ensp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    out = out.replaceAllMapped(
      RegExp(r'&#(x?)([0-9a-fA-F]+);'),
      (m) {
        final isHex = m[1] == 'x';
        final code = int.tryParse(m[2]!, radix: isHex ? 16 : 10);
        if (code == null || code < 0 || code > 0x10ffff) {
          return m[0]!;
        }
        return String.fromCharCode(code);
      },
    );
    return out.replaceAll('&amp;', '&');
  }
}
