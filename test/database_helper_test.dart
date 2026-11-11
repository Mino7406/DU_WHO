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
    await h.addFavorite('b2', owner: 'u1');
    expect(await h.getFavoriteUserIds(owner: 'u1'), {'b2'});
    expect((await h.getFavoriteStaff(owner: 'u1')).single.name, '다라');
    await h.removeFavorite('b2', owner: 'u1');
    expect(await h.getFavoriteStaff(owner: 'u1'), isEmpty);
    await close(h);
  });

  test('즐겨찾기는 계정(owner)마다 따로 저장된다', () async {
    final h = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    await h.addFavorite('a1', owner: '22124248');
    await h.addFavorite('b2', owner: '22124248');
    await h.addFavorite('b2', owner: '32152');
    await h.addFavorite('b2', owner: '32152'); // 같은 줄은 하나만 남는다

    expect(await h.getFavoriteUserIds(owner: '22124248'), {'a1', 'b2'});
    expect(await h.getFavoriteUserIds(owner: '32152'), {'b2'});
    expect(await h.getFavoriteUserIds(owner: ''), isEmpty);

    // 한 계정에서 빼도 다른 계정의 같은 교직원 즐겨찾기는 남는다
    await h.removeFavorite('b2', owner: '22124248');
    expect(await h.getFavoriteUserIds(owner: '22124248'), {'a1'});
    expect((await h.getFavoriteStaff(owner: '32152')).map((s) => s.name), [
      '다라',
    ]);
    await close(h);
  });

  test('시드 JSON 이 바뀌면 다시 채우고, 즐겨찾기는 유지된다', () async {
    final v1 = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    await v1.addFavorite('b2', owner: 'u1');
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
    final fav = (await v2.getFavoriteStaff(owner: 'u1')).single;
    expect(fav.userId, 'b2');
    expect(fav.department, '교무팀');
    await close(v2);
  });

  test('v1 DB 업그레이드: v4 까지 올라가고, 계정 구분 없던 즐겨찾기는 버린다', () async {
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
    expect(await db.getVersion(), 4);
    // v3 의 최근 본 교직원 테이블도 생긴다
    await h.addRecent('a1');
    expect((await h.getRecentStaff()).single.name, '가나');
    // 계정 구분이 없던 기존 즐겨찾기는 남지 않는다
    expect(await h.getFavoriteUserIds(owner: ''), isEmpty);
    expect(await h.getFavoriteStaff(owner: ''), isEmpty);
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'favorites_v1'",
      ),
      isEmpty,
    );
    await db.close();
  });

  test('v3 DB 업그레이드: 즐겨찾기를 owner 가 있는 구조로 새로 만들고 기존 기록은 버린다', () async {
    // v3 스키마(favorites 에 owner 없음)와 데이터를 직접 만든다
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE staff (
              id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, name TEXT NOT NULL,
              department TEXT, title TEXT, tel TEXT, cell_tel TEXT, location TEXT,
              email TEXT, charge_business TEXT)''');
          await db.execute('CREATE TABLE favorites (user_id TEXT PRIMARY KEY)');
          await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.execute(
            'CREATE TABLE recents (user_id TEXT PRIMARY KEY, at INTEGER NOT NULL)',
          );
        },
      ),
    );
    await old.insert('favorites', {'user_id': 'b2'});
    await old.close();

    final h = helper(
      seed([
        ['a1', '가나', '총무팀'],
        ['b2', '다라', '학생지원팀'],
      ]),
    );
    final db = await h.database;
    expect(await db.getVersion(), 4);
    final cols = await db.rawQuery('PRAGMA table_info(favorites)');
    expect(cols.map((c) => c['name']), containsAll(['owner', 'user_id']));
    expect(await h.getFavoriteUserIds(owner: ''), isEmpty);
    expect(await h.getFavoriteUserIds(owner: '22124248'), isEmpty);
    // 업그레이드 뒤 새로 넣는 즐겨찾기는 정상 저장된다
    await h.addFavorite('b2', owner: '22124248');
    expect(await h.getFavoriteUserIds(owner: '22124248'), {'b2'});
    await db.close();
  });

  test('seedHash: 같은 문자열은 같은 값, 다르면 다른 값', () {
    expect(seedHash('abc'), seedHash('abc'));
    expect(seedHash('abc'), isNot(seedHash('abd')));
  });
}
