import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lang.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _key = 'app_lang';

  AppLang _lang = AppLang.ja;

  AppLang get lang => _lang;
  S get strings => S(_lang);
  Locale get locale => _lang.locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = AppLang.tryParse(prefs.getString(_key)) ?? AppLang.fromDevice();
    notifyListeners();
  }

  Future<void> setLang(AppLang lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.code);
    notifyListeners();
  }
}

class S {
  const S(this.lang);
  final AppLang lang;

  static S of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LocaleScope>()?.strings ??
      LocaleController.instance.strings;

  String _p(String ja, String en, String zh, String vi) => switch (lang) {
        AppLang.ja => ja,
        AppLang.en => en,
        AppLang.zh => zh,
        AppLang.vi => vi,
      };

  String get appTagline => _p(
        '現場積算・注文をオフラインで',
        'Offline takeoff and orders',
        '离线现场积算与订货',
        'Tính khối lượng và đặt hàng offline',
      );

  String get login => _p('ログイン', 'Log in', '登录', 'Đăng nhập');
  String get register => _p('新規登録', 'Sign up', '新注册', 'Đăng ký');
  String get email => _p('メールアドレス', 'Email', '邮箱', 'Email');
  String get password => _p('パスワード', 'Password', '密码', 'Mật khẩu');
  String get forgotEmail =>
      _p('メールアドレスを忘れた場合', 'Forgot email', '忘记邮箱', 'Quên email');
  String get forgotPassword =>
      _p('パスワードを忘れた場合', 'Forgot password', '忘记密码', 'Quên mật khẩu');
  String get privacyPolicy =>
      _p('プライバシーポリシー', 'Privacy Policy', '隐私政策', 'Chính sách bảo mật');
  String get terms => _p('利用規約', 'Terms of Use', '使用条款', 'Điều khoản sử dụng');
  String get personalInfo =>
      _p('個人情報保護方針', 'Personal Information Policy', '个人信息保护方针', 'Chính sách thông tin cá nhân');

  String get registerTitle => _p('新規登録', 'Sign up', '新注册', 'Đăng ký');
  String get registerIntro => _p(
        '氏名・住所・電話番号・メールアドレスを入力してください（会社名は任意）。住所は注文書に表示されます。登録後、メールに届く認証コードで確認し、パスワードを設定してください。同じ端末種別では同一メールの再登録はできません（iPhone/iPad・Mac・Windows は別アカウントとして同一メール可）。同一会社名なら電話番号は同僚と共有できます。席位に招待された方は、招待メールのアドレスで登録・ログインしてください。',
        'Enter your name, address, phone, and email (company is optional). The address appears on order documents. After sign-up, verify with the email code and set a password. The same email cannot be registered twice on the same platform (iPhone/iPad, Mac, and Windows can each use the same email as separate accounts). Colleagues at the same company may share a phone number. If invited to a seat, register or sign in with the invited email.',
        '请输入姓名、住所、电话和邮箱（公司名可选）。住所会显示在注文书上。注册后请用邮件验证码确认并设置密码。同一平台下同一邮箱不能再次注册（iPhone/iPad、Mac、Windows 可分别用同一邮箱注册成独立账号）。同一公司名下可与同事共用电话。被席位邀请时，请用邀请邮件中的邮箱注册或登录。',
        'Nhập họ tên, địa chỉ, số điện thoại và email (tên công ty không bắt buộc). Địa chỉ hiện trên phiếu đặt hàng. Sau đăng ký, xác minh bằng mã email rồi đặt mật khẩu. Không đăng ký lại cùng email trên cùng nền tảng (iPhone/iPad, Mac và Windows có thể dùng chung email như các tài khoản riêng). Cùng công ty có thể dùng chung số điện thoại. Nếu được mời vào chỗ, hãy đăng ký/đăng nhập bằng email được mời.',
      );
  String get companyOrName =>
      _p('会社名／名前', 'Company / name', '公司名／姓名', 'Công ty / tên');
  String get companyOptional =>
      _p('会社名（任意）', 'Company (optional)', '公司名（可选）', 'Công ty (không bắt buộc)');
  String get companyNameLabel =>
      _p('会社名', 'Company', '公司名', 'Công ty');
  String get contactNameLabel =>
      _p('氏名', 'Full name', '姓名', 'Họ và tên');
  String get phone => _p('電話番号', 'Phone', '电话', 'Số điện thoại');
  String get inviteCodeOptional =>
      _p('招待コード（任意）', 'Invite code (optional)', '招待コード（可选）', 'Mã mời (không bắt buộc)');
  String get doRegister => _p('登録する', 'Register', '注册', 'Đăng ký');
  String get fieldRequired => _p(
        'を入力してください',
        ' is required',
        '请填写',
        ' là bắt buộc',
      );
  String pleaseEnter(String label) => switch (lang) {
        AppLang.ja => '$labelを入力してください',
        AppLang.en => 'Enter $label',
        AppLang.zh => '请输入$label',
        AppLang.vi => 'Vui lòng nhập $label',
      };
  String get registerDone => _p('登録完了', 'Registered', '注册完成', 'Đăng ký xong');
  String registerMailSent(String email) => _p(
        '認証コードを $email に送信しました。\n次の画面でコードを入力してください。',
        'A verification code was sent to $email.\nEnter the code on the next screen.',
        '已向 $email 发送验证码。\n请在下一屏输入验证码。',
        'Đã gửi mã xác minh tới $email.\nHãy nhập mã ở màn hình tiếp theo.',
      );

  String get verifyEmailTitle =>
      _p('メール認証', 'Email verification', '邮箱验证', 'Xác minh email');
  String verifyEmailHint(String email) => _p(
        '$email に送った6桁の認証コードを入力してください。有効期限は5分です。',
        'Enter the 6-digit code sent to $email. It expires in 5 minutes.',
        '请输入发送到 $email 的6位验证码。有效期5分钟。',
        'Nhập mã 6 số gửi tới $email. Có hiệu lực 5 phút.',
      );
  String get verifyCodeLabel =>
      _p('認証コード（6桁）', 'Verification code (6 digits)', '验证码（6位）', 'Mã xác minh (6 số)');
  String get verifyCodeAction =>
      _p('認証する', 'Verify', '验证', 'Xác minh');
  String get resendCode =>
      _p('認証コードを再送信', 'Resend code', '重新发送验证码', 'Gửi lại mã');
  String get resendCodeSent =>
      _p('認証コードを再送信しました', 'Verification code resent', '已重新发送验证码', 'Đã gửi lại mã xác minh');
  String get verifyCodeInvalid =>
      _p('認証コードが正しくありません', 'Invalid verification code', '验证码不正确', 'Mã xác minh không đúng');
  String get emailNotVerified => _p(
        '先にメール認証を完了してください',
        'Complete email verification first',
        '请先完成邮箱验证',
        'Hãy xác minh email trước',
      );
  String get emailVerifyRequiredBody => _p(
        'メール認証が未完了です。認証コードを再送信し、認証画面へ進みますか？',
        'Email is not verified yet. Resend the code and continue to verification?',
        '邮箱尚未验证。是否重新发送验证码并进入验证页面？',
        'Email chưa được xác minh. Gửi lại mã và tiếp tục xác minh?',
      );
  String get gotoEmailVerify => _p(
        'メール認証へ（コード再送）',
        'Verify email (resend code)',
        '去邮箱验证（重发验证码）',
        'Xác minh email (gửi lại mã)',
      );
  String get resumeRegistrationTitle => _p(
        '登録の続き',
        'Continue registration',
        '继续完成注册',
        'Tiếp tục đăng ký',
      );
  String resumeRegistrationBody(String email) => _p(
        '$email は登録途中です。認証コードを再送しました。次の画面でコードを入力し、パスワードを設定してください。',
        '$email has an incomplete registration. We resent a verification code. Enter it next, then set a password.',
        '$email 的注册尚未完成。已重新发送验证码，请在下一页输入后设置密码。',
        '$email chưa hoàn tất đăng ký. Đã gửi lại mã xác minh. Nhập mã ở bước tiếp theo rồi đặt mật khẩu.',
      );
  String get invalidEmail =>
      _p('メールアドレスの形式が正しくありません', 'Invalid email format', '邮箱格式不正确', 'Định dạng email không đúng');
  String get invalidPhone =>
      _p('電話番号を正しく入力してください', 'Enter a valid phone number', '请正确输入电话号码', 'Nhập số điện thoại hợp lệ');
  String get invalidAddress =>
      _p('住所を正しく入力してください', 'Enter a valid address', '请正确输入住所', 'Nhập địa chỉ hợp lệ');
  String get networkRequired => _p(
        '登録にはインターネット接続が必要です',
        'An internet connection is required to register',
        '注册需要联网',
        'Cần kết nối mạng để đăng ký',
      );
  String get registerFailed =>
      _p('登録に失敗しました。再試行してください', 'Registration failed. Please try again.', '注册失败，请重试', 'Đăng ký thất bại. Thử lại.');
  String get resendFailed =>
      _p('再送信に失敗しました', 'Failed to resend', '重新发送失败', 'Gửi lại thất bại');

