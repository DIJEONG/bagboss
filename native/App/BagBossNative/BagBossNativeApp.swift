import SwiftUI
import BBContent
import BBAudio

// 조립 지점(composition root). 첫 탭 '게임'(N4 통합 — 지하철 한 판), 나머지는 단계 점검 화면(데이터 · 렌더 · 캐릭터 · 가방).
@main
struct BagBossNativeApp: App {
    /// 실행 인자: `-game`(기본) · `-render` · `-lab` · `-bag` · `-data` 이면 그 탭으로 시작(시뮬레이터 · UI 테스트 자동화용)
    /// DEBUG: `-autostart` 면 게임 탭에서 바로 새 판(씨앗 2026)
    @State private var tab: Int = {
        let a = ProcessInfo.processInfo.arguments
        if a.contains("-bag") { return 4 }
        if a.contains("-lab") { return 3 }
        if a.contains("-render") { return 2 }
        if a.contains("-data") { return 1 }
        return 0
    }()

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("-noaudio") { AudioEngine.deviceOff = true }   // 개발용: 맥 오디오가 멈춘 시뮬레이터에서 화면만 점검
        #endif
        BootTrace.mark("App.init")
        GameAssets.shared.start()   // 무거운 준비(데이터 · 아틀라스 · 셰이더 · HUD 그림 · 소리 표)를 뒤 스레드에서 바로 시작
        BootTrace.measure("글꼴 등록") { GameFonts.register() }
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                GameRootView().tabItem { Label("게임", systemImage: "tram") }.tag(0)
                BootCheckView().tabItem { Label("데이터", systemImage: "shippingbox") }.tag(1)
                NavigationStack { RenderViewer() }.tabItem { Label("렌더", systemImage: "photo") }.tag(2)
                NavigationStack { CharacterLab() }.tabItem { Label("캐릭터", systemImage: "figure.walk") }.tag(3)
                NavigationStack { BagLab() }.tabItem { Label("가방", systemImage: "briefcase") }.tag(4)
            }
            .preferredColorScheme(.dark)
        }
    }
}
