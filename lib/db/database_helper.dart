import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../staff_model.dart';

class DatabaseHelper {
  DatabaseHelper._()
    : _factory = null,
      _path = null,
      _loadSeed = _loadSeedAsset;
  static final DatabaseHelper instance = DatabaseHelper._();

  /// 테스트용: DB 팩토리·경로·시드 JSON 을 바꿔 끼운다.
  @visibleForTesting
  DatabaseHelper.forTesting({
    required DatabaseFactory factory,
    required String path,
    required Future<String> Function() loadSeed,
  }) : _factory = factory,
       _path = path,
       _loadSeed = loadSeed;

  static const _dbName = 'du_who.db';

  // 1 → 2: favorites 를 staff.id 대신 user_id 로 저장, meta 테이블 추가
  // 2 → 3: 최근 본 교직원(recents) 테이블 추가
  static const _dbVersion = 3;
  static const _seedAsset = 'assets/staff_db.json';

  final DatabaseFactory? _factory;
  final String? _path;
  final Future<String> Function() _loadSeed;

  // 동시에 여러 곳에서 불러도 한 번만 연다
  Future<Database>? _db;

  Future<Database> get database => _db ??= _open();

  Future<Database> _open() async {
    final path =
        _path ??
        p.join((await getApplicationDocumentsDirectory()).path, _dbName);
    final db = await (_factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    await _syncSeed(db);
    return db;
  }

  static Future<String> _loadSeedAsset() => rootBundle.loadString(_seedAsset);

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        name TEXT NOT NULL,
        department TEXT,
        title TEXT,
        tel TEXT,
        cell_tel TEXT,
        location TEXT,
        email TEXT,
        charge_business TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_staff_name ON staff(name)');
    await db.execute('CREATE INDEX idx_staff_department ON staff(department)');
    await db.execute('CREATE INDEX idx_staff_user_id ON staff(user_id)');
    await _createFavorites(db);
    await _createMeta(db);
    await _createRecents(db);
  }

  // 즐겨찾기는 user_id 로 저장한다. staff 를 다시 채우면 id 가 바뀌기 때문이다.
  Future<void> _createFavorites(DatabaseExecutor db) =>
      db.execute('CREATE TABLE favorites (user_id TEXT PRIMARY KEY)');

  // 최근 본 교직원. 상세를 열거나 전화를 걸 때 시각(ms)을 갱신한다
  Future<void> _createRecents(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS recents (user_id TEXT PRIMARY KEY, at INTEGER NOT NULL)',
  );

  Future<void> _createMeta(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)',
  );

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMeta(db);
      // 기존 즐겨찾기(staff.id)를 user_id 로 옮긴다
      await db.execute('ALTER TABLE favorites RENAME TO favorites_v1');
      await _createFavorites(db);
      await db.execute('''
        INSERT OR IGNORE INTO favorites (user_id)
        SELECT s.user_id FROM favorites_v1 f
        JOIN staff s ON s.id = f.staff_id
        WHERE s.user_id IS NOT NULL AND s.user_id <> ''
      ''');
      await db.execute('DROP TABLE favorites_v1');
    }
    if (oldVersion < 3) {
      await _createRecents(db);
    }
  }

  /// 번들된 교직원 JSON 이 바뀌었으면 staff 테이블을 다시 채운다.
  /// 앱 업데이트로 새 데이터가 들어와도 기존 설치자에게 반영되게 한다. 즐겨찾기는 user_id 라 유지된다.
  Future<void> _syncSeed(Database db) async {
    final jsonString = await _loadSeed();
    final hash = seedHash(jsonString);
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['seed_hash'],
    );
    if (rows.isNotEmpty && rows.first['value'] == hash) return;

    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    final list = (decoded['memberSearchList'] as List?) ?? const [];
    await db.transaction((txn) async {
      await txn.delete('staff');
      final batch = txn.batch();
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final s = Staff.fromJson(raw);
        if (s.name.isEmpty) continue;
        batch.insert('staff', s.toMap());
      }
      await batch.commit(noResult: true);
      await txn.insert('meta', {
        'key': 'seed_hash',
        'value': hash,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Staff>> getAllStaff() async {
    final db = await database;
    final rows = await db.query('staff', orderBy: 'name ASC');
    return rows.map(Staff.fromMap).toList();
  }

  // mode 0: 전체 필드(name OR department OR [title] OR charge_business)
  // mode 1: 이름/부서만 (name OR department)
  // includeTitle=false: 직위를 볼 수 없는 학생은 직위로도 찾지 못하게 한다
  Future<List<Staff>> searchStaff(
    String keyword,
    int mode, {
    bool includeTitle = true,
  }) async {
    if (keyword.isEmpty) return getAllStaff();
    final db = await database;
    final like = '%$keyword%';
    final fields = mode == 1
        ? ['name', 'department']
        : ['name', 'department', if (includeTitle) 'title', 'charge_business'];
    final where = fields.map((f) => '$f LIKE ?').join(' OR ');
    final args = List.filled(fields.length, like);
    final rows = await db.query(
      'staff',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return rows.map(Staff.fromMap).toList();
  }

  Future<Set<String>> getFavoriteUserIds() async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['user_id']);
    return rows.map((r) => r['user_id'] as String).toSet();
  }

  /// 즐겨찾기한 교직원만 이름순으로. 지금 데이터에 없는 사람은 빠진다.
  Future<List<Staff>> getFavoriteStaff() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM staff WHERE user_id IN (SELECT user_id FROM favorites) '
      'ORDER BY name ASC',
    );
    return rows.map(Staff.fromMap).toList();
  }

  Future<void> addFavorite(String userId) async {
    final db = await database;
    await db.insert('favorites', {
      'user_id': userId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 최근 본 교직원으로 기록한다. 오래된 것은 [keep]개만 남기고 지운다
  Future<void> addRecent(String userId, {int keep = 20}) async {
    final db = await database;
    await db.insert('recents', {
      'user_id': userId,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.rawDelete(
      'DELETE FROM recents WHERE user_id NOT IN '
      '(SELECT user_id FROM recents ORDER BY at DESC LIMIT ?)',
      [keep],
    );
  }

  /// 최근 본 교직원, 최근 순. 지금 데이터에 없는 사람은 빠진다
  Future<List<Staff>> getRecentStaff({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT s.* FROM recents r JOIN staff s ON s.user_id = r.user_id '
      'GROUP BY r.user_id ORDER BY r.at DESC LIMIT ?',
      [limit],
    );
    return rows.map(Staff.fromMap).toList();
  }

  Future<void> clearRecents() async {
    final db = await database;
    await db.delete('recents');
  }

  Future<void> removeFavorite(String userId) async {
    final db = await database;
    await db.delete('favorites', where: 'user_id = ?', whereArgs: [userId]);
  }
}

/// 시드 JSON 의 내용 해시(FNV-1a 32비트). 실행마다 같은 값이 나와야 해서 String.hashCode 대신 쓴다.
String seedHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return '${s.length}:${h.toRadixString(16)}';
}
