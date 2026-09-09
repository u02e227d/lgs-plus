import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/models.dart';

/// 認証（オフラインデモ：メール活性化リンク相当をローカルで模擬）
class AuthService {
  AuthService(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  String _hash(String password) =>
      sha256.convert(utf8.encode('lgs+$password')).toString();

  Future<AppUser> register({
    required String companyName,
    required String address,
    required String contactName,
    required String phone,
    required String email,
  }) async {
    final normalized = email.trim().toLowerCase();
    final existing = await _db.findUserByEmail(normalized);
    if (existing != null) {
      throw Exception('このメールアドレスは既に登録されています');
    }
    final user = AppUser(
      id: _uuid.v4(),
      companyName: companyName.trim(),
      address: address.trim(),
      contactName: contactName.trim(),
      phone: phone.trim(),
      email: normalized,
      activated: false,
    );
    await _db.upsertUser(user);
    await _db.setSession('pending_activation:$normalized', user.id);
    return user;
  }

  /// メールリンク相当：パスワード設定で活性化
  Future<AppUser> activateWithPassword({
    required String email,
    required String password,
  }) async {
    if (password.length < 6) {
      throw Exception('パスワードは6文字以上にしてください');
    }
    final normalized = email.trim().toLowerCase();
    final user = await _db.findUserByEmail(normalized);
    if (user == null) throw Exception('アカウントが見つかりません');
    final activated = user.copyWith(
      passwordHash: _hash(password),
      activated: true,
    );
    await _db.upsertUser(activated);
    await _db.setSession('current_user_id', activated.id);
    return activated;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final user = await _db.findUserByEmail(email.trim().toLowerCase());
    if (user == null) throw Exception('メールまたはパスワードが違います');
    if (!user.activated || user.passwordHash == null) {
      throw Exception('アカウントが未活性化です。メールからパスワードを設定してください');
    }
    if (user.passwordHash != _hash(password)) {
      throw Exception('メールまたはパスワードが違います');
    }
    await _db.setSession('current_user_id', user.id);
    return user;
  }

  Future<AppUser?> currentUser() async {
    final id = await _db.getSession('current_user_id');
    if (id == null) return null;
    return _db.findUserById(id);
  }

  /// テスト期間：認証スキップ用のデモユーザーで即ログイン
  Future<AppUser> ensureTestLogin() async {
    const email = 'test@lgsplus.local';
    var user = await _db.findUserByEmail(email);
    if (user == null) {
      user = AppUser(
        id: _uuid.v4(),
        companyName: 'テスト建設',
        address: '東京都',
        contactName: 'テストユーザー',
        phone: '000-0000-0000',
        email: email,
        passwordHash: _hash('test1234'),
        activated: true,
      );
      await _db.upsertUser(user);
    } else if (!user.activated || user.passwordHash == null) {
      user = user.copyWith(
        passwordHash: _hash('test1234'),
        activated: true,
      );
      await _db.upsertUser(user);
    }
    await _db.setSession('current_user_id', user.id);
    return user;
  }

  Future<void> logout() async {
    await _db.clearSession();
  }
}

/// 図面ファイルをアプリ Documents にコピー
class DrawingImportService {
  static Future<File> persistBytes(List<int> bytes, String preferredName) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'drawings'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = File(p.join(dir.path, '${const Uuid().v4()}_$preferredName'));
    await dest.writeAsBytes(bytes, flush: true);
    return dest;
  }

  static Future<File> persistFile(File source, String preferredName) async {
    return persistBytes(await source.readAsBytes(), preferredName);
  }
}
