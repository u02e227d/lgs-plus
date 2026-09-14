import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/legal/legal_documents.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/services/account_recovery.dart';

AppUser _user({
  required String phone,
  required String name,
  String email = 'a@example.com',
}) {
  return AppUser(
    id: 'u1',
    companyName: 'テスト建設',
    address: '東京都',
    contactName: name,
    phone: phone,
    email: email,
    activated: true,
  );
}

void main() {
  test('電話番号はハイフン・+81・全角数字を正規化する', () {
    expect(AccountRecovery.normalizePhone('090-1234-5678'), '09012345678');
    expect(AccountRecovery.normalizePhone('+81 90-1234-5678'), '09012345678');
    expect(AccountRecovery.normalizePhone('０９０ー１２３４ー５６７８'), '09012345678');
  });

  test('氏名は空白を無視して照合する', () {
    expect(AccountRecovery.namesMatch('山田 太郎', '山田太郎'), isTrue);
    expect(AccountRecovery.namesMatch('山田太郎', '佐藤太郎'), isFalse);
  });

  test('電話＋姓・名が一致すればアカウントを返す', () {
    final users = [
      _user(phone: '090-1234-5678', name: '山田太郎', email: 'yamada@lgs.local'),
    ];
    final found = AccountRecovery.matchByPhoneAndName(
      users: users,
      phone: '09012345678',
      name: '',
      familyName: '山田',
      givenName: '太郎',
    );
    expect(found?.email, 'yamada@lgs.local');
  });

  test('会社名／名前欄に保存した氏名でも照合できる', () {
    final user = AppUser(
      id: 'u2',
      companyName: '山田太郎',
      address: '',
      contactName: '山田太郎',
      phone: '090-1111-2222',
      email: 'name@lgs.local',
      activated: true,
    );
    expect(
      AccountRecovery.matchByPhoneAndName(
        users: [user],
        phone: '09011112222',
        name: '',
        familyName: '山田',
        givenName: '太郎',
      )?.email,
      'name@lgs.local',
    );
  });

  test('電話または氏名が違えば見つからない', () {
    final users = [
      _user(phone: '090-1234-5678', name: '山田太郎'),
    ];
    expect(
      AccountRecovery.matchByPhoneAndName(
        users: users,
        phone: '080-0000-0000',
        name: '山田太郎',
      ),
      isNull,
    );
    expect(
      AccountRecovery.matchByPhoneAndName(
        users: users,
        phone: '090-1234-5678',
        name: '',
        familyName: '佐藤',
        givenName: '太郎',
      ),
      isNull,
    );
  });

  test('InfCMS 規約本文を整形できる', () {
    final file = File('assets/legal/legal_docs.json');
    final data = json.decode(file.readAsStringSync()) as Map;
    expect(data.keys, containsAll(['privacy_policy', 'terms', 'personal_info']));

    final terms = LegalDocuments.parse('${data['terms']}');
    final headings =
        terms.where((s) => s.isHeading).map((s) => s.text).toList();
    expect(headings.first, '利用規約');
    expect(headings.any((t) => t.startsWith('第１条')), isTrue);

    final allText = data.values.map((v) => LegalDocuments.parse('$v'))
        .expand((s) => s)
        .map((s) => s.text)
        .join('\n');
    expect(allText.contains('info@mail.maxai.com'), isTrue);
    expect(allText.contains('2026年9月15日'), isTrue);
    expect(allText.contains('jun@'), isFalse);

    for (final entry in data.entries) {
      final sections = LegalDocuments.parse('${entry.value}');
      expect(sections, isNotEmpty, reason: '${entry.key} が空');
      for (final s in sections) {
        expect(RegExp(r'<[^>]+>').hasMatch(s.text), isFalse);
        expect(s.text.contains('[removed]'), isFalse);
      }
    }
  });
}
