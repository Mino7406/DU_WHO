import '../db/database_helper.dart';

// favorites 테이블의 in-memory 캐시 (앱 시작 시 DB 에서 채움, 토글 시 write-through).
// UI 가 즐겨찾기 여부를 동기로 즉시 읽을 수 있도록 Set 유지.
final Set<int> favoriteStaffIds = <int>{};

Future<void> loadFavoritesFromDb() async {
  final ids = await DatabaseHelper.instance.getFavoriteIds();
  favoriteStaffIds
    ..clear()
    ..addAll(ids);
}

Future<void> toggleFavorite(int staffId) async {
  if (favoriteStaffIds.contains(staffId)) {
    favoriteStaffIds.remove(staffId);
    await DatabaseHelper.instance.removeFavorite(staffId);
  } else {
    favoriteStaffIds.add(staffId);
    await DatabaseHelper.instance.addFavorite(staffId);
  }
}
