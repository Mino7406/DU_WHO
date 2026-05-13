import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../staff_model.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'du_who.db';
  static const _dbVersion = 1;
  static const _seedAsset = 'assets/staff_db.json';

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

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
    await db.execute('''
      CREATE TABLE favorites (
        staff_id INTEGER PRIMARY KEY,
        FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE
      )
    ''');

    await _seedFromJson(db);
  }

  // 첫 실행 시에만 호출. 번들된 assets/staff_db.json 을 읽어 staff 테이블에 일괄 삽입.
  Future<void> _seedFromJson(Database db) async {
    final jsonString = await rootBundle.loadString(_seedAsset);
    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    final list = (decoded['memberSearchList'] as List?) ?? const [];

    final batch = db.batch();
    for (final raw in list) {
      if (raw is! Map<String, dynamic>) continue;
      final s = Staff.fromJson(raw);
      if (s.name.isEmpty) continue;
      batch.insert('staff', s.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Staff>> getAllStaff() async {
    final db = await database;
    final rows = await db.query('staff', orderBy: 'name ASC');
    return rows.map(Staff.fromMap).toList();
  }

  // mode 0: 전체 필드(name OR department OR title OR charge_business)
  // mode 1: 이름/부서만 (name OR department)
  Future<List<Staff>> searchStaff(String keyword, int mode) async {
    if (keyword.isEmpty) return getAllStaff();
    final db = await database;
    final like = '%$keyword%';
    final where = mode == 1
        ? 'name LIKE ? OR department LIKE ?'
        : 'name LIKE ? OR department LIKE ? OR title LIKE ? OR charge_business LIKE ?';
    final args = mode == 1 ? [like, like] : [like, like, like, like];
    final rows = await db.query(
      'staff',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return rows.map(Staff.fromMap).toList();
  }

  // 추후 주기 동기화에서 사용 예정. 현재는 골격만.
  // user_id 가 비어있을 수 있어 UNIQUE 제약 없이 단순 INSERT.
  Future<int> upsertStaff(Staff staff) async {
    final db = await database;
    return db.insert(
      'staff',
      staff.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<int>> getFavoriteIds() async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['staff_id']);
    return rows.map((r) => r['staff_id'] as int).toSet();
  }

  Future<void> addFavorite(int staffId) async {
    final db = await database;
    await db.insert(
      'favorites',
      {'staff_id': staffId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFavorite(int staffId) async {
    final db = await database;
    await db.delete('favorites', where: 'staff_id = ?', whereArgs: [staffId]);
  }
}
