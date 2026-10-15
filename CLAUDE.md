# BAG BOSS · 막차 — iOS 네이티브 전환 (Claude Code 작업 지침)

모든 답변 · 커밋 메시지 · 코드 주석은 **한국어**로 쓴다.

## 이 저장소는 무엇인가
픽셀 아트 자동 전투 게임 **BAG BOSS · 막차**(뉴욕 지하철 · 서류가방 격자 · 콤보 경로 · 엘리베이터 타워)를
iOS 앱으로 옮기는 작업 공간이다. 게임 본체는 WebGL2 단일 HTML(`web/index.html`, 약 1.5MB)이고,
이번 단계는 그 HTML을 **고치지 않고** 네이티브 셸(WKWebView)에 올려 실기기에서 측정하는 것이 목표다.

- 플랫폼: iOS (아이폰 전용 · 세로 고정) · 최소 iOS 16.0
- 셸: UIKit + WKWebView, `app://game/` 사용자 스킴으로 번들 안 `Web/`을 서빙
- 프로젝트 생성: XcodeGen(`ios/project.yml`) — `.xcodeproj`는 커밋하지 않는다
- 수익 모델(검토 중): 주인공 양복 스킨 인앱 결제 + 광고 → 2단계 이후 브리지로 연결

## 지금 단계
**1단계: 웹 코어 + 네이티브 셸 → 실기기 측정.** 측정 결과로 2단계 방향을 정한다.
순서와 판정 기준은 `docs/01-전환-로드맵.md`, 측정 방법은 `docs/04-실기기-측정.md`.
**완전 네이티브 전환(목표 구조 · 이식 단계 N0~N6)은 `docs/06-네이티브-아키텍처.md`** — 웹판은 그 기준선(오라클)이자 데이터 · 아트 추출 원천이다.

## 폴더
```
web/index.html            게임 원본(단일 HTML). 클라우드 작업 세션에서 계속 고쳐 오는 '정본'
web/app/                  앱 전용 보조 파일: bridge.js(주입) · app.css · fonts.css · fonts/
ios/project.yml           XcodeGen 명세 (팀 ID · 번들 ID는 여기서만 바꾼다)
ios/BagBoss/App/          AppDelegate · SceneDelegate · AppConfig
ios/BagBoss/Shell/        GameViewController · WebViewFactory · AppSchemeHandler
ios/BagBoss/Bridge/       BridgeRouter · SaveStore · Haptics · AudioSessionConfig
ios/BagBoss/Perf/         PerfMonitor(CSV 기록) · PerfHUD(오버레이)
ios/BagBoss/Web/          ← 생성물. tools/build_web.py 가 web/에서 만든다(직접 고치지 않는다)
tools/build_web.py        web/ → ios/BagBoss/Web/ (구글 폰트 링크 제거 · viewport · 앱 CSS 링크)
tools/split_web.py        1.5단계용 조각 분리/합치기(원본과 바이트 동일 보장) · 경계표 tools/modules.json
web/src/                  split 결과 조각 51개 + _head/_tail · ORDER.txt (정본 이전 여부는 미정 — 지금은 index.html에서 다시 만든다)
tools/js/deps_web.mjs     조각 의존성 지도(acorn + eslint-scope) → docs/05-의존성-지도.md · docs/deps/deps.json
tools/js/extract/         웹 → 네이티브 추출(아틀라스 · 데이터 · 번역 · 비교 픽스처). 헤드리스 Chromium 으로 게임을 띄워 '실행된 값'을 읽는다
native/                   완전 네이티브(docs/06): Package.swift(BagBossKit 모듈 타깃) · Sources/BB* · Tests · App/project.yml(BagBossNative)
tools/test/run_all.py     회귀 테스트 묶음(Playwright) · bridge_test.py = 셸 흉내 브리지 검사
docs/                     로드맵 · 모듈 분리 계획 · 브리지 명세 · 실기기 측정
```

## 명령
```bash
python3 tools/build_web.py                 # 웹 코어 → 앱 번들 폴더 (web/ 를 바꿨으면 항상)
python3 tools/build_web.py --check         # 생성물이 최신인지
cd ios && xcodegen generate                # 프로젝트 생성/갱신 (파일을 더하거나 뺐을 때도)
xcodebuild -project ios/BagBoss.xcodeproj -scheme BagBoss -destination 'generic/platform=iOS Simulator' build
python3 tools/test/run_all.py quick        # 빠른 회귀(약 1분) · 전체는 인자 없이(6~10분)
python3 tools/split_web.py verify          # 조각 경계표가 현재 원본과 맞는지
python3 tools/split_web.py split && node tools/js/deps_web.mjs   # 조각 다시 만들고 의존성 지도 갱신
cd tools/js && npm run extract             # 네이티브 생성물 전부(웹 원본이 바뀌면 항상) · npm run extract:check
cd native && swift test                    # 네이티브 코어 테스트(macOS 에서 바로)
cd native/App && xcodegen generate         # 네이티브 앱 프로젝트
```
테스트 준비(처음 한 번): `pip3 install playwright && python3 -m playwright install chromium` · 분석 · 추출 도구: `cd tools/js && npm install && npx playwright install chromium`

