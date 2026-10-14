import 'package:du_who/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

// 실제 GitHub Releases API를 호출한다(네트워크 필요, 저장소가 공개여야 함).
void main() {
  test('낮은 버전이면 최신 릴리즈와 APK 주소를 돌려준다', () async {
    final info = await UpdateService.checkForUpdate(currentVersion: '0.0.1');
    expect(info, isNotNull);
    expect(info!.apkUrl, endsWith('.apk'));
  });

  test('더 높은 버전이면 업데이트 없음', () async {
    expect(
      await UpdateService.checkForUpdate(currentVersion: '99.0.0'),
      isNull,
    );
  });
}
