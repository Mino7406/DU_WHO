class AppConfig {
  // 키는 저장소에 넣지 않는다. 빌드할 때 넘긴다:
  //   flutter run --dart-define=GROQ_API_KEY=<키>
  // Cloudflare 워커로 옮기면(plan.md A2) 이 파일은 삭제한다.
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');
}
