import '../db/database_helper.dart';
import '../staff_model.dart';

// favorites 테이블의 in-memory 캐시 (앱 시작 시 DB 에서 채움, 토글 시 write-through).
// UI 가 즐겨찾기 여부를 동기로 즉시 읽을 수 있도록 Set 유지.
// 키는 user_id. staff.id 는 교직원 데이터를 다시 채우면 바뀌기 때문이다.
final Set<String> favoriteUserIds = <String>{};

bool isFavorite(Staff s) =>
    s.userId.isNotEmpty && favoriteUserIds.contains(s.userId);

Future<void> loadFavoritesFromDb() async {
  final ids = await DatabaseHelper.instance.getFavoriteUserIds();
  favoriteUserIds
    ..clear()
    ..addAll(ids);
}

Future<void> toggleFavorite(Staff s) async {
  final userId = s.userId;
  if (userId.isEmpty) return;
  if (favoriteUserIds.contains(userId)) {
    favoriteUserIds.remove(userId);
    await DatabaseHelper.instance.removeFavorite(userId);
  } else {
    favoriteUserIds.add(userId);
    await DatabaseHelper.instance.addFavorite(userId);
  }
}
