import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/models.dart';
import '../services/account_plan.dart';
import '../services/auth_service.dart';
import '../services/calc_engine.dart';
import '../services/device_session.dart';
import '../services/lgsplus_cloud.dart';
import '../services/notice_unread_controller.dart';
import '../services/store_billing.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _auth = AuthService(_db);
  }

  /// テスト期間：起動時にログイン画面をスキップ
  static const bool testDirectLogin = false;

  final AppDatabase _db = AppDatabase.instance;
  late final AuthService _auth;
  final _uuid = const Uuid();

  AppUser? user;
  bool booting = true;
  bool sessionKicked = false;
  List<SiteProject> projects = [];
  final Set<String> _appliedStoreTxns = <String>{};

  AuthService get auth => _auth;
  AppDatabase get db => _db;
  String newId() => _uuid.v4();

  Future<void> bootstrap() async {
    booting = true;
    notifyListeners();
    try {
      user = await _auth.currentUser();
      if (user == null && testDirectLogin) {
        user = await _auth.ensureTestLogin();
      }
      if (user != null) {
        await _db.claimOrphanProjects(user!.id);
        projects = await _db.listProjects(userId: user!.id);
        NoticeUnreadController.instance.start();
      } else {
        NoticeUnreadController.instance.stop();
      }
    } catch (_) {
      // ローカル起動は必ず完了させる
    } finally {
      booting = false;
      notifyListeners();
    }
    await StoreBilling.instance.attach((p) async {
      final u = user;
      if (u == null || !DeviceSession.enforceFor(u.email)) return;
      final txn = p.purchaseID?.trim() ?? '';
      if (txn.isNotEmpty && !_appliedStoreTxns.add(txn)) return;
      final signed = p.verificationData.serverVerificationData.trim();
      if (signed.isEmpty) return;
      try {
        user = await _auth.applyStorePaid(
          u,
          purchaseId: p.purchaseID,
          productId: p.productID,
          signedTransaction: signed,
        );
        notifyListeners();
      } catch (_) {
        _appliedStoreTxns.remove(txn);
      }
    });
    await checkDeviceSession();
  }

  Future<void> startStorePurchase([String? productId]) async {
    final u = user;
    if (u == null) return;
    await StoreBilling.instance.buy(
      productId: productId ?? AccountPlan.storeMonthlyProductId,
      applicationUserName: u.id,
    );
  }

  Future<void> restoreStorePurchases() async {
    await StoreBilling.instance.restore();
  }

  @override
  void dispose() {
    StoreBilling.instance.detach();
    super.dispose();
  }

  Future<void> checkDeviceSession({bool claim = false}) async {
    final current = user;
    if (current == null) return;
    try {
      final merged = await _auth.syncFromCloud(current, claim: claim);
      if (user?.id == merged.id) {
        user = merged;
        notifyListeners();
      }
    } on DeviceSwitchCooldownException {
      await _signOutLocal();
    } on SessionKickedException {
      await _signOutLocal();
    } catch (_) {
      // 圏外・サーバーエラーでもアプリは使える
    }
  }

  Future<void> _signOutLocal() async {
    sessionKicked = true;
    user = null;
    projects = [];
    NoticeUnreadController.instance.stop();
    notifyListeners();
  }

  Future<void> refreshProjects() async {
    final uid = user?.id;
    if (uid == null || uid.isEmpty) {
      projects = [];
    } else {
      projects = await _db.listProjects(userId: uid);
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (user == null) return;
    user = await _auth.currentUser();
    notifyListeners();
  }

  Future<void> setUser(AppUser? u) async {
    user = u;
    if (u != null) {
      sessionKicked = false;
      await _db.claimOrphanProjects(u.id);
      projects = await _db.listProjects(userId: u.id);
      NoticeUnreadController.instance.start();
    } else {
      projects = [];
      NoticeUnreadController.instance.stop();
    }
    notifyListeners();
  }

  void clearSessionKickNotice() {
    if (!sessionKicked) return;
    sessionKicked = false;
    notifyListeners();
  }

  Future<DrawingFile> saveDrawing(DrawingFile drawing) async {
    await _db.upsertDrawing(drawing);
    // 書き込み直後に読み戻して永続化を保証
    final saved = await _db.getDrawing(drawing.id) ?? drawing;
    notifyListeners();
    return saved;
  }

  /// 新規図面アップロード時に枠を消費（差し替えは呼び出し側でスキップ）
  Future<bool> consumeDrawingUpload() async {
    final u = user;
    if (u == null) return false;
    if (u.uploadUnlimited) return true;
    if (!u.canUploadDrawing) return false;
    try {
      final quota = await LgsplusCloud.consumeUpload(u.id);
      if (quota != null) {
        final q = quota['quota'] is Map
            ? Map<String, dynamic>.from(quota['quota'] as Map)
            : quota;
        final next = u.copyWith(
          uploadUnlimited: q['unlimited'] == 1 || q['unlimited'] == true,
          uploadRemaining: (q['remaining'] as num?)?.toInt() ?? u.uploadRemaining,
          uploadLimit: (q['limit'] as num?)?.toInt() ?? u.uploadLimit,
          uploadUsed: (q['used'] as num?)?.toInt() ?? u.uploadUsed,
          uploadBonus: (q['bonus'] as num?)?.toInt() ?? u.uploadBonus,
        );
        await _db.upsertUser(next);
        user = next;
        notifyListeners();
        return true;
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('upload_limit')) return false;
      // オフライン時はローカル枠を減らす
    }
    final remaining = u.uploadRemaining - 1;
    if (remaining < 0) return false;
    final next = u.copyWith(
      uploadRemaining: remaining,
      uploadUsed: u.uploadUsed + 1,
    );
    await _db.upsertUser(next);
    user = next;
    notifyListeners();
    return true;
  }

  Future<SiteProject> createProject({
    required String name,
    required String address,
    required String contactName,
    required String phone,
  }) async {
    final uid = user?.id ?? '';
    final project = SiteProject(
      id: newId(),
      userId: uid,
      name: name.trim(),
      address: address.trim(),
      contactName: contactName.trim(),
      phone: phone.trim(),
    );
    await _db.upsertProject(project);
    await refreshProjects();
    return (await _db.getProject(project.id)) ?? project;
  }

  Future<void> deleteProject(String id) async {
    await _db.deleteProject(id);
    await refreshProjects();
  }

  Future<Measurement> createMeasurement({
    required String projectId,
    required String drawingId,
    required String name,
  }) async {
    final m = Measurement(
      id: newId(),
      projectId: projectId,
      drawingId: drawingId,
      name: name.trim(),
    );
    await _db.upsertMeasurement(m);
    notifyListeners();
    return m;
  }

  Future<void> saveMeasurement(Measurement m) async {
    await _db.upsertMeasurement(m);
    notifyListeners();
  }

  Future<MaterialOrder> createOrder({
    required String projectId,
    required List<String> measurementIds,
    required DateTime deliveryDate,
    List<OrderLine>? extraLines,
  }) async {
    final selected = <Measurement>[];
    for (final id in measurementIds) {
      final m = await _db.getMeasurement(id);
      if (m != null) selected.add(m);
    }
    final lines = CalcEngine.aggregateOrderLines(selected, idGen: newId);
    if (extraLines != null) lines.addAll(extraLines);
    final order = MaterialOrder(
      id: newId(),
      projectId: projectId,
      measurementIds: measurementIds,
      orderDate: DateTime.now(),
      deliveryDate: deliveryDate,
      lines: lines,
    );
    await _db.upsertOrder(order);
    notifyListeners();
    return order;
  }

  Future<void> updateOrder(MaterialOrder order) async {
    await _db.upsertOrder(order);
    notifyListeners();
  }
}
