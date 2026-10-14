# DU-WHO 개선 계획

## 📍 현재 상황 (2026-10-14)

**완료한 단계**
- 1단계: 로그인 화면 비활성화(코드 보존, 기본 권한 교직원) · `.gitignore` 보강 · API 키·교직원 JSON 저장소에서 제외
- 2단계: 수신 전화 오탐 수정 (끝자리 매칭 제거 → 무작위 번호 오탐 0.8% → 0%)
- 3단계: AI를 Cloudflare Workers AI로 교체 (`worker/`, 배포 완료) · 질문 키워드 검색 · 역할 필터 · 대화 기록 정리
- 4단계: DB 자동 갱신(시드 해시) · 즐겨찾기 user_id 기준 · DB v3(최근 본 교직원)
- 5단계: 중복 코드 공용화 · 미사용 코드/패키지 삭제
- 6단계(진행 중): 전면 UI 개편 — 대구대 색상규정 그라데이션, 하단 탭(찾기·부서·즐겨찾기), 초성·전화번호 검색, 상세 시트 개편, BETA 걸려온 학교 번호 알림(켜기/끄기·권한·예시 미리보기)

**실기기 확인**: 갤럭시 Z 폴드6 커버 화면(Android 16) — 검색·AI 답변·부서·상세 시트·미리보기 알림 정상
**테스트**: 앱 26개 + 워커 14개 통과, `flutter analyze` 0건

**다음에 할 것**
- 설정 화면 새 스타일 · 다크 모드 · 폴드 펼친 화면 확인
- 미리보기 후 앱 안 토스트 문구("가상번호 …") 정리 여부 결정
- iOS 빌드 확인 (Mac 필요)
- #10 Android 14 포그라운드 서비스 · #14·#15 버전/서명 · README 갱신
- Groq API 키 폐기 (사용자 직접, 추후)
- 공개 저장소 이전 커밋에 남은 키·교직원 JSON 히스토리 정리 여부 (force push 필요 → 결정 후)

---


> 작성일: 2026-10-14
> 기준: 코드 정적 분석 (`flutter analyze` 이슈 0건). 실기기 실행 검증은 아직 안 함.
> 우선순위: 🔴 P0 즉시 / 🟠 P1 기능 버그 / 🟡 P2 품질·유지보수 / 💡 P3 기능 개선

---

## ⭐ 추가 요청 사항

### A1. UI를 알림메모(NotiMemo) 스타일로 변경
- **참고 프로젝트**: `C:\Users\OWNER\Desktop\NotiMemo` (`lib/theme/app_theme.dart`, `lib/widgets/`)
- **알림메모 UI 특징**:
  - 색 토큰 `AppColors` 한 곳에서 관리: 배경 `#F5F6FF` / 다크 `#0B0C14`, 카드 `#FFFFFF` / `#161721`, 테두리 `#EAECF5` / `#252638`
  - 브랜드 그라데이션 `#526AE4 → #A459E7`, 상태색 danger `#EF4444` / success `#10B981`
  - 상단 `TopBar`(로고 + 앱 이름 + 오른쪽 ☰ 메뉴), ☰를 누르면 오른쪽 `endDrawer`(`AppMenuDrawer`)로 기능 모음
  - 상단에 고정된 큰 제목 `HeroTitle` + 설명 `HeroSubtitle`, 그 아래만 스크롤되고 위쪽 끝은 `ShaderMask`로 흐려짐
  - 화면 진입 시 Fade + Slide 애니메이션, 누르면 살짝 작아지는 `AnimatedIconButton`
  - 공통 다이얼로그 `_AppDialog`(취소 = 회색 윤곽선 / 확인 = 강조색), 하단 토스트 `AppToast`, 첫 실행 안내 `CoachMark`
  - 아래 빈 자리에 손글씨체(Caveat) `HomeFooter` 문구
