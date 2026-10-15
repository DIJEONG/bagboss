import Foundation

/// 앱 전역 설정. 웹 쪽에는 window.__BAGBOSS_CFG__ 로 그대로 넘어간다(bridge.js의 CFG).
struct AppConfig {
    var debug: Bool
    var showHUD: Bool          // 성능 HUD를 처음부터 보일지(세 손가락 두 번 탭으로 언제든 켜고 끔)
    var perf: Bool             // 웹 프레임 측정
    var haptics: Bool          // navigator.vibrate → 네이티브 햅틱
    var saveMirror: Bool       // localStorage 'dotlab*' → 파일 백업

    static let current: AppConfig = {
        #if DEBUG
        return AppConfig(debug: true, showHUD: true, perf: true, haptics: true, saveMirror: true)
        #else
        return AppConfig(debug: false, showHUD: false, perf: true, haptics: true, saveMirror: true)
        #endif
    }()

    var webJSON: String {
        let dict: [String: Any] = ["debug": debug, "perf": perf, "haptics": haptics, "saveMirror": saveMirror, "keyPrefix": "dotlab"]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
