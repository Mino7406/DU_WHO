import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../staff_model.dart';
import '../utils/staff_search.dart';
import 'favorites.dart' as fav;

/// 세 탭(찾기·부서·즐겨찾기)이 같이 보는 데이터. 바뀌면 notifyListeners 로 모든 탭이 다시 그린다.
/// 교직원 전체(2,246명)는 한 번만 읽어 메모리에 두고 검색·부서 묶기에 쓴다.
class AppData extends ChangeNotifier {
  AppData._();
  static final AppData instance = AppData._();

  List<Staff> _all = const [];
  List<DepartmentInfo> _departments = const [];
  List<Staff> _favorites = const [];
  List<Staff> _recents = const [];
  bool _loaded = false;

  List<Staff> get all => _all;
  List<DepartmentInfo> get departments => _departments;
  List<Staff> get favorites => _favorites;
  List<Staff> get recents => _recents;
  bool get loaded => _loaded;

  Future<void> load() async {
    final db = DatabaseHelper.instance;
    _all = await db.getAllStaff();
    _departments = groupByDepartment(_all);
    await fav.loadFavoritesFromDb();
    _favorites = await db.getFavoriteStaff();
    _recents = await db.getRecentStaff();
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(Staff s) async {
    await fav.toggleFavorite(s);
    _favorites = await DatabaseHelper.instance.getFavoriteStaff();
    notifyListeners();
  }

  /// 상세를 열거나 전화를 걸면 최근 본 교직원으로 기록한다
  Future<void> addRecent(Staff s) async {
    if (s.userId.isEmpty) return;
    await DatabaseHelper.instance.addRecent(s.userId);
    _recents = await DatabaseHelper.instance.getRecentStaff();
    notifyListeners();
  }

  Future<void> clearRecents() async {
    await DatabaseHelper.instance.clearRecents();
    _recents = const [];
    notifyListeners();
  }

  /// 같은 부서 사람들(본인 포함)
  List<Staff> colleaguesOf(Staff s) {
    final d = s.department.trim().isEmpty ? '기타' : s.department.trim();
    for (final g in _departments) {
      if (g.name == d) return g.members;
    }
    return const [];
  }
}