## 작업 원칙
1. **1단계에서는 `web/index.html`을 고치지 않는다.** 필요한 것은 `web/app/bridge.js`(주입 스크립트)나 네이티브에서 해결한다.
   게임 쪽 변경이 꼭 필요하면 직접 고치지 말고 무엇을 왜 바꿔야 하는지 메모로 남긴다 — 게임 정본은 클라우드 작업 세션에서 고쳐 내려온다.
2. 새 게임 버전을 받으면: `web/index.html` 교체 → `build_web.py` → `run_all.py quick` → `split_web.py verify`(경계가 어긋나면 `--suggest`로 표 갱신).
3. 게임 코드 거의 전부가 즉시 실행 함수 하나 안에 있어 전역(GS · SND …)을 밖에서 읽을 수 없다.
   바깥 창구는 개발 훅 `window.__dotlab` 하나뿐이고 bridge.js도 그것만 쓴다. 정식 호스트 API는 1.5단계 과제(docs/02).
4. 브리지 메시지를 더하거나 바꾸면 **세 곳을 같이** 고친다: `web/app/bridge.js` · `ios/BagBoss/Bridge/BridgeRouter.swift` · `docs/03-브리지-명세.md`, 그리고 `tools/test/bridge_test.py`에 검사 한 줄.
5. Swift는 Swift 5 언어 모드(`SWIFT_VERSION 5.0` · `SWIFT_STRICT_CONCURRENCY minimal`), Xcode 16 이상 SDK 기준. UIKit을 만지는 클래스는 `@MainActor`.
   WebKit 대리자 메서드의 클로저 타입은 **SDK 선언과 똑같이**(`@escaping @MainActor @Sendable …`) 쓴다 — 다르면 엄격한 동시성 설정에서 경고 없이 안 불린다.
   서드파티 의존성은 1단계에 넣지 않는다. 이 Swift 코드는 리눅스에서 작성 · 정적 검토만 했고 아직 한 번도 컴파일되지 않았다 → 첫 빌드 경고 · 오류부터 정리.
6. 저장 데이터를 지우거나 키 이름을 바꾸는 변경은 하지 않는다(플레이어 기록 · 이어 하기). 키 목록은 docs/03 참고.
7. 측정 수치는 추측하지 말고 CSV(Documents/perf/)와 Instruments 결과로 말한다.

## 네이티브 작업 원칙 (docs/06)
- `native/Sources/BBContent/Resources/Generated/` 는 생성물이다 — 직접 고치지 말고 추출기를 고쳐 다시 굽는다.
- BBSim 은 UIKit · Metal · AVFoundation 을 import 하지 않는다. 규칙은 이벤트만 내고, 난수는 주입받은 것만, 시간은 틱만 쓴다.
- 데이터 픽셀(아틀라스 · 팔레트)은 이미지 코덱(PNG · ImageIO · MTKTextureLoader)을 거치지 않는다 — iOS 가 알파 0 픽셀의 RGB 를 지운다.
- 셰이더(native/Sources/BBRender/Resources/Shaders.metal)는 웹 GLSL 1:1 이식이다. 고치면 `swift test --filter WebParityTests`(웹 캡처 단계별 대조)를 돌린다.
  GL↔Metal 함정: 렌더 타깃 위아래 · flat 값 기준 정점(GL=마지막) · 깊이 범위 · mod — 셰이더 머리말 참고.
- 웹 프레임을 새로 찍으려면 `node tools/js/extract/frames.mjs [장면]`(스냅숏이라 찍을 때마다 장면이 달라진다 → 다시 찍으면 커밋). 캐릭터는 `characters.mjs`.
- 인물 애니메이션(BBAnim)은 웹 1:1 이식 + 그 위 강화 층(Enhance/). 강화는 `MotionStyle` 로 켜고 끄며, **꺼진 상태가 웹 대조 기준**이다.
  강화는 보이는 층만 — 키 포즈 · 시퀀스 길이 · 큐 프레임(판정 타이밍)은 건드리지 않는다.
- 웹 동작과 맞추는 것이 기준: 이식한 함수는 `tools/js/extract/fixtures.mjs` 에 픽스처를 더하고 Swift 테스트로 대조한다.

## 알려진 사실(헛걸음 방지)
- iOS WebKit에는 `navigator.vibrate`가 없다 → bridge.js가 폴리필해 네이티브 햅틱으로 보낸다(게임의 `buzz()`가 그대로 동작).
- iOS에는 Impact · Arial Black 글꼴이 없다 → `web/app/fonts.css`가 Anton(OFL)을 같은 이름으로 묶는다(만화 효과음 글자).
- 원본 `<head>`의 구글 폰트(IBM Plex Sans KR · Silkscreen)는 엔진 실험실 UI 전용이라 앱 빌드에서 뺀다. 게임 글꼴 갈무리는 HTML 안에 base64로 있다.
- 게임은 `navigator.webdriver`가 아니면 자동으로 게임 모드로 들어간다(헤드리스 테스트에서는 버튼을 눌러 들어간다).
- WebGL 문맥 잃음 처리가 게임에 없다 → bridge.js가 `gl.lost`를 알리고 셸이 저장 후 다시 연다.
- `appMemMB`(HUD · CSV)는 앱 프로세스만이다. 게임은 WebContent 프로세스에서 돈다 → Safari 웹 인스펙터 · Instruments로 본다.