- **DU-WHO 적용 작업**:
  - [ ] 학교 색(녹색 `#1A6B3C`)을 유지할지 알림메모 보라 그라데이션을 쓸지 **결정 필요**
  - [ ] `lib/theme/app_theme.dart` 신설 → `main.dart`의 `_buildLightTheme/_buildDarkTheme`와 각 화면에 흩어진 하드코딩 색 통합
  - [ ] `lib/widgets/` 신설: `TopBar`, `HeroTitle`, `AppMenuDrawer`, `AppDialog`, `AppToast` 이식
  - [ ] 홈: 서비스 카드 목록 → TopBar + Hero + ☰ 메뉴(설정·로그아웃·업데이트 확인을 메뉴로 이동) 구조로 개편
  - [ ] 검색 / 챗봇 / 설정 / 로그인 화면에 같은 스타일 적용
  - [ ] 교직원 상세 바텀시트를 공용 위젯으로 만들면서 새 스타일 적용 (#12와 함께)
  - [ ] 로그아웃·업데이트 다이얼로그를 `AppDialog`로 교체, 즐겨찾기 토글 시 토스트 표시

### A2. AI를 Cloudflare Workers AI로 교체 (알림메모와 같은 방식)
- **참고**: `NotiMemo/worker/` (`wrangler.toml`, `src/index.js`, `src/classify.js`, `test/worker.test.js`), `NotiMemo/lib/services/ai_classifier.dart`
- **알림메모 방식 요약**:
  - Workers AI 바인딩(`[ai] binding = "AI"`) 사용 → **API 키 불필요**
  - 모델 `@cf/meta/llama-3.3-70b-instruct-fp8-fast` (지금 Groq의 Llama 3.3 70B와 같은 계열)
  - `LIMITER` 레이트리밋(60초 6회, `X-Device-Id` 또는 IP 기준) + 앱에서 기기당 하루 호출 상한
  - 요청 크기·입력 길이 검사, 오류는 `{error: 코드}`로 반환 → 앱이 코드별 안내 문구 표시
  - 하루 무료 한도(10,000 뉴런) 초과 시 `quota_exceeded`
  - 앱은 타임아웃(8초) 후 대체 처리, 통신 계층(`AiTransport`)을 갈아끼워 테스트
- **DU-WHO 적용 작업**:
  - [x] `worker/` 신설: `POST /chat`, `GET /health` (`src/index.js`, `src/chat.js`, `wrangler.toml` — 이름 `du-who-ai`, LIMITER 60초 6회)
  - [x] 교직원 DB 검색은 **앱에서** 수행(#5 키워드 추출), 역할에 맞게 거른 결과(#3)만 질문과 함께 워커로 전송
  - [x] 워커는 시스템 프롬프트 + 최근 대화 6개 + (검색 결과·질문을 담은) 마지막 메시지로 모델 호출. 질문 300자·대화 6개·결과 15명·필드 200자 제한, 모르는 필드(휴대폰 등)는 버림
  - [x] 응답 스트리밍 안 함 — 알림메모처럼 JSON 단건 응답 `{reply}`
  - [x] `groq_service.dart` → `ai_chat_service.dart`로 교체, `config.dart`·`--dart-define` 삭제
  - [x] 서버 실패·한도 초과·타임아웃 시 이유 안내 + 로컬 검색 결과 5명 표시 (예외를 던지지 않음)
  - [x] 워커 테스트 14개(`node --test`) + 앱 테스트 12개(`test/ai_chat_service_test.dart`, 가짜 transport) 통과
  - [x] README에 워커 배포 방법(`npx wrangler deploy`) 추가
  - [ ] 개인정보 고지: 질문과 교직원 정보 일부(휴대폰 제외)가 Cloudflare로 전송됨을 앱 안에서 안내
  - [x] **워커 배포** 완료 (2026-10-14, 사용자 확인 후) — `https://du-who-ai.notimemo-ai.workers.dev`, 알림메모와 같은 계정·무료 한도 공유
  - [x] 배포 주소가 `AiChatService.defaultEndpoint`와 같음을 확인 (`/health` 200)
  - [x] 실기기 테스트: "장학금 담당자가 누구야?" → 장학 담당 교직원 2명(장학복지팀 등) 안내 + 근거 카드
  - [x] 오류 문구 정리: 404 "AI 서버를 찾을 수 없습니다", 5xx "AI 서버가 잠시 응답하지 않습니다" (HTTP 코드 그대로 노출하지 않음)
  - [ ] (선택) 앱 쪽 기기당 하루 호출 상한 — 알림메모는 하루 20회. 지금은 워커 LIMITER만 있음

### A3. 개인정보·API 키 git 제외
- **현재 상태**: 저장소 **공개 전환됨**. 커밋 `7b622be`로 키·교직원 JSON을 저장소 최신본에서 제외했지만 **이전 커밋 히스토리에는 남아 있음** → 히스토리 정리 필요
- **작업**:
  - [x] `.gitignore` 보강 (알림메모 `.gitignore` 참고):
    - 비밀 정보: `lib/config.dart`(A2 이후 삭제), `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pem`
    - 워커: `worker/node_modules/`, `worker/.wrangler/`, `worker/.dev.vars`
    - 개인정보 데이터: `sampledb_*.json`, `alias sample data.json`
    - 개인 파일: `.DS_Store`, `.idea/`, `*.iml`, `.vscode/`
  - [ ] `assets/staff_db.json` 처리 방법 **결정 필요**: 빌드에 필요한 파일이므로
    - (a) 실데이터는 git에서 빼고 가명 처리한 샘플(`alias sample data.json` 형식)을 커밋, 릴리즈 빌드에서만 실데이터 사용
    - (b) 실데이터를 서버로 옮기고 앱은 로그인 후 내려받기 (P0 #2와 연결)
  - [ ] GitHub 저장소 히스토리에서 API 키·실데이터 제거 (`git filter-repo` 또는 BFG) 후 force push — **되돌릴 수 없으므로 실행 전 확인**
  - [ ] 이미 공개됐던 키는 히스토리 정리와 별개로 반드시 폐기 (P0 #1)

### A4. 로그인 화면 비활성화 (코드는 보존)
- **목적**: 지금 인증이 가짜(#4)라서 의미가 없음 → 일단 화면에서 빼고, 나중에 실제 인증을 붙일 때 다시 연결
- **위치**: `lib/main.dart:220` (`home:` 분기), `lib/main.dart:227-479` (`LoginScreen`), `lib/home_screen.dart:428-474` (로그아웃 버튼), `lib/auth.dart`
- **작업**:
  - [x] `LoginScreen`을 `lib/login_screen.dart`로 옮기고 어디서도 부르지 않게 함 — **삭제하지 않음**
  - [x] 앱 시작 시 바로 `HomeScreen`으로 진입 (`DuWhoApp`의 `autoLoggedIn` 분기 제거)
  - [x] 기본 역할은 **교직원**으로 고정 (`AuthService._role` 초기값 `UserRole.staff`, `logout()`도 staff 유지) → 직함·휴대폰·전체 위치 모두 표시
    - ⚠️ 앱을 설치한 누구나 교직원 휴대폰 번호(2,210명)를 볼 수 있게 됨. 외부 배포 전에 실제 인증(#4) 또는 학생 기본값으로 되돌릴 것
  - [x] 로그아웃 버튼과 홈의 학생/교직원 뱃지 숨김
  - [x] `restoreSession()` 호출 제거, 남아 있는 `session.json`은 무시 (예전에 교직원으로 저장된 세션이 자동 적용되지 않게)
  - [x] 네이티브(`saveUserRole`)에 교직원 역할(`isStaff: true`)을 앱 시작 시 항상 전달 → 수신 전화 알림도 교직원 기준(휴대폰 번호 매칭 포함)
  - [x] `AuthService`의 역할 판별 로직(`effectivePhone`, `effectiveLocation`)은 그대로 유지 — UI가 계속 이 함수를 쓰도록 둠
  - [x] `lib/auth.dart`의 `const bool kLoginEnabled = false;` 스위치 하나로 분기 (true로 바꾸면 로그인 화면·뱃지·로그아웃·세션 복원이 모두 되살아남)
- **영향**: 모든 사용자가 교직원 권한으로 동작. 학생/교직원 차등 노출(#3, #11 등)은 코드만 유지되고 당장은 효과 없음. 실제 인증(#4)을 붙일 때 다시 의미가 생김.
- **A1과의 관계**: 로그인 화면은 UI 개편 대상에서 제외

### A5. 교직원 검색 + AI 안내를 한 화면으로 병합
- **요청**: "AI 채팅을 일반 채팅과 병합" → 검색 화면과 AI 채팅을 하나로 (사용자 확인)
- **방향**:
  - [ ] 홈의 서비스 카드 2개("교직원 검색", "AI 교직원 안내") → 하나로
  - [ ] 입력창 하나: 입력하면 아래에 검색 결과 목록이 바로 나오고(지금 검색 화면 동작), 질문을 보내면(전송 버튼/엔터) 같은 화면에 AI 답변 말풍선이 함께 나옴
  - [ ] AI 답변과 검색 결과가 같은 키워드 검색(`AiChatService.findRelevantStaff`)을 쓰도록 통일 → 답변에 나온 사람을 목록에서 바로 눌러 상세·전화
  - [ ] 초성 인덱스, 즐겨찾기, 상세 바텀시트는 그대로 유지
  - [ ] `chat_screen.dart`는 병합 후 정리
- **진행 시점**: A1(알림메모 스타일 UI)과 함께 — 6단계

### A6. 전면 UI 개편 (6단계, 사용자 요청 "완전히 바꿔도 좋음") — 진행 중
- **색**: 대구대 색상규정 — DU DEEP GREEN(PANTONE 569C) → DU GREEN(361C) 그라데이션, DU LIGHTGREEN(3956C) 강조, DU BLACK 글자. `lib/theme/app_theme.dart` 한 곳에서 관리
- **구조**: 상단바(로고·☰ 메뉴) + 하단 탭 3개 **찾기 · 부서 · 즐겨찾기** (`home_screen.dart` = 뼈대, `lib/screens/`)
  - [x] 찾기: 검색 + AI 한 화면(A5). 입력 즉시 결과, ✨로 AI 답변 + 근거 교직원 카드. 예시 질문 칩, 최근 본 교직원, 사용 팁
  - [x] **초성 검색**(ㄱㅁㅎ), **전화번호 검색**(0573·850-1234, 교직원 권한이면 휴대폰도), 검색어 **강조 표시**, 관련도 정렬(이름 일치 > 시작 > 포함 > 부서 > 업무)
  - [x] 부서: 207개 부서 목록(인원, 초성 필터) → 부서 화면(교내전화 있는 사람 먼저)
  - [x] 즐겨찾기: ★ 목록 + 최근 본 교직원(DB v3 `recents` 테이블)
  - [x] 상세 시트: 큰 동작 버튼(교내전화·휴대폰·메일), 정보 카드(복사 버튼·길게 눌러 복사), "같은 부서 N명 보기"
  - [x] 공용 위젯: `TopBar`, `HeroTitle`, `AppMenuDrawer`, `showAppDialog`, `showAppToast`, `StaffTile`, `AiExchangeView`
  - [x] 이전 `search_screen.dart`(초성 인덱스), `chat_screen.dart` 삭제, `scrollable_positioned_list` 의존성 제거
- **BETA 걸려온 학교 번호 알림** (사용 팁 아래 카드, 사용자 요청)
  - [x] 켜기/끄기 스위치 → 네이티브 `caller_id_enabled` (Android `CallReceiver`, iOS `CallKitHandler`가 확인)
  - [x] 권한 상태(전화·통화기록·알림·배터리 예외) 표시, 빠지면 "권한 허용" → 거부 상태면 설정 앱 열기
  - [x] "알림 미리보기": 실제 교직원 대신 **예시 정보(홍길동 (예시) · 학생지원팀 · 팀장)와 가상번호 053-850-0000**으로 "[미리보기]" 알림 (사용자 요청). 본문의 "실제 전화가 오면 이렇게 표시돼요 · 가상번호" 줄은 사용자 요청으로 삭제. Android·iOS 동일. 실기기 확인
- **실기기 확인(폴드6 커버 화면)**: 찾기·전화번호 검색·BETA 카드·미리보기 알림·부서 목록·부서 화면·상세 시트 정상
- [ ] 설정 화면을 새 스타일로 (지금은 예전 모양에 새 색만 적용)
- [ ] 다크 모드 실기기 확인, 폴드 펼친 화면(넓은 화면) 레이아웃 확인
- [ ] 테스트: `staff_search_test`(초성·번호·정렬·강조·부서 묶기) 추가 — 전체 26개 통과

---

## 🔴 P0 — 보안 / 개인정보

### 1. Groq API 키 하드코딩
- **위치**: `lib/config.dart:2`
- **문제**: APK 디컴파일 또는 GitHub 저장소에서 키 그대로 노출.
- **해결**:
  - [ ] Groq 콘솔에서 현재 키 **즉시 폐기** (수동)
  - [x] AI를 알림메모와 같은 Cloudflare Workers AI로 교체 → 앱에 키가 아예 없어짐 (**#A2**)
  - [ ] git 제외 및 히스토리 정리 (**#A3**)

### 2. 교직원 DB(휴대폰 번호 포함)가 APK에 평문 번들
- **위치**: `assets/staff_db.json` (2,246명 중 2,210명 휴대폰 번호 포함), 루트 `sampledb_260505.json`
- **문제**: 학생/교직원 차등 노출이 **UI에서만** 적용됨. APK 압축 해제만으로 전체 휴대폰 번호 열람 가능.
- **해결**:
  - [ ] 실데이터 여부 확인 (실데이터면 공개 저장소·배포 자체가 개인정보 이슈)
  - [ ] 학생용 번들에서는 `cell_tel` 제거, 교직원 정보는 서버 인증 후 수신하는 구조 검토
  - [ ] 루트의 샘플 JSON 파일 저장소에서 제외

### 3. AI 챗봇 경유 권한 누수
- **위치**: (이전) `groq_service.dart` `_buildContext` → (현재) `lib/services/ai_chat_service.dart` `staffToContext`
- **문제**: 역할 구분 없이 직함·전체 위치를 LLM에 전달 → 학생도 챗봇으로 숨김 정보 획득 가능.
- **해결**:
  - [x] `staffToContext`에서 `AuthService.isStaff` 확인 (학생: 직위 제외, 위치는 `effectiveLocation()` 건물명만)
  - [x] 휴대폰 번호는 역할과 관계없이 서버로 보내지 않음(교내전화만). 테스트로 확인

### 4. 인증이 하드코딩
- **위치**: `lib/auth.dart:17-30`, `session.json`
- **문제**: 비밀번호 `'12345'` 고정, ID 하드코딩. `session.json`의 `role`을 `staff`로 수정하면 권한 상승.
- **해결**:
  - [ ] (단기) **A4로 로그인 화면을 비활성화** → 이 항목은 실제 인증을 붙일 때까지 보류
  - [ ] (재활성화 시) 데모용임을 명시하고 세션 파일 무결성 확인(서명/HMAC) 또는 `flutter_secure_storage` 사용
  - [ ] (장기) 학교 포털 SSO / 서버 인증 연동

---

## 🟠 P1 — 기능 버그

### 5. AI 챗봇 RAG가 사실상 동작하지 않음
- **위치**: (이전) `groq_service.dart:74` → (현재) `ai_chat_service.dart` `extractKeywords`, `rankStaff`, `findRelevantStaff`
- **문제**: 질문 문장 전체를 `LIKE '%총무부 담당자가 누구야?%'`로 검색 → 거의 항상 0건. LLM이 DB 없이 답변함.
- **해결**:
  - [x] 질문에서 키워드 추출 (조사·불용어 제거, 최대 5개)
  - [x] 키워드별로 검색 후 합치고 점수순 정렬 (이름 일치 > 부서 > 담당업무 > 직함), 상위 15명
  - [x] 결과 없으면 "(검색 결과 없음)"을 프롬프트에 넣고, 시스템 지시로 지어내지 말라고 명시
  - 실데이터 확인: "장학금 담당자가 누구야?" 이전 0명 → 2명, "기숙사 담당 연락처 알려줘" 0명 → 5명, "수강신청 관련 문의는 어느 부서야?" 0명 → 2명

### 6. 챗봇 히스토리 상태 불일치
- **위치**: `lib/services/groq_service.dart:20`, `lib/chat_screen.dart:18-22`
- **문제**:
  - `GroqService` 싱글톤이 히스토리를 유지하지만 화면 재진입 시 UI는 초기화 → 모델은 이전 대화를 기억
  - 로그아웃 시 히스토리 미삭제 (교직원 세션 내용이 학생 세션으로 이어짐)
  - 히스토리 길이 제한 없음 + 매 턴 최대 20명분 컨텍스트 누적 → 토큰 폭증
- **해결**:
  - [x] `ChatScreen.initState`에서 `resetChat()` 호출 (또는 UI 메시지도 서비스에 보관)
  - [x] 로그아웃 시 `AiChatService.instance.resetChat()` (로그인 화면이 켜져 있을 때만 쓰임)
  - [x] 히스토리에는 질문·답변 원문만 저장, DB 검색 결과는 현재 턴에만 포함, 최근 6개만 유지. 실패한 질문은 기록하지 않음

### 7. DB 업데이트가 기존 사용자에게 반영되지 않음
- **위치**: `lib/db/database_helper.dart:15, 33`
- **문제**: `_dbVersion = 1`, 시드가 `onCreate`에서만 실행. 새 `staff_db.json`을 배포해도 기존 설치자 DB는 그대로.
- **해결**:
  - [x] 번들 JSON의 내용 해시(`seedHash`, FNV-1a)를 `meta` 테이블에 저장 → 앱 시작 시 해시가 다르면 `staff`만 다시 채움 (즐겨찾기 유지). **버전 숫자를 올릴 필요 없음** — JSON만 바꿔서 배포하면 됨
  - [x] DB 스키마 v1 → v2 `onUpgrade` 추가 (meta 테이블, favorites 이전)
  - [x] `database` getter를 Future 캐시로 바꿔 동시에 불려도 한 번만 열림
  - [x] 테스트(`test/database_helper_test.dart`, sqflite_common_ffi): 새 설치·JSON 변경 시 재시드·같은 JSON이면 재시드 안 함·v1 업그레이드 통과
  - 실데이터(2,246명) 기준: 변경 없을 때 열기 13ms(해시 10ms 포함), 재시드 0.4초 (PC 측정)

### 8. 즐겨찾기가 AUTOINCREMENT id 기준
- **위치**: `lib/db/database_helper.dart:55-60`, `lib/state/favorites.dart`
- **문제**: 재시드 시 id가 바뀌어 즐겨찾기가 다른 사람을 가리키거나 CASCADE로 삭제됨.
- **해결**:
  - [x] `favorites(user_id TEXT PRIMARY KEY)`로 변경, 메모리 캐시도 `favoriteUserIds: Set<String>` + `isFavorite(staff)`
  - [x] v1 → v2 업그레이드에서 기존 `staff_id` 즐겨찾기를 `user_id`로 옮김 (user_id 없는 행은 버림)

### 9. 수신 전화 매칭 오류 — ⚠️ 실제로 겪은 문제 (P1 최우선)
- **증상(사용자 제보)**: 테스트 중 대구대와 관련 없는 일반 전화번호가 자꾸 교직원으로 감지됨
- **위치**: `CallOverlayService.kt` (`MATCH_SQL`), `ios/Runner/StaffDatabase.swift` (`matchSQL`)
- **원인 (데이터로 확인)**:
  - `tel` 필드 길이 분포: 10자리 1,258건 / **4자리 105건** / 1자리 10건(`.`) / 기타 소수
  - 4자리 값은 내선번호로 보임 (예: 교직원 A `tel: "0573"`)
  - 매칭 SQL의 `? LIKE '%' || tel` 은 "수신 번호가 tel로 **끝나면**" 일치로 판단
  - → `010-1234-0573` 같은 **아무 번호나 끝 4자리가 0573이면** 교직원 A로 표시됨
  - 4자리 내선번호 끝자리 종류가 100개 → **무작위 번호의 약 1%가 오탐**. 하루 전화 수십 통이면 자주 보이는 게 정상인 수준
  - 추가: 교내번호 86개를 246명이 공유 → `LIMIT 1`로 임의의 한 명만 표시
  - 참고: 테스트 행 `테스트 번호`(`cell_tel 010-xxxx-xxxx`, 개인 번호라 가림)도 교직원 권한(A4)에서는 매칭됨 → #16에서 제거
- **해결**:
  - [x] 끝자리 `LIKE` 매칭 제거, **정규화된 전체 번호 정확 일치**만 사용
  - [x] 4자리 내선번호는 학교 대표 국번이 붙은 번호로만 매칭: 수신 번호가 `053850`·`053650`으로 시작하고 끝 4자리가 같을 때만
    (데이터의 전체 번호 앞자리: `053850` 1,170건, `053650` 72건 — 내선이 어느 국번에 속하는지는 학교 확인 필요)
  - [x] 1~3자리·`.`·`0000` 같은 무효 값은 매칭 대상에서 제외
  - [x] 공유 번호면 "○○부 (N명 공용)" + 이름 3명까지 표시 (가장 정확한 순위의 결과끼리만 묶음: 휴대폰 일치 > 교내전화 일치 > 내선)
  - ✖ `tel_norm` 컬럼 추가는 하지 않기로 함: 앱 업데이트 후 앱을 한 번도 안 연 상태에서 전화가 오면 네이티브가 옛 스키마 DB를 읽어 컬럼이 없어 조회가 실패함. 2,246행 REPLACE 비교는 충분히 빠름
  - [x] Android(Kotlin `CallOverlayService.MATCH_SQL`)·iOS(Swift `StaffDatabase.matchSQL`) 같은 SQL로 수정. Android debug APK 빌드 성공, iOS는 Mac 빌드 확인 필요
  - [x] 실데이터 검증(Node 내장 SQLite): 무작위 010 번호 3,000개 중 기존 24개(0.8%) 오탐 → 새 SQL 0개, 실제 교직원 번호 누락 0건. `010-1234-0573` 미매칭, `053-850-0573`·`0573` 매칭 확인
  - [ ] 앱 안 단위 테스트로 옮기기 (#17)
  - [ ] 실기기에서 일반 번호·교내 번호로 수신 테스트

### 10. Android 14+ 포그라운드 서비스 크래시 가능성 (실기기 확인 필요)
- **위치**: `CallOverlayService.kt:190-201`, `AndroidManifest.xml`
- **문제**: API 34에서 `FOREGROUND_SERVICE_TYPE_DATA_SYNC` 사용, 그런데 `FOREGROUND_SERVICE_DATA_SYNC` 권한 미선언 → `startForeground` 실패 후 예외 무시 → `startForegroundService` 후 미호출 크래시 가능.
- **해결 (택1)**:
  - [ ] API 34 이상은 `FOREGROUND_SERVICE_TYPE_SHORT_SERVICE` 사용
  - [ ] **권장**: 포그라운드 서비스 제거, `CallReceiver`에서 `goAsync()`로 DB 조회 후 바로 알림 표시
- [ ] Android 13 / 14 / 15 실기기에서 수신 테스트

### 11. 검색 입력 경쟁 상태 / 권한 우회
- **위치**: `lib/search_screen.dart:143-154, 426`, `lib/db/database_helper.dart:89-104`
- **문제**:
  - 입력마다 DB 쿼리, debounce 없음 → 늦게 도착한 이전 결과가 최신 결과를 덮어씀
  - 학생도 "전체" 모드에서 숨겨진 직함(title)으로 검색 가능
- **해결**:
  - [ ] 250ms debounce + 요청 번호로 오래된 응답 무시
  - [ ] 학생은 검색 조건에서 `title` 제외

---

## 🟡 P2 — 코드 품질 / 유지보수

### 12. 중복 코드
- [x] `_showStaffDetails`, `_detailRow`, `_makePhoneCall`, `_sendEmail` 중복 제거 → `lib/widgets/staff_detail_sheet.dart`(`showStaffDetailSheet`), `lib/utils/contact_launcher.dart`(`makePhoneCall`, `sendEmail`)
  - 홈·검색 합계 약 400줄 감소. 검색 화면 상세 시트에도 즐겨찾기 ★ 생김(홈은 해제 시 시트 닫힘 유지)

### 13. 홈 화면 즐겨찾기 로딩 비효율
- **위치**: `lib/home_screen.dart:143-152`
- [x] 전체 2,246명 로드 후 필터 → `getFavoriteStaff()` (`WHERE user_id IN (SELECT ...)`) 쿼리로 변경 (4단계에서 함께)

### 14-1. 자동 업데이트 감지 — ✅ 저장소 공개 전환으로 해결 (2026-10-14 테스트)
- **원인이었던 것**: 저장소가 비공개라 인증 없는 GitHub Releases API 호출이 항상 404 → 업데이트 다이얼로그가 안 뜸
- **현재**: 공개 전환 후 API 200, 최신 `v1.1.0` + `DU_WHO_v1.1.0.apk` 다운로드 링크 정상(200)
- [x] `UpdateService.checkForUpdate({currentVersion})` 매개변수 추가 → `test/update_service_test.dart`에서 실제 API로 확인
  - `0.0.1` → v1.1.0 감지 + APK 주소 반환 ✓ / `99.0.0` → 업데이트 없음 ✓ / 현재 `1.1.0` → 업데이트 없음 ✓
- [ ] 실기기에서 다이얼로그 → "지금 업데이트" → APK 다운로드·설치까지 확인 (다음 릴리즈 때)
  - ⚠️ 릴리즈 APK가 debug 키로 서명됨(#15) → 서명 키가 바뀌면 덮어쓰기 설치가 실패하므로 릴리즈 키를 먼저 정할 것
- [ ] 404/네트워크 오류일 때 수동 확인에서 "최신 버전" 대신 "확인할 수 없음"으로 표시

### 14. 앱 버전 이중 관리
- **위치**: `lib/services/update_service.dart:4` (`'1.1.0'`), `pubspec.yaml` (`1.1.0+2`)
- [ ] `package_info_plus`로 런타임 버전 조회해 단일화

### 15. 배포 설정
- **위치**: `android/app/build.gradle.kts`
- [ ] release 서명키 생성 및 `signingConfig` 설정 (현재 debug 키 → 서명 바뀌면 업데이트 설치 불가)
- [ ] `applicationId` `com.example.du_who` → 고유 ID로 변경 (변경 시 기존 설치와 별개 앱이 됨 → 시점 결정 필요)
- [ ] `android:label="DU_WHO"` → `DU-WHO` 통일
- [ ] 빌드 경고 대응: Android Gradle Plugin 8.11.1 → 9.0.1 이상, Kotlin 2.2.20 → 2.3.20 이상 (`android/settings.gradle.kts`) — Flutter 지원 곧 종료 예정

### 16. 쓰지 않는 코드 / 데이터 정리
- [x] `lib/call_screen.dart` 삭제 (미사용 하드코딩 목업)
- [x] `pubspec.yaml`에서 미사용 `google_generative_ai` 제거
- [ ] (출시 전) `staff_db.json`의 테스트 행 5건 제거 — 지금은 수신 전화 팝업 테스트에 쓰고 있어 보류. 파일은 git 밖(로컬)에만 있음 (`테스트 번호`, `테스트3`, `테스트4`, `테스트5`, `테스트02`)
- [x] `.DS_Store`·`.idea`·`*.iml` 저장소에서 제외 및 `.gitignore` 추가

### 17. 테스트 부재
- [x] `test/widget_test.dart` 기본 카운터 테스트 삭제
- 지금 있는 테스트 18개: `ai_chat_service_test`(12: 키워드 추출·정렬·역할 필터·대화 기록·오류), `database_helper_test`(4: 시드·마이그레이션), `update_service_test`(2: 실제 GitHub API) + 워커 `node --test` 14개
- [ ] 남은 단위 테스트: `AuthService.effectivePhone/effectiveLocation`, 초성 추출, 전화번호 매칭 SQL(지금은 Node로 일회성 검증만)

### 18. README 정합성
- [ ] 검색 화면 설명 수정 (실제는 `ScrollablePositionedList` 사용)
- [x] 설치 방법의 "메모 입력 및 알림 고정 기능" 문구 수정 + "직접 빌드" 안내 추가
- [ ] 개발팀 표 인원 확인

### 19. 플랫폼 정리 — Android + iOS 유지, 데스크톱·웹 제거 (완료)
- [x] `macos/`, `linux/`, `windows/`, `web/` 폴더 제거 (휴지통으로 이동)
- [x] `ios/`는 사용자 요청으로 **복원** — #9 매칭 수정(`StaffDatabase.swift`, `NotificationManager.swift`) 포함. 복원본은 이전 커밋과 비교해 이 두 파일만 다름을 확인
- [x] `.metadata`는 root·android·ios 항목만 남김
- [ ] iOS 빌드 확인 (Swift는 Windows에서 컴파일 불가 → Mac에서 `flutter build ios`)
- iOS 한계: `CXCall`이 발신 번호를 주지 않아 자동 식별 불가 → 안내 알림 + 수동 조회만 가능. 장기적으로 Call Directory Extension 검토

---

## 💡 P3 — 기능 개선 (버그 수정 이후)

- [ ] 초성 검색 (`ㄱㅁㅎ` → 김민호)
- [ ] 챗봇 응답 마크다운 렌더링 + 전화번호/이메일 탭으로 바로 연결
- [ ] 최근 검색어, 부서별 그룹 보기
- [ ] 챗봇 추천 질문 칩 (예: "장학금 담당자", "학적 업무")

---

## 진행 순서 제안

1. **#1 API 키 폐기** (수동, 즉시) + **A3** `.gitignore` 보강, git 저장소 상태 확인 + **A4** 로그인 화면 비활성화 (작업량 작음)
2. **#9 수신 전화 오탐 수정** (실제 겪은 문제, 수정 범위 작음) → 실기기에서 일반 번호로 재현·확인
3. **A2 + #3, #5, #6** Cloudflare 워커로 교체하면서 챗봇 권한 누수·RAG·히스토리를 함께 수정
4. **#7, #8** DB 마이그레이션 + 즐겨찾기 키 변경 (함께 처리)
5. **#12, #16** 중복 코드 공용 위젯화 + 쓰지 않는 코드 정리 → **A1** UI 개편의 기반
6. **A1 + A5** 알림메모 스타일 UI 적용 + 검색·AI 한 화면 병합 (#11, #13 검색·홈 수정 포함)
7. **#10** Android 포그라운드 서비스 안정화 → 실기기 검증 (#9 오탐 수정은 2단계에서 먼저)
8. **#14-1, #14, #15, #17, #18** 업데이트 감지·버전·서명·테스트·README 정리
9. P3 기능 개선

## 결정이 필요한 것

- [ ] A1: 브랜드 색 — 대구대 녹색 유지 vs 알림메모 보라 그라데이션
- [ ] A3: `staff_db.json` 실데이터 처리 방식 (가명 샘플 커밋 vs 서버 이전)
- [ ] A3: GitHub 히스토리 정리(force push) 진행 여부 — 비공개 저장소라 급하지 않음, 공개 전환 시 필수
- [ ] A4: 외부 배포(GitHub 릴리즈) 전에 기본 권한을 교직원으로 둘지, 학생으로 되돌릴지
- [ ] #14-1: 업데이트 배포 경로 — 공개 릴리즈 저장소 vs 워커 `/version`
- [ ] #15: `applicationId` 변경 시점 (변경하면 기존 설치 앱과 별개 앱이 됨)
