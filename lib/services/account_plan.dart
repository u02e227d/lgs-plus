import 'dart:io';
import 'dart:math';

import '../models/models.dart';

class SeatPack {
  const SeatPack({
    required this.productId,
    required this.seats,
    required this.priceYen,
    required this.labelJa,
  });

  final String productId;
  final int seats;
  final int priceYen;
  final String labelJa;
}

class AccountPlan {
  AccountPlan._();

  /// 無料：月間図面アップロード上限（ボーナス加算前）
  static const freeUploadBase = 1;

  /// 招待成功1回あたりの加算（基礎1 + 特典2 = 上限3）※ iOS のみ
  static const inviteUploadBonus = 2;
  static const reportAdoptUploadBonus = 2;
  static const freeUploadCapIos = 3;

  /// Mac / Windows 無料は紹介なし・毎月1枚のみ
  static const freeUploadCapMac = 1;
  static const freeUploadCapWindows = 1;

  static bool get friendInviteEnabled =>
      !Platform.isMacOS && !Platform.isWindows;

  static int get freeUploadCap {
    if (Platform.isWindows) return freeUploadCapWindows;
    if (Platform.isMacOS) return freeUploadCapMac;
    return freeUploadCapIos;
  }

  static const legacyMonthlyProductId = 'lgsplus.premium.monthly';

  /// iOS / iPadOS App Store 商品
  static const seatPacks = <SeatPack>[
    SeatPack(
      productId: 'lgsplus.team.1.monthly',
      seats: 1,
      priceYen: 9980,
      labelJa: '1席',
    ),
    SeatPack(
      productId: 'lgsplus.team.5.monthly',
      seats: 5,
      priceYen: 29980,
      labelJa: '5席',
    ),
    SeatPack(
      productId: 'lgsplus.team.10.monthly',
      seats: 10,
      priceYen: 49980,
      labelJa: '10席',
    ),
    SeatPack(
      productId: 'lgsplus.team.15.monthly',
      seats: 15,
      priceYen: 69980,
      labelJa: '15席',
    ),
    SeatPack(
      productId: 'lgsplus.team.20.monthly',
      seats: 20,
      priceYen: 89980,
      labelJa: '20席',
    ),
  ];

  /// Mac App Store 用（別 App・別課金。ASC で同 ID を作成し価格を独立設定）
  static const macSeatPacks = <SeatPack>[
    SeatPack(
      productId: 'lgsplus.mac.team.1.monthly',
      seats: 1,
      priceYen: 9980,
      labelJa: '1席',
    ),
    SeatPack(
      productId: 'lgsplus.mac.team.5.monthly',
      seats: 5,
      priceYen: 29980,
      labelJa: '5席',
    ),
    SeatPack(
      productId: 'lgsplus.mac.team.10.monthly',
      seats: 10,
      priceYen: 49980,
      labelJa: '10席',
    ),
    SeatPack(
      productId: 'lgsplus.mac.team.15.monthly',
      seats: 15,
      priceYen: 69980,
      labelJa: '15席',
    ),
    SeatPack(
      productId: 'lgsplus.mac.team.20.monthly',
      seats: 20,
      priceYen: 89980,
      labelJa: '20席',
    ),
  ];

  /// 現在プラットフォームで購入に出すプラン一覧（Windows はアプリ内課金なし）
  static List<SeatPack> get storeSeatPacks {
    if (Platform.isWindows) return const [];
    if (Platform.isMacOS) return macSeatPacks;
    return seatPacks;
  }

  /// StoreKit 照会用（iOS/Mac 両方の ID を含む＝復元・検証用）
  static final productIds = {
    for (final p in seatPacks) p.productId,
    for (final p in macSeatPacks) p.productId,
    legacyMonthlyProductId,
  };

  static SeatPack? packForProductId(String? id) {
    final key = (id ?? '').trim();
    if (key.isEmpty) return null;
    for (final p in seatPacks) {
      if (p.productId == key) return p;
    }
    for (final p in macSeatPacks) {
      if (p.productId == key) return p;
    }
    if (key == legacyMonthlyProductId) {
      return const SeatPack(
        productId: legacyMonthlyProductId,
        seats: 1,
        priceYen: 9980,
        labelJa: '1席',
      );
    }
    return null;
  }

  static int seatsForProductId(String? id) =>
      packForProductId(id)?.seats ?? 0;

  /// 後方互換（旧テスト・iOS 既定）
  static const monthlyProductId = 'lgsplus.team.1.monthly';
  static const monthlyPriceYen = 9980;

  /// 当プラットフォームの既定購入 Product ID
  static String get storeMonthlyProductId => storeSeatPacks.first.productId;

  static const signupNotice =
      '無料プラン：毎月図面を1枚までアップロードでき、その範囲ですべての機能をご利用いただけます。';
  static const bonusNotice =
      '招待特典：図面アップロードが2枚増えました。紹介コードで登録した方に付与され、当月は最大3枚までです（前月分の繰越なし）。';
  static const reportAdoptNotice = 'ご提案が採用され、図面アップロード回数が追加されました。';
  static const paidNotice =
      '席位プランはApp Storeで月額課金されます。いつでも解約できますが、お支払い済みの月分は返金されません。'
      '購入者のメールが組織オーナーとなり、席数までメンバーを招待できます。有料中は図面アップロード無制限です。';

  static const inviteLinkBase = 'https://shop.infmaxai.com/invite';

  static String generateInviteCode([Random? rng]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = rng ?? Random();
    final body = List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
    return 'LGS-$body';
  }

  static String normalizeInviteCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static String inviteLink(String code) =>
      '$inviteLinkBase?code=${Uri.encodeQueryComponent(normalizeInviteCode(code))}';

  static String inviteSubject() => 'LGS+積算のご招待';

  static String inviteBody(String code) {
    final normalized = normalizeInviteCode(code);
    return 'LGS+積算をご紹介します。\n'
        '\n'
        '招待コード：$normalized\n'
        '登録リンク：${inviteLink(normalized)}\n'
        '\n'
        'アプリをダウンロードし、新規登録画面でこの招待コードを入力してください。'
        '招待コードで登録・ログインした方に、当月の図面アップロードが2枚追加されます（無料は当月最大3枚・前月繰越なし）。'
        '受け取り操作は不要です。';
  }

  static bool shouldApplyPaidTransaction({
    required String? purchaseId,
    required String? alreadyAppliedPurchaseId,
  }) {
    final id = purchaseId?.trim() ?? '';
    if (id.isEmpty) return true;
    return id != (alreadyAppliedPurchaseId?.trim() ?? '');
  }

  /// 新規登録は日数特典なし（アップロード枠のみ）
  static AppUser applySignupTrial(AppUser user, DateTime now) {
    return user.copyWith(pendingNotice: signupNotice);
  }

  static AppUser cancelPaid(AppUser user, DateTime now) {
    return user.copyWith(
      plan: SubscriptionPlan.free,
      seatLimit: 0,
      productId: null,
      clearProductId: true,
    );
  }
}
