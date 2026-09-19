import 'dart:io';

import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// Apple 端末でのみ StoreKit カタログを同期（Windows では no-op）
Future<void> syncAppStoreCatalog() async {
  if (!Platform.isIOS && !Platform.isMacOS) return;
  await AppStore().sync();
}
