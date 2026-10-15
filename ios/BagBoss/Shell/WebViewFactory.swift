import UIKit
import WebKit

/// WKWebView 구성. 게임 HTML은 손대지 않고, 필요한 것은 전부 사용자 스크립트로 주입한다.
@MainActor
enum WebViewFactory {
    static let messageHandlerName = "bagboss"

    static var webRoot: URL {
        guard let url = Bundle.main.url(forResource: "Web", withExtension: nil) else {
            fatalError("번들에 Web/ 폴더가 없다 — tools/build_web.py 를 돌리고 xcodegen generate 를 다시 하세요")
        }
        return url
    }

    static func make(router: BridgeRouter, snapshot: [String: String], config: AppConfig) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.setURLSchemeHandler(AppSchemeHandler(root: webRoot), forURLScheme: AppSchemeHandler.scheme)
        cfg.websiteDataStore = .default()                       // 영구 저장소(localStorage 유지)
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.dataDetectorTypes = []
        cfg.suppressesIncrementalRendering = false
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = false
        cfg.preferences.isElementFullscreenEnabled = false

        let ucc = cfg.userContentController
        installUserScripts(on: ucc, snapshot: snapshot, config: config)
        ucc.addScriptMessageHandler(router, contentWorld: .page, name: messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.underPageBackgroundColor = .black
        let scroll = webView.scrollView
        scroll.isScrollEnabled = false
        scroll.bounces = false
        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false
        scroll.contentInsetAdjustmentBehavior = .never          // 안전 영역은 CSS env(safe-area-inset-*)가 처리(viewport-fit=cover)
        scroll.delaysContentTouches = false
        scroll.pinchGestureRecognizer?.isEnabled = false
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { webView.isInspectable = config.debug }   // 맥 Safari › 개발자 메뉴에서 붙어 프로파일링
        return webView
    }

    /// documentStart 순서: ① 설정 + 저장 스냅숏 → ② bridge.js → (게임 스크립트)
    /// 웹 콘텐츠 프로세스가 죽어 다시 불러올 때도 최신 스냅숏으로 다시 깐다.
    static func installUserScripts(on ucc: WKUserContentController, snapshot: [String: String], config: AppConfig) {
        ucc.removeAllUserScripts()
        let snapJSON: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: []),
                  let text = String(data: data, encoding: .utf8) else { return "{}" }
            return text
        }()
        let preamble = "window.__BAGBOSS_CFG__=\(config.webJSON);window.__BAGBOSS_SAVE__=\(snapJSON);"
        ucc.addUserScript(WKUserScript(source: preamble, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let bridgeURL = webRoot.appendingPathComponent("app/bridge.js")
        if let bridge = try? String(contentsOf: bridgeURL, encoding: .utf8) {
            ucc.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        } else {
            NSLog("[BagBoss] bridge.js 를 읽지 못했다: %@", bridgeURL.path)
        }
    }
}
