import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// オフライン永続化（SQLite）
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'lgs_plus.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            company_name TEXT NOT NULL,
            address TEXT NOT NULL,
            contact_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT,
            activated INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            contact_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE drawings (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            local_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            kind TEXT NOT NULL,
            scale_px_per_mm REAL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE measurements (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            drawing_id TEXT NOT NULL,
            name TEXT NOT NULL,
            walls_json TEXT NOT NULL,
            ceilings_json TEXT NOT NULL,
            openings_json TEXT,
            board_estimate_json TEXT,
            lgs_estimate_json TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE orders (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            measurement_ids TEXT NOT NULL,
            order_date TEXT NOT NULL,
            delivery_date TEXT NOT NULL,
            lines_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE session (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN board_estimate_json TEXT',
          );
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN lgs_estimate_json TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN openings_json TEXT',
          );
        }
      },
    );
  }

  // ---- session ----
  Future<void> setSession(String key, String value) async {
    final db = await database;
    await db.insert(
      'session',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSession(String key) async {
    final db = await database;
    final rows =
        await db.query('session', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> clearSession() async {
    final db = await database;
    await db.delete('session');
  }

  // ---- users ----
  Future<void> upsertUser(AppUser user) async {
    final db = await database;
    await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppUser?> findUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> findUserById(String id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  // ---- projects ----
  Future<void> upsertProject(SiteProject project) async {
    final db = await database;
    await db.insert('projects', project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SiteProject>> listProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'created_at DESC');
    return rows.map(SiteProject.fromMap).toList();
  }

  Future<SiteProject?> getProject(String id) async {
    final db = await database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SiteProject.fromMap(rows.first);
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('orders', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('measurements', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('drawings', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ---- drawings ----
  Future<void> upsertDrawing(DrawingFile drawing) async {
    final db = await database;
    await db.insert('drawings', drawing.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DrawingFile>> listDrawings(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'drawings',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(DrawingFile.fromMap).toList();
  }

  Future<DrawingFile?> getDrawing(String id) async {
    final db = await database;
    final rows = await db.query('drawings', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return DrawingFile.fromMap(rows.first);
  }

  Future<void> deleteDrawing(String id) async {
    final db = await database;
    await db.delete('drawings', where: 'id = ?', whereArgs: [id]);
  }

  // ---- measurements ----
  Future<void> upsertMeasurement(Measurement m) async {
    final db = await database;
    await db.insert('measurements', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Measurement>> listMeasurements(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'measurements',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Measurement.fromMap).toList();
  }

  Future<Measurement?> getMeasurement(String id) async {
    final db = await database;
    final rows =
        await db.query('measurements', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Measurement.fromMap(rows.first);
  }

  Future<void> deleteMeasurement(String id) async {
    final db = await database;
    await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  // ---- orders ----
  Future<void> upsertOrder(MaterialOrder order) async {
    final db = await database;
    await db.insert('orders', order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MaterialOrder>> listOrders(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'orders',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(MaterialOrder.fromMap).toList();
  }
}
