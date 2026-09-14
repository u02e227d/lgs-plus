import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/calc_engine.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _auth = AuthService(_db);
  }

  /// テスト期間：起動時にログイン画面をスキップ
  static const bool testDirectLogin = true;

  final AppDatabase _db = AppDatabase.instance;
  late final AuthService _auth;
  final _uuid = const Uuid();

  AppUser? user;
  bool booting = true;
  List<SiteProject> projects = [];

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
        projects = await _db.listProjects();
      }
    } catch (_) {
      // ローカル起動は必ず完了させる
    } finally {
      booting = false;
      notifyListeners();
    }
    final current = user;
    if (current == null) return;
    try {
      final merged = await _auth.syncFromCloud(current);
      if (user?.id == merged.id) {
        user = merged;
        notifyListeners();
      }
    } catch (_) {
      // 圏外・サーバーエラーでもアプリは使える
    }
  }

  Future<void> refreshProjects() async {
    projects = await _db.listProjects();
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
      projects = await _db.listProjects();
    } else {
      projects = [];
    }
    notifyListeners();
  }

  Future<DrawingFile> saveDrawing(DrawingFile drawing) async {
    await _db.upsertDrawing(drawing);
    // 書き込み直後に読み戻して永続化を保証
    final saved = await _db.getDrawing(drawing.id) ?? drawing;
    notifyListeners();
    return saved;
  }

  Future<SiteProject> createProject({
    required String name,
    required String address,
    required String contactName,
    required String phone,
  }) async {
    final project = SiteProject(
      id: newId(),
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