  String get activateTitle =>
      _p('アカウント活性化', 'Activate account', '账号激活', 'Kích hoạt tài khoản');
  String get resetPasswordTitle =>
      _p('パスワード再設定', 'Reset password', '重设密码', 'Đặt lại mật khẩu');
  String get activateHint => _p(
        'メール認証が完了しました。パスワードを設定するとアカウントが有効になります。',
        'Email verified. Setting a password activates your account.',
        '邮箱验证已完成。设置密码后账号即生效。',
        'Đã xác minh email. Đặt mật khẩu để kích hoạt tài khoản.',
      );
  String get resetHint => _p(
        '新しいパスワードを設定してください。',
        'Set a new password.',
        '请设置新密码。',
        'Hãy đặt mật khẩu mới.',
      );
  String get passwordMin6 =>
      _p('パスワード（6文字以上）', 'Password (6+ characters)', '密码（至少6位）', 'Mật khẩu (từ 6 ký tự)');
  String get passwordConfirm =>
      _p('パスワード確認', 'Confirm password', '确认密码', 'Xác nhận mật khẩu');
  String get setPasswordActivate =>
      _p('パスワードを設定して有効化', 'Set password and activate', '设置密码并启用', 'Đặt mật khẩu và kích hoạt');
  String get resetPasswordAction =>
      _p('パスワードを再設定', 'Reset password', '重设密码', 'Đặt lại mật khẩu');
  String get passwordMismatch =>
      _p('パスワードが一致しません', 'Passwords do not match', '两次密码不一致', 'Mật khẩu không khớp');

  String get findEmailTitle =>
      _p('メールアドレスを探す', 'Find email', '查找邮箱', 'Tìm email');
  String get familyName => _p('姓', 'Family name', '姓', 'Họ');
  String get givenName => _p('名', 'Given name', '名', 'Tên');
  String get enterFamilyGiven =>
      _p('姓と名を入力してください', 'Enter family and given name', '请输入姓和名', 'Nhập họ và tên');
  String foundEmail(String email) => _p(
        'ご登録のメールアドレスは $email です。',
        'Your registered email is $email.',
        '您注册的邮箱是 $email。',
        'Email đã đăng ký là $email.',
      );

  String get forgotPasswordTitle =>
      _p('パスワード再設定', 'Reset password', '重设密码', 'Đặt lại mật khẩu');

