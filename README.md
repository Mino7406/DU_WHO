<div align="center">

<h1>
  <a href="https://github.com/Mino7406/DU_WHO/releases"><img src="assets/logo.png" width="100" alt="DU-WHO 앱 아이콘"></a><br>
  DU-WHO
</h1>

대구대학교 교직원을 이름, 부서, 담당업무, 전화번호로 찾는 안드로이드 앱입니다. AI에게 "장학금 담당자가 누구야?"처럼 물어볼 수 있고, 학교 번호로 전화가 오면 누구인지 알림으로 알려 줍니다(BETA). 화면은 [Flutter](https://flutter.dev/), 수신 전화 식별은 [네이티브(Kotlin)](https://kotlinlang.org/)로 작성했습니다.

[![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://developer.android.com/)
[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Kotlin](https://img.shields.io/badge/Kotlin-native-7F52FF?style=flat-square&logo=kotlin&logoColor=white)](https://kotlinlang.org/)
[![SQLite](https://img.shields.io/badge/SQLite-local-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://pub.dev/packages/sqflite)
[![AI server](https://img.shields.io/badge/AI-Cloudflare%20Workers-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/workers-ai/)
![language](https://img.shields.io/badge/docs-한국어-blue?style=flat-square)

</div>

### 목차

| | 문서 | 내용 |
|:--:|---|---|
| ✨ | [주요 기능](#주요-기능) | 앱에서 할 수 있는 것 |
| 🧰 | [기술 스택](#기술-스택) · [폴더 구조](#폴더-구조) | 쓴 라이브러리와 파일 배치 |
| 🚀 | [설치 및 실행](#설치-및-실행) | APK 설치, 직접 빌드, AI 서버 배포 |
| ⚙️ | [설정](#설정) | 설정 화면 항목과 코드 안의 상수 |
| 🎛️ | [화면과 버튼](#화면과-버튼) | 하단 탭, ☰ 메뉴, 상세 시트 정리 |
| 🔍 | [기능 상세](#기능-상세) | 기능별 동작 순서 (눌러서 펼치기) |
| 🧩 | [주요 함수](#주요-함수) | 파일별 핵심 함수 (눌러서 펼치기) |
| 🗂️ | [데이터 저장](#데이터-저장) | DB 테이블과 네이티브·Flutter가 나눠 쓰는 값 |
| 🔐 | [신분별 정보 노출](#신분별-정보-노출) · [권한](#권한) | 학생/교직원 차이, 안드로이드 권한 |

---

## 주요 기능

**🔎 찾기 (검색 + AI 한 화면)**

- **바로 검색**: 입력하는 대로 아래에 결과가 나옵니다. 교직원 2,246명을 메모리에 올려 두고 찾기 때문에 인터넷이 없어도 됩니다.
- **초성 · 번호 검색**: `ㄱㅁㅎ`처럼 초성만 넣거나, `0573`, `850-1234`처럼 번호 일부만 넣어도 찾습니다. 걸린 글자는 강조해서 보여 줍니다.
- **관련도 정렬**: 이름 일치 > 이름 시작 > 이름 포함 > 부서 > 담당업무 > 직위 순으로 위에 올립니다. 검색 범위는 `전체` / `이름·부서`로 바꿀 수 있습니다.
- **AI 안내(✨)**: 문장으로 묻고 ✨를 누르면, 앱이 DB에서 관련 교직원을 골라 AI 서버로 보내고 그 자료만 근거로 답을 받습니다. 답 아래에 근거 교직원이 카드로 붙어서 바로 전화하거나 상세를 열 수 있습니다.

**🏢 부서 · ⭐ 즐겨찾기**

- **부서별 보기**: 부서 목록(인원 수)을 이름으로 거르고, 누르면 그 부서 사람들을 봅니다. 교내전화가 있는 사람이 먼저 나옵니다.
- **즐겨찾기 · 최근 본 교직원**: 자주 연락하는 사람을 ★로 모아 두고, 최근에 상세를 열거나 전화한 사람을 따로 보여 줍니다.
- **상세 시트**: 교내전화, 휴대폰, 메일을 큰 버튼으로 바로 실행합니다. 정보를 길게 누르면 복사되고, `같은 부서 보기`로 동료 목록으로 넘어갑니다.

**📞 걸려온 학교 번호 알림 (BETA)**

- 전화가 오면 번호를 DB에서 찾아 교직원이면 소속, 직위, 위치를 헤드업 알림으로 띄웁니다. 여러 명이 같이 쓰는 번호면 부서 단위로 보여 줍니다.
- 찾기 화면의 BETA 카드에서 켜고 끄고, 필요한 권한 상태를 보고, 예시 정보와 가상번호로 `수신 화면 미리보기`를 해 볼 수 있습니다.

**🧩 그 밖에**

- 대구대학교 색상규정(DU DEEP GREEN → DU GREEN 그라데이션)을 따른 라이트/다크 테마
- 앱을 켤 때 GitHub 최신 릴리스 확인, ☰ 메뉴에서 수동 확인
- 앱 업데이트로 새 교직원 데이터가 들어오면 자동으로 DB를 갈아 끼웁니다. 즐겨찾기는 그대로 남습니다.

> [!NOTE]
> 교직원 정보는 학교 포털에서 받은 시점 기준이라 **최신이 아닐 수 있습니다.** 앱 안에도 같은 안내가 나옵니다.

---

## 기술 스택

- **[Flutter](https://flutter.dev/) / Dart** (`^3.11.5`): 화면, 검색, AI 호출, 상태 관리(`ValueNotifier` / `ChangeNotifier`, 별도 라이브러리 없음)
- **Kotlin**: 수신 전화 감지(`BroadcastReceiver`), 발신자 알림 서비스, 권한·배터리 예외 요청
- **[sqflite](https://pub.dev/packages/sqflite) ^2.3.3**: 교직원, 즐겨찾기, 최근 본 교직원을 담는 로컬 DB
- [http](https://pub.dev/packages/http), [url_launcher](https://pub.dev/packages/url_launcher), [permission_handler](https://pub.dev/packages/permission_handler), [path_provider](https://pub.dev/packages/path_provider), [path](https://pub.dev/packages/path)
- **[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai/)**: AI 안내 서버(`worker/`), 모델은 `@cf/meta/llama-3.3-70b-instruct-fp8-fast`. 앱에 API 키가 들어 있지 않습니다.
- 테스트: `flutter_test`, `sqflite_common_ffi`(PC에서 DB 테스트), 워커는 `node --test`

---

## 폴더 구조

```
DU_WHO/
├─ lib/
│  ├─ main.dart                  # 시작점. DB 열기, 테마·즐겨찾기 불러오기, 네이티브에 DB 경로·신분 전달
│  ├─ home_screen.dart           # 뼈대. 상단바 + ☰ 메뉴 + 하단 탭 3개, 권한 요청, 업데이트 확인
│  ├─ settings_screen.dart       # 설정. 테마, 앱 정보, 업데이트 확인
│  ├─ auth.dart                  # 신분(학생/교직원)과 세션 파일. 지금은 로그인 꺼 둠(kLoginEnabled)
│  ├─ login_screen.dart          # 로그인 화면(로그인을 켤 때 쓰려고 보존)
│  ├─ staff_model.dart           # Staff 모델 (fromJson / fromMap / toMap)
│  ├─ screens/
│  │  ├─ find_tab.dart           # 찾기 탭. 검색 + AI 질문·답변 + 사용 팁 + BETA 카드
│  │  ├─ departments_tab.dart    # 부서 탭. 부서 목록과 이름 필터
│  │  ├─ department_screen.dart  # 한 부서의 교직원 목록
│  │  └─ favorites_tab.dart      # 즐겨찾기 탭. ★와 최근 본 교직원
│  ├─ services/
│  │  ├─ ai_chat_service.dart    # 질문 키워드 추출, DB 검색, 서버 호출, 실패하면 로컬 결과로 안내
│  │  ├─ caller_id_service.dart  # 걸려온 번호 알림(BETA) 상태·켜기·미리보기 (네이티브 호출)
│  │  └─ update_service.dart     # GitHub 최신 릴리스와 버전 비교
│  ├─ db/database_helper.dart    # SQLite 생성·업그레이드, 시드 동기화, 즐겨찾기·최근 기록
│  ├─ state/                     # AppData(세 탭 공용 데이터), 즐겨찾기 전역 상태
│  ├─ utils/                     # staff_search(초성·번호·관련도 검색, 부서 묶기), 전화·메일 실행
│  ├─ widgets/                   # 상세 시트, 교직원 카드, AI 답변, BETA 카드, 메뉴, 다이얼로그·토스트
│  └─ theme/app_theme.dart       # 대구대 색상과 라이트/다크 테마
├─ android/app/src/main/kotlin/com/example/du_who/
│  ├─ CallReceiver.kt            # 전화 수신 감지. 스위치가 꺼져 있으면 아무것도 안 함
│  ├─ CallOverlay.kt             # 번호로 DB 조회 → 수신 화면 위 전체 화면(받기·거절) + 헤드업 알림
│  └─ MainActivity.kt            # Flutter와 네이티브 사이 통신(du_who/call_overlay)
├─ ios/                          # iOS 빌드(전화번호 직접 입력 조회). 릴리스는 안드로이드만
├─ worker/                       # AI 안내 서버(Cloudflare Workers AI)
│  ├─ src/index.js               # /chat, /health. 크기·JSON 확인, 횟수 제한, AI 호출
│  ├─ src/chat.js                # 요청 검증, 프롬프트 구성, 답변 정리(순수 로직)
│  └─ test/worker.test.js
├─ test/                         # 검색, DB, AI 서비스, 업데이트 비교 테스트
└─ assets/                       # 앱 아이콘(logo.png), 교직원 데이터(staff_db.json, 가상 인물)
```

---

## 설치 및 실행

[Releases](https://github.com/Mino7406/DU_WHO/releases)에서 최신 APK(`DU_WHO_v*.apk`)를 받아 설치합니다. 갤럭시(One UI)에서 테스트했습니다.

> [!IMPORTANT]
> **v1.1.0 이하를 쓰고 계셨다면 삭제하고 새로 설치해 주세요.** 서명 키가 바뀌어서 이전 앱 위에는 덮어쓸 수 없습니다. 삭제하면 즐겨찾기와 최근 본 교직원이 사라집니다.

> [!NOTE]
> 출처를 알 수 없는 앱이라는 경고가 뜨면 **무시하고 설치**를 누르세요. 처음 켜면 알림, 전화, 통화 기록 권한과 배터리 최적화 예외를 차례로 물어봅니다. 걸려온 학교 번호 알림을 쓰지 않으면 거절해도 검색과 AI는 그대로 됩니다.

직접 빌드하려면:

```bash
flutter pub get
flutter test
flutter run --release
```

> [!IMPORTANT]
> **저장소의 교직원 데이터(`assets/staff_db.json`)는 시연용 가상 인물 2,246명입니다.** 실제 교직원 정보는 개인정보라 저장소에 올리지 않습니다. 가상 데이터는 학교 포털 `memberSearchList` 형식을 따르고, 부서명만 실제 학교 부서를 씁니다. `test/demo_data_test.dart`가 아이디(`demo`로 시작)와 번호(`053-000-`, `010-0000-`)를 검사해서 실제 데이터가 섞이면 테스트가 실패합니다. 파일 내용이 바뀌면 다음 실행 때 해시를 비교해서 DB를 다시 채웁니다.

### AI 서버 (`worker/`)

앱이 호출하는 서버 코드입니다. Workers AI 바인딩을 쓰기 때문에 API 키가 필요 없습니다. 직접 배포하려면:

```bash
cd worker
npm install
npm test          # node --test
npx wrangler deploy
```

배포하고 나온 주소를 [`lib/services/ai_chat_service.dart`](lib/services/ai_chat_service.dart)의 `defaultEndpoint`에 넣으면 됩니다. `wrangler.toml`의 `MODEL`로 모델을 바꿀 수 있고, 짧은 시간에 몰리는 요청을 막는 `LIMITER`(60초에 6회)도 들어 있습니다.

> [!TIP]
> **VPN을 켜면** AI 서버에 연결되지 않을 수 있습니다. 그때는 오류 대신 로컬 검색 결과로 만든 안내가 나옵니다.

---

## 설정

설정 화면(☰ → 설정)에서 바꾸는 값입니다.

| 항목 | 설명 | 기본값 |
|---|---|---|
| 테마 | 시스템 기본값, 라이트, 다크 | 시스템 기본값 |
| 앱 정보 | 앱 이름, 버전과 업데이트 확인, 제공 | |
| 걸려온 학교 번호 알림 | 찾기 화면의 BETA 카드에서 켜고 끕니다 | 켜짐 |

설정 화면이 아니라 코드에서 바꾸는 상수:

| 상수 | 위치 | 설명 |
|---|---|---|
| `kLoginEnabled` | `auth.dart` | 로그인 화면 사용 여부. `false`인 동안은 모두 교직원 권한으로 동작합니다 |
| `AiChatService.maxHistory` | `services/ai_chat_service.dart` | 서버로 보내는 최근 대화 개수(6). 워커의 `MAX_HISTORY`와 같아야 합니다 |
| `AiChatService.maxStaff` | 같은 파일 | 근거로 보내는 교직원 최대 인원(15). 워커의 `MAX_STAFF`와 같아야 합니다 |
| `AiChatService.maxQuestionLength` | 같은 파일 | 질문 최대 길이(300자). 넘으면 잘라서 보냅니다 |
| `AiChatService.timeout` | 같은 파일 | 서버 응답을 기다리는 시간(20초). 넘으면 로컬 결과로 대신합니다 |
| `_pageSize` | `screens/find_tab.dart` | 검색 결과를 한 번에 그리는 개수(60). 스크롤하면 더 보여 줍니다 |
| `_kCurrentVersion` | `services/update_service.dart` | 업데이트 비교에 쓰는 현재 버전. `pubspec.yaml`과 같이 올립니다 |

---

## 화면과 버튼

| 위치 | 버튼 | 동작 |
|---|---|---|
| 하단 탭 | `찾기` | 검색 + AI. 이미 찾기 탭에서 다시 누르면 입력창으로 올라가 바로 입력합니다 |
| 하단 탭 | `부서` / `즐겨찾기` | 부서 목록 / ★와 최근 본 교직원 |
| 찾기 입력창 | ✕ | 입력 지우기 |
| 찾기 입력창 | ✨ (또는 키보드의 검색) | 입력한 문장을 AI에게 보냅니다 |
| 찾기 입력창 아래 | `전체` / `이름·부서` 칩 | 검색 범위 바꾸기 |
| 찾기(빈 화면) | 예시 질문, 최근 본 교직원, 사용 팁, BETA 카드 | 누르면 바로 질문하거나 상세를 엽니다 |
| 상단 | ☰ | 오른쪽에서 밀려 나오는 메뉴 |
| ☰ 메뉴 | 교직원 찾기, 부서별 보기, 즐겨찾기 | 해당 탭으로 이동(부서·즐겨찾기는 개수 표시) |
| ☰ 메뉴 | AI 대화 지우기 | 대화가 있을 때만 보입니다 |
| ☰ 메뉴 | 업데이트 확인, 설정 | 최신 버전 확인, 설정 화면 |
| 상세 시트 | `교내전화` `휴대폰` `메일` | 전화 걸기 / 메일 쓰기 |
| 상세 시트 | 정보 길게 누르기, 복사 아이콘, ★ | 복사, 즐겨찾기 추가·해제 |
| 상세 시트 | `○○과 N명 보기` | 같은 부서 목록으로 이동 |

---

## 기능 상세

> [!TIP]
> 항목 제목을 클릭하면 상세 내용이 펼쳐집니다.

<details>
<summary>🔎 <b>검색</b> <sub><code>utils/staff_search.dart</code>, <code>screens/find_tab.dart</code></sub></summary>

1. 앱을 켜면 `AppData`가 교직원 전체를 한 번 읽어 메모리에 둡니다. 검색은 DB가 아니라 이 목록에서 하기 때문에 입력이 멈추면 바로 결과가 나옵니다.
2. 입력이 어떤 모양인지 먼저 봅니다.
   - 숫자 3자리 이상(하이픈·공백·`+` 허용)이면 **전화번호 검색**: 번호 일치 > 끝자리 일치 > 포함. 교직원 신분이면 휴대폰도 봅니다.
   - 공백을 뺀 글자가 모두 초성이면(두 글자 이상) **초성 검색**: 이름 초성이 같음 > 그걸로 시작 > 포함.
   - 그 밖에는 이름, 부서, (직위), 담당업무에 포함되는지 봅니다. 공백으로 나눈 낱말은 모두 걸려야 합니다(AND).
3. 점수는 이름 일치 > 이름 시작 > 이름 포함 > 부서 > 담당업무 > 직위 순입니다. `이름·부서` 칩을 고르면 이름과 부서만 봅니다.
4. 문장으로 입력해서(예: "장학금 담당자가 누구야") 아무것도 안 걸리면 조사와 불용어를 뗀 키워드로 다시 찾습니다.
5. 걸린 구간(`matchRanges`)은 카드에서 강조합니다. 초성 검색이면 이름의 해당 초성 구간, 번호 검색이면 숫자가 걸린 구간입니다.

</details>

<details>
<summary>✨ <b>AI 안내</b> <sub><code>services/ai_chat_service.dart</code>, <code>widgets/ai_exchange.dart</code>, <code>worker/</code></sub></summary>

1. ✨를 누르면 질문(300자까지)에서 키워드를 뽑고(`extractKeywords`), 키워드마다 로컬 DB를 검색해서 관련도 순 상위 15명을 고릅니다.
2. 고른 교직원(이름, 부서, 직함, 담당업무, 전화, 이메일, 위치)과 질문, 최근 대화 6개를 서버로 보냅니다. **휴대폰 번호는 보내지 않고**, 학생이면 직위를 빼고 위치는 건물명만 보냅니다.
3. 서버는 "검색 결과에 있는 내용만 근거로 답하고, 없는 이름·번호는 지어내지 않는다"는 지시와 함께 모델을 부릅니다. 검색 결과 안의 문장은 자료로만 다룹니다.
4. 답은 입력창 바로 아래에 최신 질문이 위로 오게 쌓이고, 근거 교직원 최대 3명이 카드로 붙습니다.
5. 실패하면 예외를 던지지 않고 로컬 검색 결과로 만든 안내를 보여 줍니다. 이유는 응답 시간 초과(20초), 네트워크 없음, 요청 과다(429), 오늘 사용량 소진(`quota_exceeded`), 서버 없음(404), 서버 오류(5xx)가 있습니다. 실패한 질문은 대화 기록에 남기지 않습니다.
6. 대화는 찾기 화면을 새로 열 때, ☰ → `AI 대화 지우기`, 로그아웃 때 비웁니다.

</details>

<details>
<summary>📞 <b>걸려온 학교 번호 알림 (BETA)</b> <sub><code>CallReceiver.kt</code>, <code>CallOverlay.kt</code>, <code>widgets/caller_id_card.dart</code></sub></summary>

1. 앱을 켤 때 Flutter가 DB 파일 경로와 신분(학생/교직원)을 네이티브에 저장해 둡니다(`saveDbPath`, `saveUserRole`). 앱이 꺼져 있어도 네이티브가 같은 DB를 직접 읽습니다.
2. 전화가 오면 `CallReceiver`가 BETA 스위치를 확인하고, 켜져 있으면 `CallOverlay.show`를 바로 부릅니다. 앱이 꺼져 있을 때는 안드로이드가 포그라운드 서비스 시작을 막아서(Android 12+) 서비스를 쓰지 않습니다.
3. 번호로 DB를 찾습니다. 휴대폰 일치 > 교내전화 일치 > 내선 순으로 가장 정확한 결과만 쓰고, 비어 있거나 `0000`인 번호, 4자리 미만 번호는 건너뜁니다(모든 전화와 매칭되던 오탐 수정).
4. 교직원 번호일 때만 표시합니다. "다른 앱 위에 표시"가 허용돼 있으면 기본 수신 화면을 덮는 전체 화면(이름·부서·위치, `받기`·`거절`, `닫고 기본 전화 화면 보기`)을 띄우고, 아니면 헤드업 알림만 띄웁니다. 같은 번호를 여러 명이 쓰면 사람 대신 부서와 인원으로 보여 줍니다. 학생이면 직위를 빼고 위치는 건물명만(`공학관 301호` → `공학관`) 보여 줍니다.
5. 전화를 받거나 끊기면 화면과 알림을 내립니다.
6. BETA 카드는 전화, 통화 기록, 알림 권한과 배터리 최적화 예외, 화면 위 표시 상태를 보여 주고, 빠진 권한은 `권한 허용`으로 요청합니다. 설정 앱에서 바꾸고 돌아오면 상태를 다시 읽습니다. `수신 화면 미리보기`는 실제 수신과 같은 경로로 예시 정보와 가상번호를 띄웁니다.

> [!NOTE]
> iOS는 걸려온 번호를 앱이 읽을 수 없어서 자동 식별이 안 됩니다. iOS 빌드에서는 ☰ → `전화번호로 조회`에 번호를 직접 넣으면 알림으로 알려 줍니다.

</details>

<details>
<summary>🗄️ <b>교직원 데이터 갱신</b> <sub><code>db/database_helper.dart</code></sub></summary>

1. 처음 실행하면 `assets/staff_db.json`을 읽어 `staff` 테이블을 채우고 `name`, `department`, `user_id`에 인덱스를 만듭니다.
2. 실행할 때마다 번들된 JSON의 해시(FNV-1a 32비트)를 `meta` 테이블의 값과 비교해서, 다르면 `staff`를 다시 채웁니다. 앱 업데이트로 새 데이터가 들어오면 기존 설치자에게도 반영됩니다.
3. 즐겨찾기와 최근 기록은 `staff.id`가 아니라 `user_id`로 저장하기 때문에 다시 채워도 남습니다. 지금 데이터에 없는 사람은 목록에서 빠집니다.
4. DB 버전 1 → 2에서 즐겨찾기를 `user_id`로 옮기고 `meta`를 추가했고, 2 → 3에서 `recents`를 추가했습니다.

</details>

<details>
<summary>🔔 <b>업데이트 확인</b> <sub><code>services/update_service.dart</code>, <code>home_screen.dart</code></sub></summary>

- 앱을 켤 때 GitHub `releases/latest`의 태그(앞의 `v`는 뗌)를 현재 버전과 점(.)으로 나눠 앞자리부터 비교합니다.
- 새 버전이면 릴리스 노트 앞부분(200자)과 함께 안내 창이 뜨고, `지금 업데이트`를 누르면 릴리스에 붙은 `.apk`를 바로 받습니다(없으면 릴리스 페이지).
- ☰ → `업데이트 확인`이나 설정에서 직접 확인하면, 최신일 때 `최신 버전을 사용 중입니다` 토스트가 뜹니다.

</details>

---

## 주요 함수

> [!TIP]
> 파일명을 클릭하면 함수 표가 펼쳐집니다.

<details>
<summary>📄 <b><code>utils/staff_search.dart</code>: 검색</b></summary>

| 함수 | 설명 |
|---|---|
| `searchLocal(all, query, {namesOnly, includeTitle, includeCell})` | 메모리 목록에서 관련도 순으로 찾음. 번호·초성·일반 검색을 자동으로 고름 |
| `toChoseong(text)` | 글자열의 초성만 뽑음. `김민호` → `ㄱㅁㅎ` |
| `isChoseongQuery(q)` / `isPhoneQuery(q)` | 초성 검색인지 / 전화번호 검색인지 |
| `matchRanges(text, query)` | 강조 표시할 구간 (시작, 끝) |
| `groupByDepartment(all)` | 부서별로 묶음. 부서 이름순, 부서 안은 이름순, 빈 부서는 `기타` |

</details>

<details>
<summary>📄 <b><code>services/ai_chat_service.dart</code>: AI 안내</b></summary>

| 함수 | 설명 |
|---|---|
| `sendMessage(question)` | 키워드 검색 → 서버 호출 → `AiAnswer(text, staff, fromAi)`. 실패해도 예외 없이 로컬 안내를 돌려줌 |
| `findRelevantStaff(question)` | 질문 키워드로 찾은 교직원을 `rankStaff`로 정렬해 15명까지 |
| `extractKeywords(question)` | 조사·불용어를 뗀 검색 키워드 |
| `staffToContext(staff)` | 서버로 보낼 교직원 정보. 신분에 따라 거르고 휴대폰은 뺌 |
| `fallbackReply(reason, staff)` | 서버를 못 쓸 때 보여 줄 안내문 |
| `resetChat()` | 대화 기록 비우기 |

</details>

<details>
<summary>📄 <b><code>db/database_helper.dart</code>: 저장소</b></summary>

| 함수 | 설명 |
|---|---|
| `database` | DB를 한 번만 열고, 생성·업그레이드·시드 동기화까지 처리 |
| `getAllStaff()` / `searchStaff(keyword, mode, {includeTitle})` | 전체 / 키워드 검색(mode 0: 전체 필드, 1: 이름·부서) |
| `getFavoriteUserIds()` / `getFavoriteStaff()` | 즐겨찾기 id / 즐겨찾기한 교직원(이름순) |
| `addFavorite(userId)` / `removeFavorite(userId)` | 즐겨찾기 추가 / 해제 |
| `addRecent(userId, {keep})` / `getRecentStaff({limit})` / `clearRecents()` | 최근 본 교직원 기록(20명 유지) / 조회 / 비우기 |

</details>

<details>
<summary>📄 <b>네이티브(Kotlin)</b></summary>

| 클래스 / 함수 | 설명 |
|---|---|
| `CallReceiver.onReceive` | 전화 상태 변화 수신. 스위치가 켜져 있을 때만 화면을 띄우고 내림 |
| `CallOverlay.queryStaff(number, isStaff)` | 번호로 DB 조회. 휴대폰 > 교내전화 > 내선 순, 공용 번호 판별 |
| `CallOverlay.showOverlay` / `showCallerNotification` | 수신 화면 위 전체 화면과 헤드업 알림. 신분에 따라 직위·위치를 거름 |
| `MainActivity.callerIdStatus()` | BETA 기능에 필요한 권한과 스위치 상태 |
| `MainActivity` 채널 메서드 | `saveDbPath` `saveUserRole` `getCallerIdStatus` `setCallerIdEnabled` `previewCallerId` `checkCallLogPermission` `requestCallLogPermission` `requestBatteryExemption` |

</details>

---

## AI 서버 (`worker/`)

- `POST /chat`: 본문 `{ "question": "...", "history": [...], "staff": [...] }`(32KB 이하)를 받아 `{ "reply": "..." }`를 돌려줍니다. 질문은 300자, 대화는 6개, 교직원은 15명, 답변은 1,500자까지입니다.
- `GET /health`: 상태 확인
- 오류는 `{ "error": 코드 }` 모양입니다. `body_too_large`, `bad_json`, `bad_request`, `empty_question`, `question_too_long`, `rate_limited`(분당 6회), `quota_exceeded`(Workers AI 하루 무료 한도 소진), `ai_failed`, `bad_model_output`, `not_found`, `method_not_allowed`, `internal_error`가 있고, 앱은 이 코드를 보고 안내 문구를 고릅니다.
- 교직원 DB는 앱 안에만 있습니다. 서버는 앱이 골라 보낸 검색 결과와 질문, 최근 대화만 받고 저장하지 않습니다. 앱은 `X-Device-Id`에 설치마다 만든 임의의 id(횟수 제한용)만 넣습니다.

---

## 데이터 저장

| 위치 | 내용 | 쓰는 쪽 |
|---|---|---|
| `du_who.db` → `staff` | 교직원 정보(이름, 부서, 직위, 담당업무, 전화, 휴대폰, 메일, 위치) | Flutter가 채우고, 네이티브는 읽기만 |
| `du_who.db` → `favorites` | 즐겨찾기 `user_id` | Flutter |
| `du_who.db` → `recents` | 최근 본 교직원 `user_id`와 시각(ms) | Flutter |
| `du_who.db` → `meta` | 시드 JSON 해시 등 | Flutter |
| `theme_mode.txt`, `device_id.txt`, `session.json` | 테마, AI 횟수 제한용 임의 id, 로그인 세션(로그인을 켰을 때) | Flutter |
| SharedPreferences `du_who_prefs` | `db_path`, `is_staff`, `caller_id_enabled` | Flutter가 채널로 저장, 네이티브가 읽음 |

- 앱이 꺼져 있어도 전화가 오면 알려야 해서, 네이티브는 Flutter 없이 SQLite 파일을 직접 엽니다. 그래서 DB 경로와 신분을 미리 넘겨 둡니다.

---

## 신분별 정보 노출

| 항목 | 학생 | 교직원 |
|---|---|---|
| 이름 · 부서 · 담당업무 · 교내전화 · 메일 | 표시 | 표시 |
| 직위 | 비표시(직위로 검색도 안 됨) | 표시 |
| 휴대폰 | 비표시(휴대폰 번호로 검색도 안 됨) | 표시 |
| 위치 | 건물명만 | 전체 |

검색, 상세 시트, AI로 보내는 자료, 수신 전화 알림이 모두 같은 기준을 따릅니다. 지금은 로그인을 꺼 둬서(`kLoginEnabled = false`) 모두 교직원 기준으로 보입니다.

---

## 권한

| 권한 | 용도 |
|---|---|
| `READ_PHONE_STATE` | 전화가 오는지 감지 |
| `READ_CALL_LOG` | 걸려온 번호 읽기(안드로이드 9 이상) |
| `POST_NOTIFICATIONS` | 발신자 알림(안드로이드 13 이상) |
| `SYSTEM_ALERT_WINDOW` | 수신 화면 위에 교직원 정보를 크게 표시(선택, 없으면 알림만) |
| `ANSWER_PHONE_CALLS` | 그 화면의 `받기`·`거절` 버튼 |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | 배터리 절약 때문에 알림이 늦거나 안 뜨는 것을 막음(선택) |
| `INTERNET` | AI 안내, 업데이트 확인 |

- 전화·통화 기록 권한은 걸려온 학교 번호 알림에만 씁니다. 통화 기록을 저장하거나 서버로 보내지 않습니다.

---

## 개발팀 (6조)

| 학번 | 이름 |
|---|---|
| 22124206 | 김민호 |
| 22124073 | 김기룡 |
| 22124248 | 박기민 |
| 22124549 | 신진우 |
