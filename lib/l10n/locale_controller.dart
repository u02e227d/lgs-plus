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
        '会社名またはお名前、住所、電話番号、メールアドレスを入力してください。住所は注文書に表示されます。登録後7日間は全機能を無料で使えます。同じメールアドレスまたは電話番号では再登録できません。',
        'Enter your company or name, address, phone, and email. The address appears on order documents. All features are free for 7 days after sign-up. The same email or phone cannot be registered again.',
        '请输入公司名或姓名、住所、电话和邮箱。住所会显示在注文书上。注册后7天内可免费使用全部功能。同一邮箱或电话不能再次注册。',
        'Nhập tên công ty hoặc họ tên, địa chỉ, số điện thoại và email. Địa chỉ hiện trên phiếu đặt hàng. Được dùng đầy đủ tính năng miễn phí 7 ngày sau đăng ký. Không đăng ký lại cùng email hoặc số điện thoại.',
      );
  String get companyOrName =>
      _p('会社名／名前', 'Company / name', '公司名／姓名', 'Công ty / tên');
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
  String registerMailDemo(String email) => _p(
        '活性化メールを $email に送信しました（デモ：ローカル模擬）。\n次の画面でパスワードを設定してアカウントを有効化してください。',
        'An activation email was sent to $email (local demo).\nSet a password on the next screen to activate your account.',
        '已向 $email 发送激活邮件（本地演示）。\n请在下一屏设置密码以启用账号。',
        'Đã gửi email kích hoạt tới $email (demo nội bộ).\nHãy đặt mật khẩu ở màn hình tiếp theo.',
      );

  String get activateTitle =>
      _p('アカウント活性化', 'Activate account', '账号激活', 'Kích hoạt tài khoản');
  String get resetPasswordTitle =>
      _p('パスワード再設定', 'Reset password', '重设密码', 'Đặt lại mật khẩu');
  String get activateHint => _p(
        'メール内のリンク相当です。パスワードを設定するとアカウントが有効になります。',
        'This is the email-link step. Setting a password activates the account.',
        '相当于邮件中的链接。设置密码后账号即生效。',
        'Bước tương đương liên kết email. Đặt mật khẩu để kích hoạt.',
      );
  String get resetHint => _p(
        'メールまたはSMSのリンク相当です。新しいパスワードを設定してください。',
        'This is the email or SMS link step. Set a new password.',
        '相当于邮件或短信链接。请设置新密码。',
        'Bước tương đương liên kết email/SMS. Hãy đặt mật khẩu mới.',
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
  String get fullAccessHint => _p(
        '現在は有料または特典期間中です。試算表・材料・注文を含む全機能が使えます。',
        'You have paid or bonus access. Estimates, materials, and orders are available.',
        '当前为付费或特典期内。可使用试算表、材料和订货等全部功能。',
        'Bạn đang có gói trả phí hoặc ưu đãi. Dùng được bảng tính, vật tư và đặt hàng.',
      );
  String get freeAccessHint => _p(
        '無料版：図面アップロード、スケール設定、図面測定のみ利用できます。',
        'Free plan: upload drawings, set scale, and measure only.',
        '免费版：仅可上传图纸、设定比例和测量。',
        'Bản miễn phí: chỉ tải bản vẽ, đặt tỷ lệ và đo.',
      );
  String get planVersion =>
      _p('利用バージョン', 'Plan', '使用版本', 'Phiên bản');
  String get free => _p('無料', 'Free', '免费', 'Miễn phí');
  String get paid => _p('有料', 'Paid', '付费', 'Trả phí');
  String get paidNotice => _p(
        '有料プランは毎月最低更新です。いつでも解約できますが、お支払い済みの月分は返金されません。',
        'The paid plan renews monthly. You can cancel anytime; the current paid month is non-refundable.',
        '付费套餐按月最低续订。可随时解约，已支付月份不予退款。',
        'Gói trả phí gia hạn theo tháng. Có thể hủy bất cứ lúc nào; tháng đã thanh toán không hoàn tiền.',
      );
  String get startPaid =>
      _p('有料プランを開始（月額）', 'Start paid plan (monthly)', '开始付费套餐（月额）', 'Bắt đầu gói trả phí (tháng)');
  String get cancelPlan => _p('解約する', 'Cancel', '解约', 'Hủy');
  String get inviteFriends =>
      _p('友達に紹介', 'Invite friends', '介绍给朋友', 'Mời bạn bè');
  String inviteCodeLabel(String code) => _p(
        '招待コード：$code',
        'Invite code: $code',
        '招待コード：$code',
        'Mã mời: $code',
      );
  String get inviteHint => _p(
        '上の招待コードを友達に送ってください。友達が登録時にこのコードを入力し、ログインすると、双方の利用期限に7日が自動で加算されます。紹介人が認証して受け取る操作は不要です。',
        'Send the invite code above. When a friend enters it at sign-up and logs in, both accounts get 7 extra days automatically. No claim step is needed.',
        '请把上面的招待コード发给朋友。朋友注册时填写该码并登录后，双方自动各加7天。介绍人无需再领取。',
        'Gửi mã mời ở trên. Khi bạn bè nhập mã lúc đăng ký và đăng nhập, cả hai được cộng 7 ngày. Không cần nhận thủ công.',
      );

  String get feedbackTitle =>
      _p('意見・要望報告', 'Feedback', '意见／要望报告', 'Góp ý / yêu cầu');
  String get feedbackHint => _p(
        '改善の意見や機能の要望を運営へ送れます。採用された場合、利用期限が加算されます。',
        'Send opinions or feature requests to operations. If adopted, extra usage days are added.',
        '可向运营发送改进意见或功能要望。被采纳后会增加使用期限。',
        'Gửi góp ý hoặc yêu cầu tính năng. Nếu được chọn, bạn được cộng ngày dùng.',
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
  String get sessionKicked => _p(
        'このアカウントは別の端末でログインしたため、こちらはログアウトしました。同時に使える端末は1台です。',
        'This account signed in on another device, so you were signed out here. Only one device can be used at a time.',
        '此账号已在其他设备登录，本机已退出。同一账号同时只能使用一台设备。',
        'Tài khoản đã đăng nhập trên thiết bị khác nên máy này bị đăng xuất. Chỉ dùng được một thiết bị cùng lúc.',
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
      _p('有料・特典の機能です', 'Paid or bonus feature', '付费／特典功能', 'Tính năng trả phí hoặc ưu đãi');
  String get upgradeMessage => _p(
        '無料版で使えるのは、図面のアップロード、スケール設定、図面測定だけです。\n\n材料選択・試算表・注文書は、有料プランまたは招待特典の期限内でご利用ください。',
        'The free plan only includes drawing upload, scale, and measuring.\n\nMaterials, estimates, and orders require a paid plan or an active bonus period.',
        '免费版仅可上传图纸、设定比例和测量。\n\n材料选择、试算表和订货单需付费套餐或特典期内使用。',
        'Bản miễn phí chỉ gồm tải bản vẽ, tỷ lệ và đo.\n\nVật tư, bảng tính và phiếu đặt hàng cần gói trả phí hoặc thời gian ưu đãi.',
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
  String get notActivated => _p(
        'アカウントが未活性化です。メールからパスワードを設定してください',
        'Account is not activated. Set a password from the email link.',
        '账号尚未激活。请通过邮件设置密码。',
        'Tài khoản chưa kích hoạt. Hãy đặt mật khẩu từ email.',
      );
  String get accountNotFoundDetail => _p(
        'アカウントが見つかりませんでした',
        'Account was not found',
        '未找到账号',
        'Không tìm thấy tài khoản',
      );

  String get confirmNameTitle =>
      _p('氏名の確認', 'Confirm name', '确认姓名', 'Xác nhận họ tên');
  String get resetBySms =>
      _p('SMSで再設定', 'Reset by SMS', '用短信重设', 'Đặt lại bằng SMS');
  String get enterRegisteredPhone => _p(
        'ご登録の電話番号を入力してください。',
        'Enter your registered phone number.',
        '请输入注册时的电话号码。',
        'Nhập số điện thoại đã đăng ký.',
      );
  String get enterFamilyGivenHint => _p(
        'ご登録の姓と名をそれぞれ入力してください。電話番号と氏名が一致するアカウントを確認します。',
        'Enter your registered family and given name. We match them with the phone number.',
        '请分别输入注册时的姓和名。将用电话和姓名核对账号。',
        'Nhập họ và tên đã đăng ký. Chúng tôi đối chiếu với số điện thoại.',
      );
  String get next => _p('次へ', 'Next', '下一步', 'Tiếp');
  String get confirmAction => _p('確認する', 'Confirm', '确认', 'Xác nhận');
  String get resetByEmail =>
      _p('メールで再設定', 'Reset by email', '用邮件重设', 'Đặt lại bằng email');
  String get resetChannelIntro => _p(
        'パスワード再設定用のリンクを、メールまたはSMSで送信できます。',
        'Send a password-reset link by email or SMS.',
        '可通过邮件或短信发送重设密码链接。',
        'Có thể gửi liên kết đặt lại mật khẩu bằng email hoặc SMS.',
      );
  String get enterRegisteredEmail => _p(
        'ご登録のメールアドレスを入力してください。再設定用のリンクを送信します。',
        'Enter your registered email. We will send a reset link.',
        '请输入注册邮箱。将发送重设链接。',
        'Nhập email đã đăng ký. Chúng tôi sẽ gửi liên kết đặt lại.',
      );
  String get sendResetLink =>
      _p('再設定リンクを送信', 'Send reset link', '发送重设链接', 'Gửi liên kết đặt lại');
  String get sentTitle => _p('送信しました', 'Sent', '已发送', 'Đã gửi');
  String get resetSentEmail => _p(
        'ご登録のメールアドレスへ、パスワード再設定用のリンクを送信しました。',
        'A password-reset link was sent to your registered email.',
        '已向注册邮箱发送重设密码链接。',
        'Đã gửi liên kết đặt lại mật khẩu tới email đã đăng ký.',
      );
  String get resetSentSms => _p(
        'ご登録の電話番号へ、パスワード再設定用のSMSを送信しました。',
        'A password-reset SMS was sent to your registered phone.',
        '已向注册电话发送重设密码短信。',
        'Đã gửi SMS đặt lại mật khẩu tới số đã đăng ký.',
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
        'LGS+積算をご紹介します。\n\n招待コード：$code\n登録リンク：https://lgsplus.app/invite?code=$code\n\nアプリをダウンロードし、新規登録画面でこの招待コードを入力してください。友達が登録してログインすると、紹介した方・された方の両方に自動で1週間の無料特典が付きます。受け取り操作は不要です。',
        'I would like to introduce LGS+.\n\nInvite code: $code\nSign-up link: https://lgsplus.app/invite?code=$code\n\nDownload the app and enter this code on the sign-up screen. When your friend registers and logs in, both of you automatically get one extra free week. No claim step is needed.',
        '向您介绍 LGS+積算。\n\n招待コード：$code\n注册链接：https://lgsplus.app/invite?code=$code\n\n请下载应用，并在注册画面填写此招待コード。朋友注册并登录后，双方自动各获一周免费特典，无需领取。',
        'Tôi muốn giới thiệu LGS+.\n\nMã mời: $code\nLiên kết đăng ký: https://lgsplus.app/invite?code=$code\n\nTải ứng dụng và nhập mã này khi đăng ký. Khi bạn bè đăng ký và đăng nhập, cả hai tự động được thêm một tuần miễn phí. Không cần nhận thủ công.',
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
