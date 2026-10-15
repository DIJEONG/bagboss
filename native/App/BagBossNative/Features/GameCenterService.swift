import Foundation
import Observation
import UIKit
import GameKit
import BBSim
import BBPersistence

// Game Center(docs/01 2단계 ③): 리더보드 3개 — 타워 최고(tower_best) · 오늘의 타워(daily_tower, ASC 에서 '반복' 리더보드) · 본편 최고 점수(run_best_score).
//   점수 규칙은 BBPersistence LeaderboardScore(타워 = 층 × 10000 + (9999 − 초) — 같은 층이면 빨리 오른 쪽이 위).
// 원칙: 게임은 Game Center 없이 완전히 돈다.
//   · 로그인은 막지 않는다 — authenticateHandler 가 로그인 화면을 주면 바로 띄우지 않고 쥐고 있다가, 메뉴의 Game Center 단추를 누를 때 띄운다.
//   · 로그인 전 · 오프라인 기록은 저장 메타에 이미 있다 → 로그인되는 순간 지금까지의 최고 기록을 한꺼번에 올린다(LeaderboardScore.bests).
//   · 올리기 실패는 조용히 넘긴다(GameKit 이 로그인 상태의 오프라인 제출은 스스로 모아 보낸다).

@MainActor @Observable
final class GameCenterService {
    static let shared = GameCenterService()

    private(set) var authenticated = false
    private(set) var playerName: String?
    /// 로그인 화면을 쥐고 있음(단추를 누르면 띄운다)
    private(set) var needsSignIn = false
    var notice: String?

    @ObservationIgnored var bestsProvider: (() -> LeaderboardScore.Bests?)?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var signInVC: UIViewController?

    private var ids: FeatureConfig.Leaderboards { FeatureConfig.shared.leaderboards }

    func authenticate() {
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = Self.makeHandler()
    }

    /// GameKit 은 이 처리기를 아무 스레드에서나 부를 수 있다 — 주 액터에 묶이지 않은 클로저로 만들어 넘긴다
    nonisolated private static func makeHandler() -> (UIViewController?, (any Error)?) -> Void {
        return { vc, error in
            let v = vc
            let msg = error?.localizedDescription
            Task { @MainActor in GameCenterService.shared.handleAuth(v, error: msg) }
        }
    }

    private func handleAuth(_ vc: UIViewController?, error: String?) {
        if let vc { signInVC = vc; needsSignIn = true; return }
        let p = GKLocalPlayer.local
        authenticated = p.isAuthenticated
        needsSignIn = false; signInVC = nil
        playerName = p.isAuthenticated ? p.displayName : nil
        #if DEBUG
        print("[gc] 로그인 \(authenticated ? "됨 · \(p.displayName)" : "안 됨")\(error.map { " · \($0)" } ?? "")")
        #endif
        if authenticated, let b = bestsProvider?() { submitBests(b) }
    }

    // MARK: 올리기

    private func submit(_ score: Int, _ leaderboard: String, context: Int = 0) {
        guard authenticated, score > 0 else { return }
        Task { @MainActor in
            do {
                try await GKLeaderboard.submitScore(score, context: context, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard])
            } catch {
                #if DEBUG
                print("[gc] 올리기 실패(\(leaderboard)): \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// 로그인 직후: 지금까지의 최고 기록(Game Center 는 더 높은 값만 남긴다)
    func submitBests(_ b: LeaderboardScore.Bests) {
        submit(b.runScore, ids.runBest)
        submit(b.tower, ids.towerBest)
        submit(b.dailyTower, ids.dailyTower)
    }

    /// 지하철 판 끝(SimEvent.runEnded)
    func reportRun(score: Int) { submit(score, ids.runBest) }

    /// 타워 끝(SimEvent.towerEnded) — 오늘의 타워는 그날 리더보드, 그 밖은 타워 최고(context = 야근 단계)
    func reportTower(_ r: TowerResult) {
        let s = LeaderboardScore.tower(floor: r.floor, seconds: r.seconds)
        if r.daily != nil { submit(s, ids.dailyTower) } else { submit(s, ids.towerBest, context: r.ot) }
    }

    // MARK: 대시보드

    /// 메뉴의 Game Center 단추: 로그인 안 됐으면 쥐고 있던 로그인 화면, 됐으면 리더보드
    func openDashboard() {
        if authenticated {
            GKAccessPoint.shared.trigger(state: .leaderboards) {}
            return
        }
        if let vc = signInVC, let top = Self.topViewController() {
            top.present(vc, animated: true)
            return
        }
        notice = KE("Game Center 에 로그인돼 있지 않아요. 설정 앱 › Game Center 에서 로그인하면 기록이 올라가요. (게임은 그대로 할 수 있어요)",
                    "Not signed in to Game Center. Sign in from Settings › Game Center to post scores. (The game works without it.)")
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}
