import UIKit
import WebKit
import AVFoundation

/// 루트 화면: 전체 화면 WKWebView 하나 + 측정 HUD.
final class GameViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let config = AppConfig.current
    private let saves = SaveStore()
    private lazy var haptics = Haptics()
    private lazy var perf = PerfMonitor()
    private lazy var router = BridgeRouter(saves: saves, haptics: haptics, perf: perf)
    private var webView: WKWebView!
    private let hud = PerfHUD()
    private var hudPlaced = false
    private var crashReloads = 0
    private var reloadPending = false
    private var reloadTimes: [Date] = []

    // MARK: 화면
    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AudioSessionConfig.apply()
        haptics.enabled = config.haptics

        webView = WebViewFactory.make(router: router, snapshot: saves.snapshot(), config: config)
        router.webView = webView
        router.onGLLost = { [weak self] in self?.reloadGame(reason: "glLost") }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([            // 안전 영역이 아니라 화면 끝까지(노치 아래도 게임 배경)
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        perf.start()
        perf.mark("launch", detail: "saveKeys=\(saves.snapshot().count) saveBytes=\(saves.fileSizeBytes)")
        hud.attach(to: view, monitor: perf)
        hud.isHidden = !config.showHUD
        hud.onShare = { [weak self] url in self?.shareFile(url) }

        // 세 손가락 두 번 탭: HUD 켜고 끄기 (게임 터치는 그대로 통과)
        let toggle = UITapGestureRecognizer(target: self, action: #selector(toggleHUD))
        toggle.numberOfTouchesRequired = 3
        toggle.numberOfTapsRequired = 2
        toggle.cancelsTouchesInView = false
        toggle.delaysTouchesBegan = false
        toggle.delaysTouchesEnded = false
        view.addGestureRecognizer(toggle)

        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted(_:)),
                                               name: AVAudioSession.interruptionNotification, object: nil)
        haptics.prepare()
        webView.load(URLRequest(url: AppSchemeHandler.startURL))
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }   // 아래쪽 가방 조작이 홈 제스처에 먹히지 않게
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    // 시스템 세 손가락 편집 제스처(실행 취소 · 편집 막대)가 HUD 토글 제스처를 먹지 않게
    override var editingInteractionConfiguration: UIEditingInteractionConfiguration { .none }

    // 안전 영역은 창에 붙은 뒤에야 알 수 있다 → 첫 배치 때 HUD를 노치 · 다이내믹 아일랜드 아래로
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hudPlaced, view.window != nil {
            hudPlaced = true
            hud.frame.origin = CGPoint(x: 8, y: view.safeAreaInsets.top + 8)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        perf.mark("memoryWarning")
        router.emit("memory.warning")
    }

    // MARK: 수명주기 (SceneDelegate가 부른다)
    func appWillResignActive() {
        perf.mark("resignActive")
        router.emit("app.pause")
    }

    func appDidBecomeActive() {
        perf.mark("active")
        AudioSessionConfig.apply()
        router.emit("app.resume")
        haptics.prepare()
    }

    func appDidEnterBackground() {
        perf.mark("background")
        saves.flush()                                  // 이미 받은 것부터 디스크에
        let task = BackgroundTask()
        task.id = UIApplication.shared.beginBackgroundTask(withName: "bagboss.save") { [saves, task] in
            saves.flush(); task.end()
        }
        router.emit("app.pause") { [saves, task] _ in  // 웹이 마지막 저장을 보내고(save.put) 응답하면
            saves.flush()                              // 디스크까지 쓴다
            task.end()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [saves, task] in   // 웹이 끝내 응답하지 않을 때
            saves.flush(); task.end()
        }
    }

    @objc private func audioInterrupted(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended {
            AudioSessionConfig.apply()
            router.emit("app.resume")
        }
    }

    @objc private func toggleHUD() {
        hud.isHidden.toggle()
        hud.refresh()
    }

    private func shareFile(_ url: URL) {
        guard let top = topPresenter() else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = hud
        top.present(sheet, animated: true)
    }

    // MARK: WKNavigationDelegate
    // 클로저 타입은 SDK 선언과 똑같이(@MainActor @Sendable) — 다르면 엄격한 동시성 설정에서 조용히 안 불린다
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == AppSchemeHandler.scheme || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" {
            decisionHandler(.allow)
        } else if url.scheme == "http" || url.scheme == "https" {
            UIApplication.shared.open(url)              // 바깥 링크는 Safari로
            decisionHandler(.cancel)
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        perf.mark("loaded")
    }

    /// 웹 콘텐츠 프로세스가 죽었다(대개 메모리 초과). 최신 저장 스냅숏으로 다시 깔고 다시 연다.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reloadGame(reason: "webContentTerminated")
    }

    /// 저장을 디스크까지 밀어 넣고, 최신 스냅숏으로 사용자 스크립트를 다시 깐 뒤 처음부터 연다(게임은 '이어 하기'로 복귀).
    /// 겹친 요청은 하나로, 1분에 3번 넘게 죽으면 포기(무한 재시작 방지 — CSV에 reloadGiveUp)
    private func reloadGame(reason: String) {
        guard !reloadPending else { perf.mark(reason, detail: "skip:pending"); return }
        let now = Date()
        reloadTimes = reloadTimes.filter { now.timeIntervalSince($0) < 60 } + [now]
        guard reloadTimes.count <= 3 else { perf.mark("reloadGiveUp", detail: reason); return }
        reloadPending = true
        crashReloads += 1
        perf.mark(reason, detail: "reloads=\(crashReloads)")
        // gl.lost 직후 웹이 보낸 마지막 save.put이 큐에 들어올 틈을 조금 준다
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, let webView = self.webView else { return }
            self.reloadPending = false
            self.saves.flush()
            WebViewFactory.installUserScripts(on: webView.configuration.userContentController, snapshot: self.saves.snapshot(), config: self.config)
            webView.load(URLRequest(url: AppSchemeHandler.startURL))
        }
    }

    // MARK: WKUIDelegate — 지금 게임은 alert/confirm을 안 쓰지만, 쓰면 조용히 무시되지 않게
    // 띄우지 못하면 완료 처리기를 바로 불러야 한다(안 부르면 WebKit이 예외로 앱을 죽인다)
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        guard let top = topPresenter() else { completionHandler(); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
        top.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard let top = topPresenter() else { completionHandler(false); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        top.present(alert, animated: true)
    }

    private func topPresenter() -> UIViewController? {
        guard view.window != nil else { return nil }
        var top: UIViewController = self
        while let next = top.presentedViewController { top = next }
        return top.isBeingDismissed ? nil : top
    }
}

/// beginBackgroundTask 식별자 상자(클로저 안에서 var를 고치지 않으려고)
@MainActor
private final class BackgroundTask {
    var id: UIBackgroundTaskIdentifier = .invalid
    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
