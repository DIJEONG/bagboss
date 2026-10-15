import Foundation
import CoreText

/// 게임 글꼴(tools/js/extract/fonts.mjs 가 웹에서 풀어 낸 TTF) 등록 · 이름.
/// UI 는 갈무리(Galmuri11 · Galmuri9 — 한글 2,350자 서브셋), 만화 효과음은 Anton(라틴 전용 → 한글은 갈무리로 대체).
public enum GameFonts {
    public static let ui = "Galmuri11-Regular"
    public static let uiBold = "Galmuri11-Bold"
    public static let small = "Galmuri9-Regular"
    public static let comic = "Anton-Regular"

    nonisolated(unsafe) private static var registered = false
    private static let lock = NSLock()

    /// 앱 시작 때 한 번 — 프로세스 범위로 등록한다(여러 번 불러도 안전)
    public static func register() {
        lock.lock(); defer { lock.unlock() }
        guard !registered else { return }
        registered = true
        let dir = GeneratedResources.url.appending(path: "fonts")
        for f in ["Galmuri11.ttf", "Galmuri11-Bold.ttf", "Galmuri9.ttf", "Anton-Regular.ttf"] {
            CTFontManagerRegisterFontsForURL(dir.appending(path: f) as CFURL, .process, nil)
        }
    }
}