  String get accountTitle =>
      _p('アカウント管理', 'Account', '账号管理', 'Quản lý tài khoản');
  String get notLoggedIn =>
      _p('ログインしていません', 'Not signed in', '尚未登录', 'Chưa đăng nhập');
  String get notice => _p('お知らせ', 'Notice', '通知', 'Thông báo');
  String get noticeEmpty => _p(
        'お知らせはまだありません',
        'No notices yet',
        '暂无通知',
        'Chưa có thông báo',
      );
  String get accountInfo =>
      _p('アカウント情報', 'Account info', '账号信息', 'Thông tin tài khoản');
  String get accountName =>
      _p('アカウント名', 'Account name', '账号名', 'Tên tài khoản');
  String get remainingDays =>
      _p('利用可能日数', 'Days remaining', '可用天数', 'Số ngày còn lại');
  String daysUnit(int n) => switch (lang) {
        AppLang.ja => '$n日',
        AppLang.en => '$n days',
        AppLang.zh => '$n天',
        AppLang.vi => '$n ngày',
      };
  String get uploadQuotaLabel =>
      _p('図面アップロード', 'Drawing uploads', '图纸上传', 'Tải bản vẽ');
  String get uploadUnlimited =>
      _p('無制限', 'Unlimited', '无限制', 'Không giới hạn');
  String uploadRemainingLabel(int remaining, int limit) => _p(
        '今月 残り$remaining / $limit 枚',
        'This month: $remaining / $limit left',
        '本月剩余 $remaining / $limit 张',
        'Tháng này còn $remaining / $limit',
      );
  String get seatLimitLabel => _p('席数', 'Seats', '席位', 'Chỗ');
  String seatsUnit(int n) => switch (lang) {
        AppLang.ja => '$n席',
        AppLang.en => '$n seats',
        AppLang.zh => '$n席',
        AppLang.vi => '$n chỗ',
      };
  String seatsUsageLabel(int used, int limit, int remaining) => _p(
        '使用中 $used / $limit（残り$remaining）',
        'In use $used / $limit ($remaining left)',
        '已用 $used / $limit（剩余 $remaining）',
        'Đang dùng $used / $limit (còn $remaining)',
      );
  String get seatInvitePending =>
      _p('招待中', 'Invite pending', '邀请中', 'Đang mời');
  String get fullAccessHint => _p(
        'ログイン中は測定・試算・注文など全機能が使えます。無料は毎月の図面アップロード枚数に限りがあります。',
        'While signed in, all features are available. Free plan limits monthly drawing uploads.',
        '登录后可使用测量、试算、订货等全部功能。免费版仅限制每月图纸上传张数。',
        'Khi đăng nhập dùng được mọi tính năng. Gói miễn phí giới hạn số bản vẽ tải mỗi tháng.',
      );
  String get freeAccessHint => _p(
        '無料プラン：毎月図面を1枚までアップロードでき、その範囲ですべての機能をご利用いただけます。',
        'Free plan: upload up to 1 drawing per month, with full features within that quota.',
        '免费套餐：每月最多上传1张图纸，在张数内可使用全部功能。',
        'Gói miễn phí: tối đa 1 bản vẽ/tháng, đủ tính năng trong hạn mức.',
      );
  String get planVersion =>
      _p('利用バージョン', 'Plan', '使用版本', 'Phiên bản');
  String get free => _p('無料', 'Free', '免费', 'Miễn phí');
  String get paid => _p('有料', 'Paid', '付费', 'Trả phí');
  String paidSeatSummary(int seats) => _p(
        '席位プラン（$seats席）',
        'Seat plan ($seats seats)',
        '席位套餐（$seats席）',
        'Gói chỗ ($seats chỗ)',
      );
  String get chooseSeatPack =>
      _p('席数を選んで購入', 'Choose seats to purchase', '选择席位购买', 'Chọn số chỗ để mua');
  String buySeatPack(String label, int yen) => _p(
        '$label（月額¥${_yen(yen)}）',
        '$label (¥${_yen(yen)}/mo)',
        '$label（月额¥${_yen(yen)}）',
        '$label (¥${_yen(yen)}/tháng)',
      );
  String _yen(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String get paidNotice => _p(
        '席位プランはApp Storeの月額課金です。購入者のメールが組織オーナーとなり、席数まで同僚を招待できます。有料中は図面アップロード無制限。解約は設定のサブスクリプションから。お支払い済みの月分は返金されません。',
        'Seat plans are monthly App Store subscriptions. The purchaser’s email becomes the org owner and can invite colleagues up to the seat limit. Uploads are unlimited while paid. Cancel in Settings > Subscriptions. The current month is non-refundable.',
        '席位套餐为 App Store 月额。购买者邮箱为组织所有者，可在席数内邀请同事。付费期间图纸上传无限制。可在设置的订阅中解约。已支付月份不予退款。',
        'Gói chỗ là đăng ký tháng qua App Store. Email người mua là chủ tổ chức, mời đồng nghiệp trong hạn chỗ. Upload không giới hạn khi trả phí. Hủy trong Cài đặt > Đăng ký. Tháng đã trả không hoàn.',
      );
  String get startPaid =>
      _p('席位プランを購入', 'Buy a seat plan', '购买席位套餐', 'Mua gói chỗ');
  String get cancelPlan => _p('解約する', 'Cancel', '解约', 'Hủy');
  String get restorePurchases =>
      _p('購入を復元', 'Restore purchases', '恢复购买', 'Khôi phục mua hàng');
  String get storePlatformOnly => _p(
        'Windows版ではアプリ内課金に未対応です。席位プラン・お支払いはサポートへご連絡ください。',
        'In-app purchases are not available on Windows. Contact support for seat plans and payment.',
        'Windows 版暂不支持应用内购买。席位套餐与付款请联系客服。',
        'Windows chưa hỗ trợ mua trong ứng dụng. Liên hệ hỗ trợ về gói chỗ và thanh toán.',
      );
  String get storeUnavailable => _p(
        'App Storeに接続できません。通信を確認してください',
        'Could not reach the App Store. Check your connection.',
        '无法连接 App Store。请检查网络。',
        'Không kết nối được App Store. Hãy kiểm tra mạng.',
      );
  String get storeProductMissing => _p(
        '席位プランを取得できません。設定→App Storeのサンドボックスアカウントでテスト用Apple IDにログインし、Connectのサブスクリプションが提出準備完了か確認してください',
        'Could not load seat plans. Sign in with a Sandbox Apple ID in Settings > App Store, and check subscriptions are Ready to Submit in App Store Connect.',
        '无法获取席位套餐。请在设置→App Store的沙盒账号登录测试用 Apple ID，并确认 Connect 里的订阅已是“准备提交”。',
        'Không tải được gói chỗ. Đăng nhập Sandbox Apple ID trong Cài đặt > App Store, và kiểm tra subscription đã Ready to Submit.',
      );
  String get storeBuyFailed => _p(
        '購入を開始できませんでした。時間をおいて再試行してください',
        'Could not start the purchase. Try again later.',
        '无法开始购买。请稍后再试。',
        'Không bắt đầu mua được. Thử lại sau.',
      );
  String get teamMembersTitle =>
      _p('チーム席位', 'Team seats', '团队席位', 'Chỗ nhóm');
  String get teamMemberSeatHint => _p(
        'オーナーの席位プランに参加中です。解約・席数変更はオーナーが行います。',
        'You are on the owner’s seat plan. The owner manages cancel and seat changes.',
        '您正在使用所有者的席位套餐。解约与席数变更由所有者操作。',
        'Bạn đang dùng gói chỗ của chủ. Chủ quản lý hủy và đổi số chỗ.',
      );
  String teamMembersHint(int seats) => _p(
        '購入者のメール（このアカウント）がオーナーです。最大$seats席まで同僚を招待でき、途中でオーナーメール変更や同僚の差し替えもできます。',
        'Your email owns the org. Invite up to $seats seats; you can also change the owner email and replace colleagues later.',
        '购买者邮箱（本账号）为所有者。最多可邀请 $seats 席同事，途中也可更换所有者邮箱或替换同事。',
        'Email của bạn là chủ. Mời tối đa $seats chỗ; có thể đổi email chủ và thay đồng nghiệp sau.',
      );
  String get colleagueEmail =>
      _p('同僚のメール', 'Colleague email', '同事邮箱', 'Email đồng nghiệp');
  String get inviteColleague =>
      _p('メールで招待', 'Invite by email', '用邮箱邀请', 'Mời bằng email');
  String get changeOwnerEmail =>
      _p('オーナーメールを変更', 'Change owner email', '更换所有者邮箱', 'Đổi email chủ');
  String get changeOwnerEmailHint => _p(
        '新しいメールに6桁の認証コードを送ります。確認後、このアカウントのログインメールが切り替わります。',
        'We send a 6-digit code to the new address. After confirmation, this account signs in with that email.',
        '将向新邮箱发送6位验证码。确认后，本账号的登录邮箱会切换。',
        'Gửi mã 6 số tới email mới. Sau khi xác nhận, tài khoản đăng nhập bằng email đó.',
      );
  String get newOwnerEmailLabel =>
      _p('新しいメールアドレス', 'New email address', '新邮箱地址', 'Email mới');
  String get sendChangeEmailCode =>
      _p('認証コードを送る', 'Send verification code', '发送验证码', 'Gửi mã xác minh');
  String get changeEmailCodeSent => _p(
        '新しいメールに認証コードを送りました',
        'Verification code sent to the new email',
        '验证码已发送到新邮箱',
        'Đã gửi mã tới email mới',
      );
  String get changeEmailSuccess => _p(
        'オーナーメールを変更しました',
        'Owner email updated',
        '所有者邮箱已更换',
        'Đã đổi email chủ',
      );
  String get changeEmailFailed =>
      _p('メール変更に失敗しました', 'Could not change email', '更换邮箱失败', 'Không đổi được email');
  String get emailUnchanged => _p(
        '現在と同じメールアドレスです',
        'That is the same as the current email',
        '与当前邮箱相同',
        'Trùng email hiện tại',
      );
  String get replaceColleague =>
      _p('差し替え', 'Replace', '替换', 'Thay');
  String get replaceColleagueTitle => _p(
        '同僚を差し替え',
        'Replace colleague',
        '替换同事',
        'Thay đồng nghiệp',
      );
  String replaceColleagueHint(String oldEmail) => _p(
        '$oldEmail の席を別のメールへ差し替えます。相手には新しい招待メールが届きます。',
        'Replace the seat for $oldEmail with another email. A new invite will be sent.',
        '将把 $oldEmail 的席位替换为其他邮箱，并向新邮箱发送邀请。',
        'Thay chỗ của $oldEmail bằng email khác. Sẽ gửi lời mời mới.',
      );
  String get newColleagueEmailLabel =>
      _p('新しい同僚のメール', 'New colleague email', '新同事邮箱', 'Email đồng nghiệp mới');
  String get replaceColleagueAction =>
      _p('差し替えて招待', 'Replace & invite', '替换并邀请', 'Thay và mời');
  String get replaceColleagueSuccess => _p(
        '同僚を差し替え、招待メールを送りました',
        'Colleague replaced and invite sent',
        '已替换同事并发送邀请邮件',
        'Đã thay đồng nghiệp và gửi lời mời',
      );
  String get replaceColleagueFailed =>
      _p('差し替えに失敗しました', 'Could not replace colleague', '替换失败', 'Không thay được');
  String get orgInviteSent => _p(
        '招待メールを送りました。相手は1時間以内にアプリをインストールし、そのメールで新規登録・ログインすると席に入ります。届かない場合はメールを確認して再招待できます。',
        'Invite sent. They must install the app and register/sign in with that email within 1 hour. If it doesn’t arrive, check the address and re-invite.',
        '已发送邀请邮件。对方须在1小时内安装应用，并用该邮箱完成注册/登录才可入席。若未收到，请核对邮箱后重新邀请。',
        'Đã gửi lời mời. Trong 1 giờ phải cài app và đăng ký/đăng nhập bằng email đó. Nếu không nhận được, kiểm tra email rồi mời lại.',
      );
  String get orgSeatFull =>
      _p('席数が上限です', 'Seat limit reached', '席位已满', 'Đã hết chỗ');
  String get inviteFriends =>
      _p('友達に紹介', 'Invite friends', '介绍给朋友', 'Mời bạn bè');
  String inviteCodeLabel(String code) => _p(
        '招待コード：$code',
        'Invite code: $code',
        '招待コード：$code',
        'Mã mời: $code',
      );
  String get inviteHint => _p(
        '上の招待コードを友達に送ってください。友達が登録時にこのコードを入力しログインすると、紹介された方に当月の図面アップロードが2枚追加されます（無料は当月最大3枚・前月繰越なし）。すでに登録済みの方には送れません。同一招待コードの成功は毎月2回までです。',
        'Send the invite code. When a friend signs up with it and logs in, they get +2 drawing uploads for the month (free plan max 3/month, no carry-over). Already registered accounts cannot be invited. Each invite code can succeed at most twice per month.',
        '请把上面的招待コード发给朋友。朋友注册填写并登录后，被介绍方当月图纸上传+2张（免费当月最多3张、不跨月累计）。已注册账号不可发送。同一招待コード每月最多成功2次。',
        'Gửi mã mời. Khi bạn bè đăng ký bằng mã và đăng nhập, được +2 bản vẽ trong tháng (miễn phí tối đa 3/tháng, không cộng dồn tháng trước). Không gửi cho tài khoản đã đăng ký. Mỗi mã tối đa 2 lần thành công/tháng.',
      );

  String get feedbackTitle =>
      _p('意見・要望報告', 'Feedback', '意见／要望报告', 'Góp ý / yêu cầu');
  String get feedbackHint => _p(
        '改善の意見や機能の要望を運営へ送れます。採用された場合、図面アップロード回数が追加されます。',
        'Send opinions or feature requests to operations. If adopted, extra drawing uploads are added.',
        '可向运营发送改进意见或功能要望。被采纳后会增加图纸上传次数。',
        'Gửi góp ý hoặc yêu cầu tính năng. Nếu được chọn, bạn được thêm lượt tải bản vẽ.',
      );
  String get feedbackKind => _p('区分', 'Type', '类别', 'Loại');
  String get feedbackOpinion => _p('意見', 'Opinion', '意见', 'Góp ý');
  String get feedbackRequest => _p('要望', 'Request', '要望', 'Yêu cầu');
  String get feedbackSubject => _p('件名', 'Subject', '标题', 'Tiêu đề');
  String get feedbackBody => _p('本文', 'Details', '正文', 'Nội dung');
  String get feedbackSend => _p('送信する', 'Send', '发送', 'Gửi');
  String get feedbackSent => _p(
        '送信しました。採用された場合はアカウント画面でお知らせします。',
        'Sent. If adopted, you will see a notice on the account screen.',
        '已发送。若被采纳，会在账号页通知。',
        'Đã gửi. Nếu được chọn, bạn sẽ thấy thông báo ở trang tài khoản.',
      );
  String get feedbackNeedText => _p(
        '件名と本文（8文字以上）を入力してください',
        'Enter a subject and at least 8 characters of details',
        '请填写标题和正文（至少8字）',
        'Hãy nhập tiêu đề và nội dung (từ 8 ký tự)',
      );
  String get feedbackFailed => _p(
        '送信できませんでした。通信を確認して再試行してください',
        'Could not send. Check the connection and try again.',
        '发送失败。请检查网络后重试。',
        'Không gửi được. Kiểm tra mạng rồi thử lại.',
      );
  String get feedbackOffline => _p(
        'オフラインのため送信できません',
        'Cannot send while offline',
        '离线无法发送',
        'Đang ngoại tuyến, không gửi được',
      );
  String get feedbackImages =>
      _p('画像（任意）', 'Images (optional)', '图片（可选）', 'Ảnh (không bắt buộc)');
  String get feedbackImagesHint => _p(
        'アルバムから最大3枚まで添付できます（スクリーンショット・写真）。',
        'Attach up to 3 images from your album (screenshots or photos).',
        '可从相册最多附上3张图片（截图或照片）。',
        'Đính kèm tối đa 3 ảnh từ album (ảnh chụp màn hình hoặc ảnh).',
      );
  String get feedbackAddImage =>
      _p('アルバムから追加', 'Add from album', '从相册添加', 'Thêm từ album');
  String get feedbackImageMax => _p(
        '画像は3枚までです',
        'You can attach up to 3 images',
        '最多3张图片',
        'Tối đa 3 ảnh',
      );

  String get appSettings => _p('アプリ設定', 'App settings', 'App设定', 'Cài đặt ứng dụng');
  String get displayLanguage =>
      _p('表示言語', 'Language', '显示语言', 'Ngôn ngữ hiển thị');
  String get languageNote => _p(
        '初期値は端末の言語です。日本語・英語・中国語・ベトナム語以外は日本語になります。材料品名と注文書の内容は常に日本語です。',
        'Default follows the device language. Other languages fall back to Japanese. Material names and order documents stay in Japanese.',
        '默认跟随设备语言。除日语、英语、中文、越南语以外均使用日语。材料品名和订货单内容始终为日语。',
        'Mặc định theo ngôn ngữ máy. Ngoài Nhật, Anh, Trung, Việt thì dùng tiếng Nhật. Tên vật tư và phiếu đặt hàng luôn bằng tiếng Nhật.',
      );

  String get sitesTitle =>
      _p('LGS+積算 現場一覧', 'LGS+ Sites', 'LGS+積算 现场一览', 'LGS+ Danh sách công trường');
  String get logout => _p('ログアウト', 'Log out', '退出登录', 'Đăng xuất');
  String get deleteAccount =>
      _p('アカウントを削除', 'Delete account', '删除账号', 'Xóa tài khoản');
  String get deleteAccountTitle =>
      _p('アカウント削除', 'Delete account', '删除账号', 'Xóa tài khoản');
  String get deleteAccountBody => _p(
        'アカウントとサーバー上の個人情報を削除します。この端末の現場・図面・測定データも消えます。有料プランは App Store のサブスクリプション管理から別途解約してください。この操作は取り消せません。',
        'This deletes your account and personal data on the server. Sites, drawings, and measurements on this device are also removed. Cancel any paid subscription separately in App Store settings. This cannot be undone.',
        '将删除账号及服务器上的个人信息。本机现场、图纸、测量数据也会清除。付费订阅请另行在 App Store 订阅管理中取消。此操作不可撤销。',
        'Sẽ xóa tài khoản và dữ liệu cá nhân trên máy chủ. Công trường, bản vẽ, đo trên máy này cũng bị xóa. Hủy gói trả phí riêng trong App Store. Không hoàn tác được.',
      );
  String get deleteAccountConfirm => _p(
        '削除する',
        'Delete',
        '确认删除',
        'Xóa',
      );
  String get deleteAccountPasswordHint => _p(
        '確認のためパスワードを入力',
        'Enter password to confirm',
        '请输入密码以确认',
        'Nhập mật khẩu để xác nhận',
      );
  String get deleteAccountNeedNetwork => _p(
        'アカウント削除にはネット接続が必要です',
        'Account deletion requires a network connection',
        '删除账号需要联网',
        'Cần mạng để xóa tài khoản',
      );
  String get wrongPassword => _p(
        'パスワードが違います',
        'Incorrect password',
        '密码不正确',
        'Sai mật khẩu',
      );
  String get deleteAccountDone => _p(
        'アカウントを削除しました',
        'Account deleted',
        '账号已删除',
        'Đã xóa tài khoản',
      );
  String get sessionKicked => _p(
        'このアカウントは別の端末でログインしたため、こちらはログアウトしました。同時に使える端末は1台です。',
        'This account signed in on another device, so you were signed out here. Only one device can be used at a time.',
        '此账号已在其他设备登录，本机已退出。同一账号同时只能使用一台设备。',
        'Tài khoản đã đăng nhập trên thiết bị khác nên máy này bị đăng xuất. Chỉ dùng được một thiết bị cùng lúc.',
      );
  String get deviceSwitchCooldown => _p(
        'この端末は別のアカウントに紐づいています。切替は申請から3日後〜さらに7日以内のみ可能です。期間を過ぎると再度申請（3日待ち）が必要です。',
        'This device is linked to another account. You can switch only from 3 days after requesting until 7 days after that. Miss the window and you must wait 3 days again.',
        '本机已绑定其他账号。换绑需先申请，满3天后起有7天窗口可用新账号登录；过期未换则仍仅旧账号可用，再换需重新等3天。',
        'Thiết bị này gắn tài khoản khác. Đổi chỉ sau 3 ngày chờ, rồi trong 7 ngày tiếp theo. Quá hạn phải chờ lại 3 ngày.',
      );
  String get newSite => _p('新規現場', 'New site', '新建现场', 'Công trường mới');
  String get freeBanner => _p(
        '無料版：図面アップロード・スケール設定・図面測定のみ。試算表・材料・注文は有料または特典期間中に利用できます。',
        'Free plan: drawings, scale, and measure only. Estimates, materials, and orders need paid or bonus access.',
        '免费版：仅图纸上传、比例设定和测量。试算表、材料、订货需付费或特典期内使用。',
        'Bản miễn phí: chỉ bản vẽ, tỷ lệ và đo. Bảng tính, vật tư, đặt hàng cần gói trả phí hoặc ưu đãi.',
      );
  String get noSites => _p(
        '現場がありません\n右下から新規作成してください',
        'No sites yet\nCreate one with the button at the bottom right',
        '还没有现场\n请点右下角新建',
        'Chưa có công trường\nTạo mới ở góc dưới bên phải',
      );

  String get siteName => _p('現場名称', 'Site name', '现场名称', 'Tên công trường');
  String get address => _p('住所', 'Address', '地址', 'Địa chỉ');
  String get contactPerson =>
      _p('連絡先担当者', 'Contact person', '联系人', 'Người liên hệ');
  String get create => _p('作成する', 'Create', '创建', 'Tạo');
  String enterShort(String label) => switch (lang) {
        AppLang.ja => '$labelを入力',
        AppLang.en => 'Enter $label',
        AppLang.zh => '请填写$label',
        AppLang.vi => 'Nhập $label',
      };

  String get uploadDrawing =>
      _p('図面アップロード', 'Upload drawing', '上传图纸', 'Tải bản vẽ');
  String get measure => _p('測定', 'Measure', '测量', 'Đo');
  String get order => _p('注文', 'Order', '订货', 'Đặt hàng');
  String get orderSelectTitle =>
      _p('注文 — 試算表選択', 'Order — choose estimate', '订货 — 选择试算表', 'Đặt hàng — chọn bảng tính');
  String get orderHistoryTitle =>
      _p('注文書履历', 'Order history', '注文书履历', 'Lịch sử phiếu đặt');
  String get orderHistoryAction =>
      _p('履历', 'History', '履历', 'Lịch sử');
  String get orderHistoryEmpty => _p(
        'まだ送信した注文書はありません。注文書を共有するとここに保存されます。',
        'No exported orders yet. Shared order sheets appear here.',
        '还没有发送过的注文书。分享注文书后会保存在这里。',
        'Chưa có phiếu đã gửi. Phiếu chia sẻ sẽ lưu ở đây.',
      );
  String get orderHistoryDeleteTitle =>
      _p('履历を削除', 'Delete history', '删除履历', 'Xóa lịch sử');
  String get orderHistoryDeleteBody => _p(
        'この注文書履历を削除しますか？',
        'Delete this order history entry?',
        '要删除这条注文书履历吗？',
        'Xóa mục lịch sử phiếu đặt này?',
      );
  String get goOrderDoc => _p('注文書へ', 'To order sheet', '前往注文书', 'Tới phiếu đặt');
  String get pickEstimateToOrder =>
      _p('注文する試算表を選択してください', 'Choose an estimate to order', '请选择要订货的试算表', 'Hãy chọn bảng tính để đặt hàng');
  String get splitBoardLgsOrder => _p(
        'ボード試算表と LGS試算表は分けて注文してください',
        'Order board and LGS estimates separately',
        '板材试算表和 LGS试算表请分开订货',
        'Hãy đặt bảng tấm và bảng LGS riêng',
      );
  String get selectedEstimateEmpty =>
      _p('選択した試算表に明細がありません', 'The selected estimate has no lines', '所选试算表没有明细', 'Bảng đã chọn chưa có dòng');
  String get editLineTitle => _p('明細編集', 'Edit line', '编辑明细', 'Sửa dòng');
  String get addItemTitle => _p('追加項目', 'Add item', '追加项目', 'Thêm mục');
  String get addItemNameHint =>
      _p('品名（例：接着剤）', 'Name (e.g. adhesive)', '品名（例：胶水）', 'Tên (vd: keo)');
  String get add => _p('追加', 'Add', '添加', 'Thêm');
  String get save => _p('保存', 'Save', '保存', 'Lưu');
  String get extraMaterial => _p('追加材料', 'Extra material', '追加材料', 'Vật tư thêm');
  String get itemName => _p('品名', 'Name', '品名', 'Tên');
  String get qty => _p('数量', 'Qty', '数量', 'SL');
  String get unit => _p('単位', 'Unit', '单位', 'Đơn vị');
  String qtyWithUnit(String u) => _p('数量（$u）', 'Qty ($u)', '数量（$u）', 'SL ($u)');
  String get exportOrder =>
      _p('注文書をエクスポート', 'Export order', '导出注文书', 'Xuất phiếu đặt');
  String get shareLineEmail =>
      _p('共有（LINE / Email 等）', 'Share (LINE / email…)', '分享（LINE / 邮件等）', 'Chia sẻ (LINE / email…)');
  String get saveLocally =>
      _p('ファイルに保存', 'Save to Files', '保存到本地', 'Lưu vào Files');
  String get shareSend =>
      _p('共有・送信', 'Share / Send', '共享发送', 'Chia sẻ / Gửi');
  String get exportChooseTitle =>
      _p('書き出し方法', 'How to export', '导出方式', 'Cách xuất');
  String get printSystemShare =>
      _p('印刷 / システム共有', 'Print / system share', '打印／系统分享', 'In / chia sẻ hệ thống');
  String get preview => _p('プレビュー', 'Preview', '预览', 'Xem trước');
  String get orderPreview =>
      _p('注文書プレビュー', 'Order preview', '注文书预览', 'Xem phiếu đặt');
  String get orderLinesTitle => _p('注文明細', 'Order lines', '订货明细', 'Dòng đặt hàng');
  String get orderConfirm => _p('注文確認', 'Confirm order', '确认订货', 'Xác nhận đặt');
  String orderDateLabel(String date) =>
      _p('発注日：$date', 'Order date: $date', '订货日：$date', 'Ngày đặt: $date');
  String deliveryWish(String date) =>
      _p('納品希望 $date', 'Delivery $date', '希望交货 $date', 'Giao $date');
  String get orderSelectHint => _p(
        '試算表は個別に保存されています。同じ種類を複数選ぶと注文書で合算します',
        'Estimates are saved separately. Selecting several of the same kind merges them on the order.',
        '试算表是分开保存的。选同一类多张会在注文书里合计。',
        'Bảng tính lưu riêng. Chọn nhiều cùng loại sẽ gộp trên phiếu đặt.',
      );
  String get noSavedEstimates => _p(
        '保存済みのボード／LGS／クロス試算表がありません\n測定で試算表を開き、保存してください',
        'No saved board / LGS / finish estimates.\nOpen an estimate from measure and save it.',
        '没有已保存的板材／LGS／墙纸试算表\n请在测量里打开试算表并保存。',
        'Chưa có bảng tấm / LGS / hoàn thiện đã lưu.\nHãy mở bảng tính khi đo rồi lưu.',
      );
  String get export => _p('書き出し', 'Export', '导出', 'Xuất');
  String get exporting =>
      _p('PDFを書き出しています…', 'Exporting PDF…', '正在导出PDF…', 'Đang xuất PDF…');
  String get selectExportDrawings => _p(
        '書き出す図面を選択',
        'Select drawings to export',
        '选择要导出的图纸',
        'Chọn bản vẽ cần xuất',
      );
  String get selectAll => _p('すべて選択', 'Select all', '全选', 'Chọn tất cả');
  String get deselectAll => _p('すべて解除', 'Clear all', '全不选', 'Bỏ chọn tất cả');
  String get noMeasuredExport => _p(
        '書き出せる測定図面がありません。先に測定してください。',
        'No measured drawings to export. Measure first.',
        '没有可导出的已测图纸。请先完成测量。',
        'Chưa có bản vẽ đã đo để xuất. Hãy đo trước.',
      );
  String get exportFailed =>
      _p('書き出しに失敗しました', 'Export failed', '导出失败', 'Xuất thất bại');
  String exportSubject(String site) => _p(
        '$site の測定図面',
        'Measured drawings — $site',
        '$site 的测量图纸',
        'Bản vẽ đo — $site',
      );
  String get unregistered => _p('未登録', 'None', '未登记', 'Chưa có');
  String get unmeasured => _p('未測定', 'Not measured', '未测量', 'Chưa đo');
  String get delete => _p('削除', 'Delete', '删除', 'Xóa');
  String get cancel => _p('キャンセル', 'Cancel', '取消', 'Hủy');
  String get close => _p('閉じる', 'Close', '关闭', 'Đóng');
  String get ok => _p('OK', 'OK', '确定', 'OK');
  String get done => _p('完了', 'Done', '完成', 'Xong');
  String get start => _p('開始', 'Start', '开始', 'Bắt đầu');
  String get deleteAction => _p('削除する', 'Delete', '删除', 'Xóa');
  String get uploadFirst => _p(
        '先に図面をアップロードしてください',
        'Upload a drawing first',
        '请先上传图纸',
        'Hãy tải bản vẽ trước',
      );
  String get scaleFirst => _p(
        '先に比例尺（スケール）を設定してください',
        'Set the scale first',
        '请先设定比例尺',
        'Hãy đặt tỷ lệ trước',
      );
  String get selectDrawing =>
      _p('測定する図面を選択', 'Select a drawing to measure', '选择要测量的图纸', 'Chọn bản vẽ để đo');
  String get measureName =>
      _p('測定プロジェクト名', 'Measurement name', '测量项目名', 'Tên phép đo');
  String get deleteDrawing => _p('図面を削除', 'Delete drawing', '删除图纸', 'Xóa bản vẽ');
  String get deleteMeasure => _p('測定を削除', 'Delete measurement', '删除测量', 'Xóa phép đo');
  String get deleteSite => _p('現場を削除', 'Delete site', '删除现场项目', 'Xóa công trường');
  String get confirmDelete => _p('削除する', 'Delete', '确认删除', 'Xác nhận xóa');
  String get macDeleteHint => _p(
        '削除：左にスワイプ、または右クリック（トラックパッドは二本指クリック）',
        'Delete: swipe left, or right-click (two-finger click on trackpad)',
        '删除：左滑，或鼠标右键（触控板为双指点击）',
        'Xóa: vuốt trái, hoặc chuột phải (hai ngón trên trackpad)',
      );
  String deletedItem(String name) => _p(
        '「$name」を削除しました',
        'Deleted “$name”',
        '已删除“$name”',
        'Đã xóa “$name”',
      );
  String deleteMeasureConfirm(String name) => _p(
        '「$name」を削除しますか？',
        'Delete “$name”?',
        '要删除“$name”吗？',
        'Xóa “$name”?',
      );
  String wallCeilingCount(int walls, int ceils) => _p(
        '壁 $walls / 天井 $ceils',
        'Walls $walls / Ceilings $ceils',
        '墙 $walls / 天花 $ceils',
        'Tường $walls / Trần $ceils',
      );
  String estimateLines(int n) => _p('明細 $n 行', '$n lines', '明细 $n 行', '$n dòng');
  String boardEstimateWall(String name) =>
      _p('ボード試算表（壁）— $name', 'Board estimate (wall) — $name', '板材试算表（墙）— $name', 'Bảng board (tường) — $name');
  String boardEstimateCeil(String name) =>
      _p('ボード試算表（天井）— $name', 'Board estimate (ceiling) — $name', '板材试算表（天花）— $name', 'Bảng board (trần) — $name');
  String lgsEstimateWall(String name) =>
      _p('LGS試算表（壁）— $name', 'LGS estimate (wall) — $name', 'LGS试算表（墙）— $name', 'Bảng LGS (tường) — $name');
  String lgsEstimateCeil(String name) =>
      _p('LGS試算表（天井）— $name', 'LGS estimate (ceiling) — $name', 'LGS试算表（天花）— $name', 'Bảng LGS (trần) — $name');
  String crossEstimate(String name) =>
      _p('クロス試算表 — $name', 'Finish estimate — $name', '墙纸试算表 — $name', 'Bảng hoàn thiện — $name');
  String dropEstimate(String name) =>
      _p('下り試算表 — $name', 'Drop estimate — $name', '下吊试算表 — $name', 'Bảng trần thả — $name');

  String get uploadIntro => _p(
        'フォルダまたはアルバムから図面を取り込み、既知寸法で比例尺を設定します。',
        'Import a drawing from a folder or album, then set scale with a known length.',
        '从文件夹或相册导入图纸，再用已知尺寸设定比例。',
        'Nhập bản vẽ từ thư mục hoặc album, rồi đặt tỷ lệ bằng kích thước biết trước.',
      );
  String get fromFolder =>
      _p('フォルダから選択（PDF / 画像）', 'Choose from folder (PDF / image)', '从文件夹选择（PDF / 图片）', 'Chọn từ thư mục (PDF / ảnh)');
  String get fromAlbum =>
      _p('アルバムから選択', 'Choose from album', '从相册选择', 'Chọn từ album');
  String get drawingSavedSetScale => _p(
        '図面を保存しました。続けて比例尺を設定してください',
        'Drawing saved. Set the scale next.',
        '图纸已保存。请接着设定比例。',
        'Đã lưu bản vẽ. Hãy đặt tỷ lệ tiếp theo.',
      );
  String get previewUnavailable =>
      _p('プレビュー不可', 'Preview unavailable', '无法预览', 'Không xem trước được');
  String get scaleUnset => _p('スケール未設定', 'Scale not set', '未设定比例', 'Chưa đặt tỷ lệ');
  String get setScale => _p('スケール設定', 'Set scale', '设定比例', 'Đặt tỷ lệ');

  String get upgradeTitle =>
      _p('アップロード上限です', 'Upload limit reached', '上传已达上限', 'Đã hết lượt tải');
  String get upgradeMessage => _p(
        '無料プランは毎月図面を1枚までです。席位プランに加入するとアップロード無制限になります。',
        'The free plan allows 1 drawing upload per month. A seat plan unlocks unlimited uploads.',
        '免费套餐每月最多上传1张图纸。加入席位套餐后上传无限制。',
        'Gói miễn phí cho phép 1 bản vẽ/tháng. Gói chỗ cho phép tải không giới hạn.',
      );
  String get uploadLimitTitle =>
      _p('アップロード上限です', 'Upload limit reached', '上传已达上限', 'Đã hết lượt tải');
  String get uploadLimitMessage => _p(
        '今月の無料アップロード回数を使い切りました。アカウント管理から席位プランをご検討ください。',
        'You have used this month’s free uploads. Consider a seat plan in Account.',
        '本月免费上传次数已用完。请在账号管理考虑席位套餐。',
        'Bạn đã dùng hết lượt tải miễn phí tháng này. Xem gói chỗ trong Tài khoản.',
      );
  String get goAccount =>
      _p('アカウント管理', 'Account', '账号管理', 'Quản lý tài khoản');

  String get sendMail => _p('メールで送る', 'Send email', '用邮件发送', 'Gửi email');
  String get sendSms => _p('SMSで送る', 'Send SMS', '用短信发送', 'Gửi SMS');
  String get sendLine => _p('LINEで送る', 'Send via LINE', '用LINE发送', 'Gửi LINE');
  String get sendWeChat =>
      _p('WeChatで送る', 'Send via WeChat', '用微信发送', 'Gửi WeChat');
  String get shareOther =>
      _p('その他のアプリで共有', 'Share with other apps', '用其他应用分享', 'Chia sẻ ứng dụng khác');
  String get inviteCopied =>
      _p('招待文をコピーしました', 'Invite text copied', '已复制邀请文', 'Đã sao chép lời mời');
  String get weChatShareTitle =>
      _p('WeChatで送る', 'Send via WeChat', '用微信发送', 'Gửi WeChat');
  String get weChatShareBody => _p(
        'WeChatは文字だけ送れないため、二次元コード＋招待コードの画像を送ります。\n\n本文もコピー済みです。次の画面でWeChatを選んでください。',
        'WeChat cannot receive plain text, so we send a QR image with the invite code.\n\nThe text is also copied. Choose WeChat on the next screen.',
        '微信无法直接发送纯文字，因此发送带二维码和招待コード的图片。\n\n正文也已复制。请在下一屏选择微信。',
        'WeChat không nhận chữ thuần, nên gửi ảnh mã QR kèm mã mời.\n\nNội dung đã được sao chép. Chọn WeChat ở màn hình tiếp theo.',
      );
  String get sendImage => _p('画像を送る', 'Send image', '发送图片', 'Gửi ảnh');
  String get inviteTo =>
      _p('宛先（メール / 電話番号）', 'To (email / phone)', '收件人（邮箱／电话）', 'Người nhận (email / SĐT)');
  String get subject => _p('件名', 'Subject', '主题', 'Tiêu đề');
  String get body => _p('本文', 'Message', '正文', 'Nội dung');
  String get copy => _p('コピー', 'Copy', '复制', 'Sao chép');

  String get emailTaken =>
      _p('このメールアドレスは既に登録されています', 'This email is already registered', '该邮箱已被注册', 'Email này đã được đăng ký');
  String get phoneTaken =>
      _p('この電話番号は既に登録されています', 'This phone number is already registered', '该电话已被注册', 'Số điện thoại này đã được đăng ký');
  String get inviteFriendAlreadyRegistered => _p(
        'この宛先はすでにアカウント登録済みです。紹介は未登録の方のみに送れます。',
        'This recipient already has an account. Invites are only for people who are not registered yet.',
        '该收件人已注册账号。介绍信只能发给尚未注册的人。',
        'Người nhận này đã có tài khoản. Chỉ gửi lời mời cho người chưa đăng ký.',
      );
  String get inviteNeedEmail => _p(
        'メール送信には宛先のメールアドレスを入力してください',
        'Enter the recipient email to send mail',
        '用邮件发送时请填写收件人邮箱',
        'Nhập email người nhận để gửi thư',
      );
  String get inviteNotFound =>
      _p('招待コードが見つかりません', 'Invite code not found', '找不到招待コード', 'Không tìm thấy mã mời');
  String get enterPhone =>
      _p('電話番号を入力してください', 'Enter a phone number', '请输入电话号码', 'Vui lòng nhập số điện thoại');
  String get passwordTooShort =>
      _p('パスワードは6文字以上にしてください', 'Password must be at least 6 characters', '密码至少6位', 'Mật khẩu phải từ 6 ký tự');
  String get accountNotFound =>
      _p('アカウントが見つかりません', 'Account not found', '找不到账号', 'Không tìm thấy tài khoản');
  String get badLogin =>
      _p('メールまたはパスワードが違います', 'Email or password is incorrect', '邮箱或密码不正确', 'Email hoặc mật khẩu không đúng');
  String get accountForIosOnly => _p(
        'このメールは iPhone / iPad 用アカウントです。Windows / Mac ではログイン・パスワード再設定できません。iPhone / iPad で再設定するか、同じメールでこの端末向けに新規登録してください（別アカウントになります）。',
        'This email is an iPhone / iPad account. You cannot sign in or reset its password on Windows / Mac. Reset it on iPhone / iPad, or register a separate account for this device with the same email.',
        '该邮箱是 iPhone / iPad 账号，无法在 Windows / Mac 登录或重设密码。请在 iPhone / iPad 上重设；若要在本机使用，可用同一邮箱新注册（独立账号）。',
        'Email này là tài khoản iPhone / iPad. Không đăng nhập/đặt lại mật khẩu trên Windows / Mac. Hãy đặt lại trên iPhone / iPad, hoặc đăng ký tài khoản riêng cho máy này bằng cùng email.',
      );
  String get accountForMacOnly => _p(
        'このメールは Mac 用アカウントです。Windows / iPhone / iPad ではログイン・パスワード再設定できません。Mac で再設定するか、同じメールでこの端末向けに新規登録してください（別アカウントになります）。',
        'This email is a Mac account. You cannot sign in or reset its password on Windows / iPhone / iPad. Reset it on Mac, or register a separate account for this device with the same email.',
        '该邮箱是 Mac 账号，无法在 Windows / iPhone / iPad 登录或重设密码。请在 Mac 上重设；若要在本机使用，可用同一邮箱新注册（独立账号）。',
        'Email này là tài khoản Mac. Không đăng nhập/đặt lại mật khẩu trên Windows / iPhone / iPad. Hãy đặt lại trên Mac, hoặc đăng ký tài khoản riêng cho máy này bằng cùng email.',
      );
  String get accountForWindowsOnly => _p(
        'このメールは Windows 用アカウントです。iPhone / iPad / Mac ではログイン・パスワード再設定できません。Windows で再設定するか、同じメールでこの端末向けに新規登録してください（別アカウントになります）。',
        'This email is a Windows account. You cannot sign in or reset its password on iPhone / iPad / Mac. Reset it on Windows, or register a separate account for this device with the same email.',
        '该邮箱是 Windows 账号，无法在 iPhone / iPad / Mac 登录或重设密码。请在 Windows 上重设；若要在本机使用，可用同一邮箱新注册（独立账号）。',
        'Email này là tài khoản Windows. Không đăng nhập/đặt lại mật khẩu trên iPhone / iPad / Mac. Hãy đặt lại trên Windows, hoặc đăng ký tài khoản riêng cho máy này bằng cùng email.',
      );
  String get registerWindowsWithSameEmail => _p(
        '同じメールで Windows 新規登録',
        'Register on Windows with this email',
        '用此邮箱在 Windows 新注册',
        'Đăng ký Windows bằng email này',
      );
  String get registerMacWithSameEmail => _p(
        '同じメールで Mac 新規登録',
        'Register on Mac with this email',
        '用此邮箱在 Mac 新注册',
        'Đăng ký Mac bằng email này',
      );
  String get scaleHintDesktopNav => _p(
        'ダブルクリックで拡大、クリックで縮小、ドラッグで移動',
        'Double-click zoom in, click zoom out, drag to pan',
        '双击放大，单击缩小，按住拖动移动图纸',
        'Double-click phóng to, click thu nhỏ, kéo để pan',
      );
  String get passwordNotSynced => _p(
        'この端末にはアカウントがありません。以前の端末で一度ログインして同期するか、サポートへご連絡ください',
        'This account is not on this device. Sign in once on the previous device to sync, or contact support.',
        '本机没有该账号数据。请在原设备登录一次完成同步，或联系客服。',
        'Tài khoản chưa có trên máy này. Đăng nhập trên máy cũ để đồng bộ, hoặc liên hệ hỗ trợ.',
      );
  String get notActivated => _p(
        'アカウントが未活性化です。メール認証のあとパスワードを設定してください',
        'Account is not activated. Verify your email, then set a password.',
        '账号尚未激活。请先完成邮箱验证再设置密码。',
        'Tài khoản chưa kích hoạt. Xác minh email rồi đặt mật khẩu.',
      );
  String get accountNotFoundDetail => _p(
        'アカウントが見つかりませんでした',
        'Account was not found',
        '未找到账号',
        'Không tìm thấy tài khoản',
      );

  String get confirmNameTitle =>
      _p('氏名の確認', 'Confirm name', '确认姓名', 'Xác nhận họ tên');
  String get enterRegisteredPhone => _p(
        'ご登録の電話番号を入力してください。',
        'Enter your registered phone number.',
        '请输入注册时的电话号码。',
        'Nhập số điện thoại đã đăng ký.',
      );
  String get findEmailIntro => _p(
        'ご登録の電話番号と氏名で、メールアドレスを確認できます。',
        'We can look up your email with your registered phone number and name.',
        '可用注册时的电话和姓名查找邮箱。',
        'Có thể tìm email bằng số điện thoại và họ tên đã đăng ký.',
      );
  String get useEmailToLogin =>
      _p('このメールでログイン', 'Sign in with this email', '用此邮箱登录', 'Đăng nhập bằng email này');
  String get resetPasswordWithEmail =>
      _p('このメールでパスワード再設定', 'Reset password with this email', '用此邮箱重设密码', 'Đặt lại mật khẩu bằng email này');
  String get enterFamilyGivenHint => _p(
        'ご登録の姓と名をそれぞれ入力してください。電話番号と氏名が一致するアカウントを確認します。',
        'Enter your registered family and given name. We match them with the phone number.',
        '请分别输入注册时的姓和名。将用电话和姓名核对账号。',
        'Nhập họ và tên đã đăng ký. Chúng tôi đối chiếu với số điện thoại.',
      );
  String get next => _p('次へ', 'Next', '下一步', 'Tiếp');
  String get confirmAction => _p('確認する', 'Confirm', '确认', 'Xác nhận');
  String get enterRegisteredEmail => _p(
        'ご登録のメールアドレスを入力してください。再設定用の認証コードを送信します。',
        'Enter your registered email. We will send a reset verification code.',
        '请输入注册邮箱。将发送重设用的验证码。',
        'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã xác minh đặt lại.',
      );
  String get sendResetLink =>
      _p('再設定リンクを送信', 'Send reset link', '发送重设链接', 'Gửi liên kết đặt lại');
  String get sendResetCode =>
      _p('認証コードを送信', 'Send verification code', '发送验证码', 'Gửi mã xác minh');
  String get sentTitle => _p('送信しました', 'Sent', '已发送', 'Đã gửi');
  String get resetSentEmail => _p(
        'ご登録のメールアドレスへ、パスワード再設定用の認証コードを送信しました。次の画面でコードを入力してください。',
        'A password-reset code was sent to your registered email. Enter it on the next screen.',
        '已向注册邮箱发送重设密码验证码。请在下一屏输入。',
        'Đã gửi mã đặt lại mật khẩu tới email đã đăng ký. Nhập mã ở màn hình tiếp theo.',
      );
  String resetVerifyHint(String email) => _p(
        '$email に送信した6桁の認証コードを入力してください。',
        'Enter the 6-digit code sent to $email.',
        '请输入发送到 $email 的6位验证码。',
        'Nhập mã 6 số đã gửi tới $email.',
      );
  String get resetSentDemo => _p(
        '（デモ：ローカル模擬。次の画面でパスワードを再設定できます。）',
        '(Demo: local simulation. You can reset the password on the next screen.)',
        '（演示：本地模拟。可在下一屏重设密码。）',
        '(Demo nội bộ. Có thể đặt lại mật khẩu ở màn hình tiếp theo.)',
      );
  String get legalLoadFailed => _p(
        '本文を読み込めませんでした。',
        'Could not load the document.',
        '无法读取正文。',
        'Không tải được nội dung.',
      );

  String cannotOpen(String app) => _p(
        '$appを開けませんでした。共有シートを使ってください。',
        'Could not open $app. Use the share sheet instead.',
        '无法打开$app。请改用系统分享。',
        'Không mở được $app. Hãy dùng bảng chia sẻ.',
      );
  String destPrefix(String dest) => _p(
        '宛先：$dest\n',
        'To: $dest\n',
        '收件人：$dest\n',
        'Đến: $dest\n',
      );
  String get inviteChannelHint => _p(
        'LINE・SMS・メールは本文を送れます。WeChatは二次元コード画像＋招待コードで送ります。',
        'LINE, SMS, and email can send the text. WeChat uses a QR image with the invite code.',
        'LINE、短信、邮件可发送正文。微信用二维码图片和招待コード发送。',
        'LINE, SMS và email gửi được nội dung. WeChat gửi ảnh mã QR kèm mã mời.',
      );
  String get imageFailed => _p(
        '画像を作れませんでした。招待文はコピー済みです。',
        'Could not create the image. The invite text is copied.',
        '无法生成图片。邀请文已复制。',
        'Không tạo được ảnh. Lời mời đã được sao chép.',
      );
  String get mail => _p('メール', 'Mail', '邮件', 'Email');

  String get inviteSubject => _p(
        'LGS+積算のご招待',
        'Invitation to LGS+',
        'LGS+積算邀请',
        'Lời mời LGS+',
      );
  String inviteBody(String code) => _p(
        'LGS+積算をご紹介します。\n\n'
        '招待コード：$code\n'
        '登録リンク：https://shop.infmaxai.com/invite?code=$code\n\n'
        'アプリをダウンロードし、新規登録画面でこの招待コードを入力してください。'
        '招待コードで登録・ログインした方に、当月の図面アップロードが2枚追加されます（無料は当月最大3枚・前月繰越なし）。受け取り操作は不要です。',
        'I would like to introduce LGS+.\n\n'
        'Invite code: $code\n'
        'Sign-up link: https://shop.infmaxai.com/invite?code=$code\n\n'
        'Download the app and enter this code on sign-up. The friend who registers with the code gets +2 drawing uploads for the month (free plan max 3/month, no carry-over). No claim step needed.',
        '向您介绍 LGS+積算。\n\n'
        '招待コード：$code\n'
        '注册链接：https://shop.infmaxai.com/invite?code=$code\n\n'
        '请下载应用，并在注册画面填写此招待コード。用招待コード注册并登录的一方，当月图纸上传+2张（免费当月最多3张、不跨月累计）。无需领取。',
        'Tôi muốn giới thiệu LGS+.\n\n'
        'Mã mời: $code\n'
        'Liên kết đăng ký: https://shop.infmaxai.com/invite?code=$code\n\n'
        'Tải ứng dụng và nhập mã này khi đăng ký. Người đăng ký bằng mã mời được +2 bản vẽ trong tháng (miễn phí tối đa 3/tháng, không cộng dồn). Không cần nhận thủ công.',
      );

  String get pdfRenderFailed =>
      _p('PDFレンダリングに失敗しました', 'Failed to render PDF', 'PDF渲染失败', 'Không kết xuất được PDF');
  String scaleK(String value) => 'K = $value px/mm';
  String get drawings => _p('図面', 'Drawings', '图纸', 'Bản vẽ');
  String get measureList =>
      _p('測定一覧', 'Measurements', '测量一览', 'Danh sách phép đo');
  String get scaleUnsetTap => _p(
        'スケール未設定 → タップして設定',
        'Scale not set → tap to set',
        '未设定比例 → 点按设定',
        'Chưa đặt tỷ lệ → chạm để đặt',
      );
  String get site => _p('現場', 'Site', '现场', 'Công trường');
  String get measureNameHint => _p(
        '例：1F 飲食エリア 壁と天井積算',
        'e.g. 1F dining — walls and ceiling',
        '例：1F 餐饮区 墙与天花积算',
        'VD: tầng 1 khu ăn uống — tường và trần',
      );
  String deleteNamedConfirm(String name) => deleteMeasureConfirm(name);

  String get scaleHintStart => _p(
        '実測値アイコンを始点までドラッグし、指を離して確定',
        'Drag the crosshair to the start point, then release',
        '将十字拖到起点后松手确定',
        'Kéo dấu thập tới điểm đầu rồi thả',
      );
  String get scaleHintEnd => _p(
        '始点確定。終点までドラッグして指を離してください',
        'Start set. Drag to the end point and release',
        '起点已定。拖到终点后松手',
        'Đã chốt điểm đầu. Kéo tới điểm cuối rồi thả',
      );
  String get scaleNeedDistance => _p(
        '始点から離れた位置で終点を指定してください',
        'Choose an end point away from the start',
        '请在离起点较远的位置指定终点',
        'Chọn điểm cuối cách điểm đầu',
      );
  String get enterRealSize =>
      _p('実寸を入力', 'Enter actual size', '输入实际尺寸', 'Nhập kích thước thật');
  String drawingDistancePx(String px) => _p(
        '図面上の距離: $px px',
        'Distance on drawing: $px px',
        '图纸上的距离：$px px',
        'Khoảng cách trên bản vẽ: $px px',
      );
  String get realSizeMm =>
      _p('実寸 (mm)', 'Actual size (mm)', '实际尺寸 (mm)', 'Kích thước thật (mm)');
  String get retry => _p('やり直す', 'Retry', '重做', 'Làm lại');
  String get confirmValue => _p('確定', 'OK', '确定', 'Xác nhận');
  String get invalidMm => _p(
        '正しいミリメートル値を入力してください（0より大きい数）',
        'Enter a valid millimeter value greater than 0',
        '请输入大于0的毫米值',
        'Nhập giá trị mm lớn hơn 0',
      );
  String scaleSaved(String px, String mm, String k) => _p(
        '比例尺をローカル保存しました  ${px}px ÷ ${mm}mm = K=$k px/mm',
        'Scale saved  ${px}px ÷ ${mm}mm = K=$k px/mm',
        '已保存比例  ${px}px ÷ ${mm}mm = K=$k px/mm',
        'Đã lưu tỷ lệ  ${px}px ÷ ${mm}mm = K=$k px/mm',
      );
  String get reset => _p('リセット', 'Reset', '重置', 'Đặt lại');
  String get measuring => _p('測定中', 'Measuring', '测量中', 'Đang đo');
  String get scaleHintIdleUnset => _p(
        'スケール設定ボタンを押し、十字を図面に出してください',
        'Tap Set scale, then place the crosshair on the drawing',
        '请点「设定比例」，再把十字放到图纸上',
        'Chạm Đặt tỷ lệ rồi đưa dấu thập lên bản vẽ',
      );
  String scaleHintIdleSaved(String k) => _p(
        '保存済み K=$k px/mm。再設定する場合はスケール設定へ',
        'Saved K=$k px/mm. Tap Set scale to change it',
        '已保存 K=$k px/mm。要重设请点设定比例',
        'Đã lưu K=$k px/mm. Chạm Đặt tỷ lệ để đổi',
      );
  String get scaleHintAimStart => _p(
        '十字を始点へドラッグ → 指を離して確定',
        'Drag the crosshair to the start, then release',
        '将十字拖到起点后松手确定',
        'Kéo dấu thập tới điểm đầu rồi thả',
      );
  String get scaleHintAimEnd => _p(
        '十字を終点へドラッグ → 指を離して実寸入力',
        'Drag the crosshair to the end, then release to enter size',
        '将十字拖到终点后松手输入实际尺寸',
        'Kéo dấu thập tới điểm cuối rồi thả để nhập kích thước',
      );
  String get scaleHintMacNav => scaleHintDesktopNav;
}

class LocaleScope extends StatelessWidget {
  const LocaleScope({super.key, required this.controller, required this.child});

  final LocaleController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _LocaleScope(
        strings: controller.strings,
        child: child,
      ),
    );
  }
}

class _LocaleScope extends InheritedWidget {
  const _LocaleScope({required this.strings, required super.child});

  final S strings;

  @override
  bool updateShouldNotify(_LocaleScope oldWidget) =>
      oldWidget.strings.lang != strings.lang;
}
