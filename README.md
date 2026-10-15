# BAG BOSS · 막차 — iOS 시작 패키지 (1단계: 웹 코어 + 네이티브 셸)

게임 HTML(v4.64)을 그대로 WKWebView에 올린 아이폰 앱 골격입니다. 목표는 **실기기에서 돌려 보고 숫자로 다음 단계를 정하는 것**입니다.

## 맥에서 처음 실행하기
준비물: Xcode 16 이상 · Apple 계정(무료 계정도 내 기기 설치는 가능) · Homebrew

```bash
brew install xcodegen
cd bagboss-ios
python3 tools/build_web.py          # 웹 코어 → ios/BagBoss/Web (이미 들어 있지만, web/를 바꾸면 다시)
cd ios && xcodegen generate && open BagBoss.xcodeproj
```
1. Xcode › BagBoss 타깃 › Signing & Capabilities에서 **Team** 선택 (또는 `ios/project.yml`의 `DEVELOPMENT_TEAM`에 팀 ID)
2. 번들 ID가 겹치면 `ios/project.yml`의 `PRODUCT_BUNDLE_IDENTIFIER` 변경 후 `xcodegen generate`
3. 아이폰을 연결하고 실행(⌘R). 처음엔 기기에서 *설정 › 일반 › VPN 및 기기 관리*에서 개발자 신뢰가 필요할 수 있습니다.

## 들어 있는 것
| 영역 | 내용 |
|---|---|
| 셸 | 전체 화면 · 세로 고정 · 상태 막대/홈 인디케이터 숨김 · 하단 제스처 지연 · 확대/고무줄 스크롤 끔 |
| 웹 코어 | `app://game/`으로 번들 서빙 · 완전 오프라인 · 원본 HTML 무수정 |
| 저장 | localStorage `dotlab*` 키를 앱 파일에 미러 → 웹 저장소가 비면 자동 복원 |
| 햅틱 | 게임의 진동 호출(`navigator.vibrate`)을 아이폰 햅틱으로 연결 |
| 수명주기 | 앱이 가려지면 메뉴로 일시정지 + 저장 · 돌아오면 오디오 재개 · 웹 프로세스/WebGL이 죽으면 저장 후 자동 복구 |
| 측정 | 성능 HUD(세 손가락 두 번 탭) · 1초 단위 CSV(파일 앱 › BAG BOSS › perf) · Safari 웹 인스펙터 연결(디버그) |
| 테스트 | Playwright 회귀 10종 + 셸 흉내 브리지 검사 |

## Claude Code로 이어 가기
이 폴더에서 Claude Code를 열면 `CLAUDE.md`를 먼저 읽습니다. 첫 요청 예시:
> "README대로 빌드해서 시뮬레이터로 띄워 보고, docs/04 측정 체크리스트 1번부터 같이 진행하자"

문서: `docs/01-전환-로드맵.md` · `docs/02-모듈-분리-계획.md` · `docs/03-브리지-명세.md` · `docs/04-실기기-측정.md`

## 라이선스 메모
`web/app/fonts/anton-latin-400-normal.woff2` — Anton, SIL Open Font License 1.1 (`OFL-Anton.txt`). 앱에 함께 배포 가능.
