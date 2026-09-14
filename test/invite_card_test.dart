import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/services/invite_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('招待カード画像にQRとコードを描ける', () async {
    final bytes = await InviteCard.png(inviteCode: 'LGS-A6WNVZ');
    expect(bytes.length, greaterThan(2000));
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50);
    expect(bytes[2], 0x4E);
    expect(bytes[3], 0x47);
  });
}
