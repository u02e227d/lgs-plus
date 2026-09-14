import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/services/device_session.dart';

void main() {
  test('本番アカウントは1端末、テストメールは対象外', () {
    expect(DeviceSession.enforceFor('user@example.com'), isTrue);
    expect(DeviceSession.enforceFor('test@lgsplus.local'), isFalse);
    expect(DeviceSession.enforceFor('TEST@lgsplus.local'), isFalse);
  });

  test('サーバーの追い出しコードを判定する', () {
    expect(DeviceSession.isKickedMessage('session_kicked'), isTrue);
    expect(DeviceSession.isKickedMessage('このメールアドレスは既に登録されています'), isFalse);
  });
}
