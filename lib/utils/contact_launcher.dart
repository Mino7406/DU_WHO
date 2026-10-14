import 'package:url_launcher/url_launcher.dart';

// 전화 앱을 연다. 숫자·+ 외 문자는 지우고, 비었거나 0000 이면 무시한다
Future<void> makePhoneCall(String number) async {
  final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.isEmpty || cleaned == '0000') return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// 메일 앱을 연다
Future<void> sendEmail(String email) async {
  if (email.isEmpty) return;
  final uri = Uri(scheme: 'mailto', path: email);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
