import 'package:flutter/services.dart';

/// 걸려온 학교 번호 알림(BETA)의 상태. 네이티브(Android/iOS)가 알려준다
class CallerIdStatus {
  /// 자동 식별 가능 여부. iOS 는 발신 번호를 못 읽어 false
  final bool supported;
  final bool enabled;
  final bool phone;
  final bool callLog;
  final bool notifications;
  final bool battery;

  /// "다른 앱 위에 표시". 있으면 수신 화면 위에 크게 띄우고, 없으면 알림만 뜬다
  final bool overlay;

  const CallerIdStatus({
    required this.supported,
    required this.enabled,
    this.phone = true,
    this.callLog = true,
    this.notifications = true,
    this.battery = true,
    this.overlay = true,
  });

  /// 알림이 실제로 뜨는 데 필요한 권한이 모두 있는지
  bool get ready => phone && callLog && notifications;

  static CallerIdStatus fromMap(Map<dynamic, dynamic> m) => CallerIdStatus(
    supported: m['supported'] == true,
    enabled: m['enabled'] != false,
    phone: m['phone'] != false,
    callLog: m['callLog'] != false,
    notifications: m['notifications'] != false,
    battery: m['battery'] != false,
    overlay: m['overlay'] != false,
  );
}

/// 네이티브 수신 전화 식별 기능과 통신한다(MethodChannel du_who/call_overlay)
class CallerIdService {
  static const _channel = MethodChannel('du_who/call_overlay');

  /// 상태를 못 읽으면(데스크톱·테스트 등) null
  static Future<CallerIdStatus?> status() async {
    try {
      final m = await _channel.invokeMethod<Map>('getCallerIdStatus');
      return m == null ? null : CallerIdStatus.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setCallerIdEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  /// "다른 앱 위에 표시" 설정 화면을 연다(사용자가 직접 켜야 한다)
  static Future<void> requestOverlay() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// [number]로 전화가 온 것처럼 화면·알림을 띄운다. 실제 수신과 같은 DB 조회·알림 경로를 쓴다
  static Future<bool> preview(String number) async {
    try {
      return await _channel.invokeMethod<bool>('previewCallerId', {
            'number': number,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
