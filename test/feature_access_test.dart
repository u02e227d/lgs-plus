import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/l10n/app_lang.dart';
import 'package:lgs_plus/l10n/locale_controller.dart';
import 'package:lgs_plus/models/models.dart';
import 'package:lgs_plus/providers/app_state.dart';
import 'package:lgs_plus/screens/account/account_screen.dart';
import 'package:lgs_plus/screens/home/project_list_screen.dart';
import 'package:lgs_plus/services/feature_access.dart';
import 'package:provider/provider.dart';

AppUser _freeExpired() => AppUser(
      id: 'free',
      companyName: '無料建設',
      address: '東京都',
      contactName: '無料',
      phone: '090',
      email: 'free@test.local',
      activated: true,
      plan: SubscriptionPlan.free,
      accessUntil: DateTime(2020, 1, 1),
    );

AppUser _paid() => _freeExpired().copyWith(plan: SubscriptionPlan.paid);

AppUser _trial() =>
    _freeExpired().copyWith(accessUntil: DateTime(2099, 1, 1));

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

  test('無料期限切れは全機能なし、有料・特典期限内はあり', () {
    final now = DateTime(2026, 9, 14);
    expect(FeatureAccess.hasFullAccess(_freeExpired(), now), isFalse);
    expect(FeatureAccess.hasFullAccess(_paid(), now), isTrue);
    expect(FeatureAccess.hasFullAccess(_trial(), now), isTrue);
    expect(FeatureAccess.hasFullAccess(null, now), isFalse);
  });

  testWidgets('無料版：現場一覧に制限バナーが出る', (tester) async {
    final state = AppState();
    state.booting = false;
    state.user = _freeExpired();
    state.projects = [];
    await tester.pumpWidget(_app(state, home: const ProjectListScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('図面アップロード'), findsWidgets);
    expect(find.textContaining('試算表'), findsWidgets);
  });

  testWidgets('有料版：現場一覧に無料バナーは出ない', (tester) async {
    final state = AppState();
    state.booting = false;
    state.user = _paid();
    state.projects = [];
    await tester.pumpWidget(_app(state, home: const ProjectListScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('無料版：図面アップロード'), findsNothing);
  });

  testWidgets('無料版：有料機能を開くと案内が出てアカウントへ行ける', (tester) async {
    final state = AppState();
    state.booting = false;
    state.user = _freeExpired();
    await tester.pumpWidget(
      _app(
        state,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => FeatureAccess.requireFullAccess(context),
              child: const Text('open-paid'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-paid'));
    await tester.pumpAndSettle();
    expect(find.text(S.of(tester.element(find.text('open-paid'))).upgradeTitle),
        findsOneWidget);
    expect(find.textContaining('材料選択'), findsOneWidget);
    expect(find.textContaining('試算表'), findsOneWidget);
    expect(find.textContaining('注文書'), findsOneWidget);

    await tester.tap(find.text(const S(AppLang.ja).close));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('open-paid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(const S(AppLang.ja).goAccount));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.textContaining('図面アップロード'), findsWidgets);
  });

  testWidgets('有料版：requireFullAccess はダイアログなしで通る', (tester) async {
    final state = AppState();
    state.booting = false;
    state.user = _paid();
    var allowed = false;
    await tester.pumpWidget(
      _app(
        state,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                allowed = await FeatureAccess.requireFullAccess(context);
              },
              child: const Text('open-paid'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-paid'));
    await tester.pumpAndSettle();
    expect(allowed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
