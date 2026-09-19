import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../services/account_recovery.dart';

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
      version: 13,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            company_name TEXT NOT NULL,
            address TEXT NOT NULL,
            contact_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            client_app TEXT NOT NULL DEFAULT 'ios',
            password_hash TEXT,
            activated INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            invite_code TEXT,
            referred_by_code TEXT,
            plan TEXT NOT NULL DEFAULT 'free',
            access_until TEXT,
            pending_notice TEXT,
            seat_limit INTEGER NOT NULL DEFAULT 0,
            product_id TEXT,
            org_owner_user_id TEXT,
            upload_unlimited INTEGER NOT NULL DEFAULT 0,
            upload_remaining INTEGER NOT NULL DEFAULT 1,
            upload_limit INTEGER NOT NULL DEFAULT 3,
            upload_used INTEGER NOT NULL DEFAULT 0,
            upload_bonus INTEGER NOT NULL DEFAULT 0,
            UNIQUE(email, client_app)
          )
        ''');
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL DEFAULT '',
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
            drops_json TEXT,
            board_estimate_json TEXT,
            lgs_estimate_json TEXT,
            cross_estimate_json TEXT,
            drop_estimate_json TEXT,
            ceiling_board_estimate_json TEXT,
            ceiling_lgs_estimate_json TEXT,
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
          CREATE TABLE order_history (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            title TEXT NOT NULL,
            issued_at TEXT NOT NULL,
            created_at TEXT NOT NULL,
            meta_json TEXT NOT NULL,
            lines_json TEXT NOT NULL,
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
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN cross_estimate_json TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN drops_json TEXT',
          );
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN drop_estimate_json TEXT',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN ceiling_board_estimate_json TEXT',
          );
          await db.execute(
            'ALTER TABLE measurements ADD COLUMN ceiling_lgs_estimate_json TEXT',
          );
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE users ADD COLUMN invite_code TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN referred_by_code TEXT');
          await db.execute(
            "ALTER TABLE users ADD COLUMN plan TEXT NOT NULL DEFAULT 'free'",
          );
          await db.execute('ALTER TABLE users ADD COLUMN access_until TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN pending_notice TEXT');
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN seat_limit INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE users ADD COLUMN product_id TEXT');
          await db.execute(
            'ALTER TABLE users ADD COLUMN upload_unlimited INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN upload_remaining INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN upload_limit INTEGER NOT NULL DEFAULT 3',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN upload_used INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN upload_bonus INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 9) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN org_owner_user_id TEXT',
          );
        }
        if (oldVersion < 10) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS order_history (
              id TEXT PRIMARY KEY,
              project_id TEXT NOT NULL,
              title TEXT NOT NULL,
              issued_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              meta_json TEXT NOT NULL,
              lines_json TEXT NOT NULL,
              FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 11) {
          await db.execute(
            "ALTER TABLE projects ADD COLUMN user_id TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 12) {
          await db.execute(
            "ALTER TABLE users ADD COLUMN client_app TEXT NOT NULL DEFAULT 'ios'",
          );
        }
        if (oldVersion < 13) {
          // email 単独 UNIQUE → (email, client_app) へ（iOS/Mac 同一メール可）
          await db.execute('''
            CREATE TABLE users_v13 (
              id TEXT PRIMARY KEY,
              company_name TEXT NOT NULL,
              address TEXT NOT NULL,
              contact_name TEXT NOT NULL,
              phone TEXT NOT NULL,
              email TEXT NOT NULL,
              client_app TEXT NOT NULL DEFAULT 'ios',
              password_hash TEXT,
              activated INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              invite_code TEXT,
              referred_by_code TEXT,
              plan TEXT NOT NULL DEFAULT 'free',
              access_until TEXT,
              pending_notice TEXT,
              seat_limit INTEGER NOT NULL DEFAULT 0,
              product_id TEXT,
              org_owner_user_id TEXT,
              upload_unlimited INTEGER NOT NULL DEFAULT 0,
              upload_remaining INTEGER NOT NULL DEFAULT 1,
              upload_limit INTEGER NOT NULL DEFAULT 3,
              upload_used INTEGER NOT NULL DEFAULT 0,
              upload_bonus INTEGER NOT NULL DEFAULT 0,
              UNIQUE(email, client_app)
            )
          ''');
          await db.execute('''
            INSERT OR IGNORE INTO users_v13 (
              id, company_name, address, contact_name, phone, email, client_app,
              password_hash, activated, created_at, invite_code, referred_by_code,
              plan, access_until, pending_notice, seat_limit, product_id,
              org_owner_user_id, upload_unlimited, upload_remaining, upload_limit,
              upload_used, upload_bonus
            )
            SELECT
              id, company_name, address, contact_name, phone, email,
              COALESCE(NULLIF(client_app, ''), 'ios'),
              password_hash, activated, created_at, invite_code, referred_by_code,
              plan, access_until, pending_notice, seat_limit, product_id,
              org_owner_user_id, upload_unlimited, upload_remaining, upload_limit,
              upload_used, upload_bonus
            FROM users
          ''');
          await db.execute('DROP TABLE users');
          await db.execute('ALTER TABLE users_v13 RENAME TO users');
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

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<AppUser?> findUserByEmail(String email, {String? clientApp}) async {
    final db = await database;
    final raw = (clientApp ?? '').trim().toLowerCase();
    final app = raw == 'mac'
        ? 'mac'
        : (raw == 'windows' || raw == 'win' || raw == 'win32')
            ? 'windows'
            : 'ios';
    final rows = await db.query(
      'users',
      where: 'email = ? AND client_app = ?',
      whereArgs: [email.trim().toLowerCase(), app],
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> findUserByPhone(String phone) async {
    final key = AccountRecovery.normalizePhone(phone);
    if (key.isEmpty) return null;
    for (final user in await listUsers()) {
      if (AccountRecovery.normalizePhone(user.phone) == key) {
        return user;
      }
    }
    return null;
  }

  Future<AppUser?> findUserById(String id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> listUsers() async {
    final db = await database;
    final rows = await db.query('users');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<AppUser?> findUserByInviteCode(String code) async {
    final key = code.trim().toUpperCase();
    if (key.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'UPPER(invite_code) = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  // ---- projects ----
  Future<void> upsertProject(SiteProject project) async {
    final db = await database;
    await db.insert('projects', project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SiteProject>> listProjects({String? userId}) async {
    final db = await database;
    if (userId == null || userId.isEmpty) {
      return [];
    }
    final rows = await db.query(
      'projects',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SiteProject.fromMap).toList();
  }

  /// 旧データ（user_id 空）を現在ユーザーに紐づける（初回ログイン時1回）
  Future<void> claimOrphanProjects(String userId) async {
    if (userId.isEmpty) return;
    final db = await database;
    await db.update(
      'projects',
      {'user_id': userId},
      where: "user_id = '' OR user_id IS NULL",
    );
  }

  Future<SiteProject?> getProject(String id) async {
    final db = await database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return SiteProject.fromMap(rows.first);
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('order_history', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('orders', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('measurements', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('drawings', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  /// アカウント削除時：本端末の現場・図面・測定・注文をすべて消去
  Future<void> wipeAllJobData() async {
    final db = await database;
    await db.delete('order_history');
    await db.delete('orders');
    await db.delete('measurements');
    await db.delete('drawings');
    await db.delete('projects');
  }

  // ---- order history ----
  Future<void> upsertOrderHistory(OrderHistoryEntry entry) async {
    final db = await database;
    await db.insert(
      'order_history',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OrderHistoryEntry>> listOrderHistory(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'order_history',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(OrderHistoryEntry.fromMap).toList();
  }

  Future<void> deleteOrderHistory(String id) async {
    final db = await database;
    await db.delete('order_history', where: 'id = ?', whereArgs: [id]);
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
