import Foundation
import WebKit

/// 웹 ⇄ 네이티브 메시지 라우터. 명세: docs/03-브리지-명세.md
///
/// 웹 → 네이티브: window.webkit.messageHandlers.bagboss.postMessage({ v:1, type, payload }) → Promise(reply)
/// 네이티브 → 웹: emit(type) → NativeBridge._native({ type }) 의 Promise 결과
///
/// 주의: WKUserContentController는 핸들러를 강하게 잡는다. 라우터는 웹뷰를 weak로만 든다(순환 참조 방지).
@MainActor
final class BridgeRouter: NSObject, WKScriptMessageHandlerWithReply {
    weak var webView: WKWebView?
    private let saves: SaveStore
    private let haptics: Haptics
    private let perf: PerfMonitor
    var onReady: (([String: Any]) -> Void)?
    /// WebGL 문맥을 잃었다 → 화면 주인(GameViewController)이 저장 후 다시 연다
    var onGLLost: (() -> Void)?

    init(saves: SaveStore, haptics: Haptics, perf: PerfMonitor) {
        self.saves = saves
        self.haptics = haptics
        self.perf = perf
        super.init()
    }

    // MARK: 웹 → 네이티브
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        guard let envelope = message.body as? [String: Any],
              let type = envelope["type"] as? String else {
            replyHandler(nil, "bad envelope")
            return
        }
        let payload = envelope["payload"] as? [String: Any] ?? [:]

        switch type {
        case "save.put":
            // entries: { key: string | null }  (null = 삭제)
            let entries = payload["entries"] as? [String: Any] ?? [:]
            var puts: [String: String?] = [:]
            for (key, value) in entries { puts.updateValue(value as? String, forKey: key) }   // NSNull → nil = 삭제 표시(키는 남긴다)
            saves.apply(puts)
            replyHandler(["ok": true, "n": puts.count], nil)

        case "haptic":
            let pattern = (payload["pattern"] as? [NSNumber])?.map { $0.intValue } ?? [20]
            haptics.play(pattern: pattern)
            replyHandler(nil, nil)

        case "perf.sample":
            perf.ingest(payload)
            replyHandler(nil, nil)

        case "app.ready":
            perf.mark("ready", detail: Self.compact(payload))
            onReady?(payload)
            replyHandler(["native": true, "version": 1], nil)

        case "gl.lost":
            perf.mark("glLost", detail: Self.compact(payload))
            replyHandler(nil, nil)
            onGLLost?()

        case "log":
            let level = payload["level"] as? String ?? "info"
            let msg = payload["msg"] as? String ?? ""
            NSLog("[BagBoss/web %@] %@ %@", level, msg, payload["src"] as? String ?? "")
            if level == "error" { perf.mark("jsError", detail: msg) }
            replyHandler(nil, nil)

        default:
            replyHandler(nil, "unknown type: \(type)")
        }
    }

    // MARK: 네이티브 → 웹
    /// 웹의 NativeBridge._native({type}) 를 부르고, 그 Promise가 끝나면 completion.
    func emit(_ type: String, completion: ((Any?) -> Void)? = nil) {
        guard let webView else { completion?(nil); return }
        let body = "return await (window.NativeBridge ? window.NativeBridge._native({ type: t }) : null);"
        webView.callAsyncJavaScript(body, arguments: ["t": type], in: nil, in: .page) { result in
            switch result {
            case .success(let value): completion?(value)
            case .failure(let error):
                NSLog("[BagBoss] emit %@ 실패: %@", type, error.localizedDescription)
                completion?(nil)
            }
        }
    }

    private static func compact(_ obj: [String: Any]) -> String {
        // NaN · 무한대 같은 값은 JSONSerialization이 try로 못 잡는 예외를 던진다 → 먼저 검사
        guard JSONSerialization.isValidJSONObject(obj) else { return String(describing: obj) }
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}
