# BAG BOSS · 막차 — iOS 네이티브 앱 (Claude Code 작업 지침)

모든 답변 · 커밋 메시지 · 코드 주석 · 문서는 **한국어**로 쓴다.

## 이 저장소는 무엇인가
픽셀 아트 자동 전투 게임 **BAG BOSS · 막차**(뉴욕 지하철 · 서류가방 격자 · 콤보 경로 · 엘리베이터 타워)의 **완전 네이티브 iOS 앱**이다.
**`native/`가 정본 제품이다.** 웹판(`web/index.html`)은 데이터 · 아트를 추출해 온 옛 원천일 뿐이고, 웹 호환 · 웹 대조는 더 이상 설계 기준이 아니다.

- 플랫폼: iOS 17+ · 아이폰 전용 · 세로 고정 · Swift 6(엄격 동시성)
- 앱: `native/App/project.yml`(XcodeGen, 스킴 **BagBossNative**, 번들 `com.dijeong.bagboss.native`) — `.xcodeproj`는 커밋하지 않는다
- 렌더: Metal 커스텀(G-버퍼 · 팔레트 램프 · 노멀 조명 · 후처리) · 소리: AVAudioEngine 합성 · 진동: Core Haptics · 화면: SwiftUI
- 수익: 양복 스킨 인앱 결제(StoreKit 2, `Features/FeatureConfig.json`) · Game Center 리더보드
- 배포: TestFlight(빌드 번호 = `project.yml`의 `CURRENT_PROJECT_VERSION`)

## 폴더
```
native/Package.swift      BagBossKit — 모듈 경계를 타깃 의존성으로 강제(아래로만 의존)
                          Core ← Content ← Anim ← Sim ← Presentation ← (Render · Audio · Haptics · UI) / Persistence
native/Sources/BBCore           고정 스텝 시계 · 난수 · 이벤트 버퍼
native/Sources/BBContent        Resources/Generated(생성물) · NativePalette · 번역 · 글꼴
native/Sources/BBAnim           리그 · 포즈 · 시퀀스 · IK · 강화 층(Enhance/) · 네이티브 동작 포즈(Models/Native*Poses.swift)
native/Sources/BBSim            규칙(Bag · Core · World — 무도장 · 네이티브 기술 World+Native*.swift)
native/Sources/BBPresentation   Director(StageDirector · 카메라 · 타격감 · BeachFx · SnowFx · 소리 신호) · Scene(장면 구성 · 무대 아트) · HUD
native/Sources/BBRender         FrameAssembly · FrameRenderer · Resources/Shaders.metal
native/Sources/BBAudio          합성 효과음 · 음악 · 환경음(TrainAmbience) · Resources/Hits(녹음 타격음)
native/Sources/BBHaptics · BBPersistence · BBUI
native/Tests/                   모듈별 테스트 · *StripTests = 눈으로 보는 띠 그림(BB_DUMP=1) · Fixtures
native/App/BagBossNative/       Flow(타이틀 · 메뉴 · 도감 · 결과 · DebugLaunch) · Game(세션 · 무대 뷰 · 패드 · GameBridges) · Features(스킨 · Game Center · 무도장 패널 · 포즈 편집)
tools/js/extract/               추출기(node) — strings.mjs(번역: strings-extra.json 이 원본) 등 → Generated/
docs/                           06 아키텍처 · 07 동작 점검 · 08 공방 · 09 UI 배치 · 10 눈 승강장 · 11 타격감 · 12 해변 도장
ios/ · web/ · tools/*.py · tools/test/   옛 1단계 웹 셸(docs/01~05) — 참고용, 갱신하지 않는다
```

## 명령
```bash
cd native && swift test                                   # 전체 테스트(macOS 에서 바로)
cd native && swift test --filter <스위트>                  # 일부
cd native && BB_DUMP=1 swift test --filter <…StripTests>   # 띠 그림 → tools/js/out/stage/ 등(커밋 안 함)
cd native/App && xcodegen generate                        # 앱 프로젝트(파일을 더하거나 뺐을 때도)
xcodebuild -project native/App/BagBossNative.xcodeproj -scheme BagBossNative -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
cd tools/js && node extract/strings.mjs                   # 번역 다시 굽기
```
디버그 실행 인자(시뮬레이터 점검): `native/App/BagBossNative/Flow/DebugLaunch.swift` 머리말 — 예 `-stage beachdojo|beachdusk|beachnight|snow|snowdojo` · `-dojo [적]` · `-dojomove <id> [초]` · `-screen <이름>` · `-devhud`.

## 작업 원칙
1. **저장 키는 지우거나 이름을 바꾸지 않는다**(플레이어 기록 · 이어 하기). 새 키 · 새 값을 더하는 것은 된다.
2. `native/Sources/BBContent/Resources/Generated/` 는 생성물이다 — 손으로 고치지 않는다. 번역은 `tools/js/extract/strings-extra.json` 을 고치고 `node extract/strings.mjs` 로 굽는다.
   추출 데이터와 다른 값이 필요하면 네이티브 쪽 덮어쓰기(코드 · NativePalette 빈 줄 등)로 한다.
3. BBSim 은 UIKit · Metal · AVFoundation 을 import 하지 않는다. 규칙은 이벤트만 내고, 난수는 주입받은 것만, 시간은 틱만 쓴다.
4. 데이터 픽셀(아틀라스 · 팔레트)은 이미지 코덱(PNG · ImageIO · MTKTextureLoader)을 거치지 않는다 — iOS 가 알파 0 픽셀의 RGB 를 지운다.
5. 셰이더 GL↔Metal 함정: 렌더 타깃 위아래 · flat 값 기준 정점(GL=마지막) · 깊이 범위 · mod — `Shaders.metal` 머리말 참고.
   셰이더를 고치면 전체 테스트(렌더 테스트 포함)를 돌린다.
6. 그림 · 연출 변경은 띠 그림(StripTests)으로 눈으로 확인하고, 성능은 추측하지 말고 측정값(테스트 출력 · Instruments)으로 말한다.
7. 새 기능에는 테스트를 더하고, 큰 연출 · 무대는 `docs/` 에 설계 문서를 남긴다.
8. 앱 키(App Store Connect API 키 · 업로드 plist)는 저장소에 넣지 않는다 — **공개 저장소**다.

## 알려진 사실(헛걸음 방지)
- 아카이브는 반드시 스킴 **BagBossNative**(BagBossKit 스킴으로 아카이브하면 내보내기가 실패한다).
- 시뮬레이터에서 오디오 RPC 타임아웃(AudioEngine.prewarmOutput)으로 죽으면 코드 문제가 아니다 — 시뮬레이터를 재부팅한다.
- 무대 픽셀 층: 시차 p 인 층의 장면 x = 층 x + (1−p)·camX. GL z 는 작을수록 앞. 깊이 d 0.62 이상은 먼 흐림에 들어간다.
