# BAG BOSS · 막차 — iOS 네이티브 앱

픽셀 아트 자동 전투 게임 **BAG BOSS · 막차**(뉴욕 지하철 · 서류가방 격자 · 콤보 경로 · 엘리베이터 타워)의 **완전 네이티브 iOS 앱**입니다.
Swift 6 · Metal 커스텀 렌더러 · AVAudioEngine 합성 · Core Haptics · SwiftUI로 만들었고, TestFlight로 배포하고 있습니다.

> 처음에는 웹판(WebGL2 단일 HTML)을 WKWebView에 올린 셸로 시작했습니다(`ios/` · `web/`).
> 지금은 **`native/`가 정본 제품**이고, 웹판은 데이터 · 아트를 추출해 온 원천으로만 남아 있습니다.

## 맥에서 실행하기
준비물: Xcode 26 이상(지금 27.0으로 빌드) · Homebrew · `brew install xcodegen`

```bash
cd native && swift test                  # 코어 테스트(macOS에서 바로 — 시뮬레이터 필요 없음)
cd native/App && xcodegen generate && open BagBossNative.xcodeproj   # 앱(스킴 BagBossNative) → ⌘R
```
- 팀 ID · 번들 ID(`com.dijeong.bagboss.native`) · 빌드 번호는 `native/App/project.yml`에서만 바꿉니다. `.xcodeproj`는 커밋하지 않습니다.
- Xcode에서 실행하면 로컬 StoreKit 구성(`StoreKit/BagBossSkins.storekit`)으로 스킨 결제를 시험합니다.
- 디버그 빌드는 실행 인자로 화면을 바로 엽니다(`native/App/BagBossNative/Flow/DebugLaunch.swift` 머리말).
  예: `-stage beachdojo` · `-stage snow` · `-dojo nv_spar` · `-screen menu-tower` · `-dojomove nv_rise 5`

## 구조
```
native/Package.swift      로컬 패키지 BagBossKit — 모듈 경계를 타깃 의존성으로 강제
  Sources/BBCore           고정 스텝 시계 · 난수 · 이벤트 버퍼
  Sources/BBContent        추출 데이터(Resources/Generated — 생성물) · 팔레트 · 번역 · 글꼴
  Sources/BBAnim           인물 리그 · 포즈 · 시퀀스 · IK · 네이티브 동작(Models/)
  Sources/BBSim            게임 규칙(60Hz · 이벤트만 낸다 · UIKit/Metal/AVFoundation 금지)
  Sources/BBPresentation   연출(무대 · 카메라 · 타격감 · 해변/눈 효과 · HUD · 소리 신호)
  Sources/BBRender         Metal 렌더러(G-버퍼 · 팔레트 램프 · 노멀 조명 · 후처리) · Resources/Shaders.metal
  Sources/BBAudio          합성 효과음 · 음악 · 환경음 · 녹음 타격음
  Sources/BBHaptics        Core Haptics 계획 · 재생
  Sources/BBPersistence    저장(판 · 메타 · 설정 · 구매) — 키는 지우거나 이름을 바꾸지 않는다
  Sources/BBUI             가방 격자 UI
  Tests/                   모듈별 테스트 + Fixtures(웹 추출 대조값)
native/App/               앱 타깃(xcodegen) — Flow(타이틀 · 메뉴 · 도감 · 결과) · Game(세션 · 무대 뷰 · 패드) · Features(스킨 · Game Center · 무도장 패널)
docs/                     설계 문서(아래)
tools/js/                 추출 도구(node) — 번역 · 데이터 · 아틀라스를 Generated/ 로 굽는다
ios/ · web/ · tools/*.py  옛 1단계(웹 셸) — 참고용, 더 이상 갱신하지 않음
```

## 자주 쓰는 명령
```bash
cd native && swift test                               # 전체 테스트
cd native && swift test --filter BeachFxTests          # 일부만
cd native && BB_DUMP=1 swift test --filter BeachStripTests   # 눈으로 보는 띠 그림 → tools/js/out/stage/
cd tools/js && node extract/strings.mjs               # 번역 다시 굽기(원본: extract/strings-extra.json)
```

## 문서
| 문서 | 내용 |
|---|---|
| `docs/06-네이티브-아키텍처.md` | 목표 구조 · 모듈 경계 · 이식 단계 |
| `docs/07-동작-점검.md` | 동작 점검 · 내선 연결 조준 |
| `docs/08-공방-설계.md` | 공방(막기 → 흔들기 → 무너뜨리기) |
| `docs/09-UI-배치.md` | 게임 화면 배치(무대 우선 + 바텀시트 가방) |
| `docs/10-눈-스테이지.md` | 7호선 눈 승강장 |
| `docs/11-타격감.md` | KO 마무리 · 펀치인 · 발놀림 먼지 · 인물 가독성 |
| `docs/12-해변-도장.md` | 코니아일랜드 해변 도장(오후 · 노을 · 밤) |
| `docs/01~05` | 옛 웹 셸 단계 기록(로드맵 · 모듈 분리 · 브리지 · 실기기 측정 · 의존성 지도) |

## 라이선스 메모
Anton 글꼴 — SIL Open Font License 1.1 (`web/app/fonts/OFL-Anton.txt`). 앱에 함께 배포 가능.
