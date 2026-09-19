import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/l10n/app_lang.dart';
import 'package:lgs_plus/l10n/locale_controller.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/providers/app_state.dart';
import 'package:lgs_plus/screens/account/account_screen.dart';
import 'package:lgs_plus/services/feature_access.dart';
import 'package:provider/provider.dart';

AppUser _free({int remaining = 3}) => AppUser(
      id: 'free',
      companyName: '無料建設',
      address: '東京都',
      contactName: '無料',
      phone: '090',
      email: 'free@test.local',
      activated: true,
      plan: SubscriptionPlan.free,
      uploadRemaining: remaining,
      uploadLimit: 3,
    );

AppUser _paid() => _free().copyWith(
      plan: SubscriptionPlan.paid,
      uploadUnlimited: true,
      uploadRemaining: -1,
      seatLimit: 5,
    );

Widget _app(AppState state, {required Widget home}) {
  return LocaleScope(
    controller: LocaleController.instance,
    child: ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: home),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ログイン済みは全機能、アップロードは枠で制限', () {
    expect(FeatureAccess.hasFullAccess(_free()), isTrue);
    expect(FeatureAccess.hasFullAccess(_paid()), isTrue);
    expect(FeatureAccess.hasFullAccess(null), isFalse);
    expect(_free(remaining: 0).canUploadDrawing, isFalse);
    expect(_paid().canUploadDrawing, isTrue);
  });

  testWidgets('アップロード上限時は案内が出てアカウントへ行ける', (tester) async {
    final state = AppState();
    state.booting = false;
    state.user = _free(remaining: 0);
    await tester.pumpWidget(
      _app(
        state,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => FeatureAccess.requireUploadSlot(context),
              child: const Text('upload'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('upload'));
    await tester.pumpAndSettle();
    expect(find.text(const S(AppLang.ja).uploadLimitTitle), findsOneWidget);

    await tester.tap(find.text(const S(AppLang.ja).goAccount));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('枠があれば requireUploadSlot は通る', (tester) async {
    final state = AppState();
    state.booting = false;
    state.user = _free(remaining: 2);
    var allowed = false;
    await tester.pumpWidget(
      _app(
        state,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                allowed = await FeatureAccess.requireUploadSlot(context);
              },
              child: const Text('upload'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('upload'));
    await tester.pumpAndSettle();
    expect(allowed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
