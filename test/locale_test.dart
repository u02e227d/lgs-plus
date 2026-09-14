import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lgs_plus/l10n/app_lang.dart';
import 'package:lgs_plus/l10n/locale_controller.dart';
import 'package:lgs_plus/l10n/s_measure.dart';

void main() {
  test('端末言語が日英中越ならそれに合わせ、それ以外は日本語', () {
    expect(AppLang.fromDevice(const Locale('ja')), AppLang.ja);
    expect(AppLang.fromDevice(const Locale('en', 'US')), AppLang.en);
    expect(AppLang.fromDevice(const Locale('zh', 'CN')), AppLang.zh);
    expect(AppLang.fromDevice(const Locale('zh', 'TW')), AppLang.zh);
    expect(AppLang.fromDevice(const Locale('vi', 'VN')), AppLang.vi);
    expect(AppLang.fromDevice(const Locale('ko')), AppLang.ja);
    expect(AppLang.fromDevice(const Locale('fr', 'FR')), AppLang.ja);
  });

  test('保存コードの解釈', () {
    expect(AppLang.tryParse('zh'), AppLang.zh);
    expect(AppLang.tryParse('de'), isNull);
  });

  test('UI文言は言語で変わり、日本語の既定値も残る', () {
    expect(const S(AppLang.ja).displayLanguage, '表示言語');
    expect(const S(AppLang.en).displayLanguage, 'Language');
    expect(const S(AppLang.zh).displayLanguage, '显示语言');
    expect(const S(AppLang.vi).displayLanguage, 'Ngôn ngữ hiển thị');
  });

  test('測定・試算の見出しは言語で変わり、品名キーは日本語のまま', () {
    expect(const Ms(AppLang.ja).estimate, '試算表');
    expect(const Ms(AppLang.en).estimate, 'Estimate');
    expect(const Ms(AppLang.zh).materials, '材料选择');
    expect(const Ms(AppLang.vi).methodSelect, 'Chọn phương pháp');
    expect(const Ms(AppLang.en).displayArea('天井'), 'Ceiling');
    expect(const Ms(AppLang.zh).directInput, '直接输入');
    expect(const Ms(AppLang.en).greenStartNext, contains('Green'));
    expect(const Ms(AppLang.zh).dropGuideTitle, contains('下吊'));
    expect(const Ms(AppLang.ja).dropGuideWidth, '幅');
    expect(const S(AppLang.zh).pickEstimateToOrder, contains('试算表'));
    expect(const S(AppLang.zh).feedbackTitle, contains('意见'));
    expect(const S(AppLang.ja).feedbackOpinion, '意見');
    expect(const S(AppLang.zh).sessionKicked, contains('一台'));
    expect(const S(AppLang.ja).sessionKicked, contains('1台'));
  });
}
