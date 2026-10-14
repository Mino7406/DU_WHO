import 'dart:convert';
import 'dart:io';

import 'package:du_who/db/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String seed(List<List<String>> people) => jsonEncode({
  'memberSearchList': [
    for (final x in people)
      {'user_id': x[0], 'user_nm': x[1], 'user_dept_name': x[2]},
  ],
});

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('du_who_db_test');
    path = p.join(dir.path, 'du_who.db');
  });
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  DatabaseHelper helper(String json) => DatabaseHelper.forTesting(
    factory: factory,
    path: path,
    loadSeed: () async => json,
  );

  Future<void> close(DatabaseHelper h) async => (await h.database).close();

  test('새로 설치: 시드를 채우고 user_id 로 즐겨찾기', () async {
    final h = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    expect((await h.getAllStaff()).map((s) => s.name), ['가나', '다라']);
    await h.addFavorite('b2');
    expect(await h.getFavoriteUserIds(), {'b2'});
    expect((await h.getFavoriteStaff()).single.name, '다라');
    await h.removeFavorite('b2');
    expect(await h.getFavoriteStaff(), isEmpty);
    await close(h);
  });

  test('시드 JSON 이 바뀌면 다시 채우고, 즐겨찾기는 유지된다', () async {
    final v1 = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    await v1.addFavorite('b2');
    await close(v1);

    // 같은 JSON 이면 다시 채우지 않는다(id 유지)
    final same = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    final idsBefore = (await same.getAllStaff()).map((s) => s.id).toList();
    await close(same);
    final same2 = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    expect((await same2.getAllStaff()).map((s) => s.id).toList(), idsBefore);
    await close(same2);

    // 새 데이터: 앞에 사람이 추가되고 부서가 바뀜 → staff 교체, 즐겨찾기 b2 유지
    final v2 = helper(
      seed([
        ['c3', '마바', '입학팀'],
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '교무팀'],
      ]),
    );
    expect((await v2.getAllStaff()).length, 3);
    final fav = (await v2.getFavoriteStaff()).single;
    expect(fav.userId, 'b2');
    expect(fav.department, '교무팀');
    await close(v2);
  });

  test('v1 DB 업그레이드: staff.id 즐겨찾기를 user_id 로 옮긴다', () async {
    // 이전 버전(v1) 스키마와 데이터를 직접 만든다
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE staff (
              id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, name TEXT NOT NULL,
              department TEXT, title TEXT, tel TEXT, cell_tel TEXT, location TEXT,
              email TEXT, charge_business TEXT)''');
          await db.execute(
            'CREATE TABLE favorites (staff_id INTEGER PRIMARY KEY, '
            'FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE)',
          );
        },
      ),
    );
    await old.insert('staff', {'user_id': 'a1', 'name': '가나'}); // id 1
    await old.insert('staff', {'user_id': 'b2', 'name': '다라'}); // id 2
    await old.insert('staff', {'user_id': '', 'name': '아이디없음'}); // id 3
    await old.insert('favorites', {'staff_id': 2});
    await old.insert('favorites', {'staff_id': 3});
    await old.close();

    // 새 버전으로 열면: 업그레이드 → 시드 해시가 없으니 다시 채움
    final h = helper(
      seed([
        ['b2', '다라', '학생지원팀'],
        ['a1', '가나', '총무팀'],
      ]),
    );
    final db = await h.database;
    expect(await db.getVersion(), 3);
    // v3 의 최근 본 교직원 테이블도 생긴다
    await h.addRecent('a1');
    expect((await h.getRecentStaff()).single.name, '가나');
    expect(await h.getFavoriteUserIds(), {'b2'});
    expect((await h.getFavoriteStaff()).single.name, '다라');
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'favorites_v1'",
      ),
      isEmpty,
    );
    await db.close();
  });

  test('seedHash: 같은 문자열은 같은 값, 다르면 다른 값', () {
    expect(seedHash('abc'), seedHash('abc'));
    expect(seedHash('abc'), isNot(seedHash('abd')));
  });
}
