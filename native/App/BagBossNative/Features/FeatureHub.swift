import Foundation
import Observation
import UIKit
import BBContent
import BBSim
import BBAnim
import BBPersistence

// 2단계 A 앱 기능 묶음(에이전트 O — docs/06 §8 'N6 준비 · 앱 기능'):
//   무도장(콤보 실험실) 전체 패널 · 스킨 미리보기 · StoreKit 2 유료 스킨 · Game Center · 결과 공유.
// GameSession 은 판 하나의 조립 지점이라 기능 상태를 여기(FeatureHub)에 따로 둔다 — GameSession 에는 갈고리 몇 줄만 있다:
//   init 끝 → FeatureHub.shared.boot(session)
//   openDojo → noteDojoEntry(…) (나갈 때 되돌아갈 곳)
//   handleFlow towerEnded · runEnded → GameCenterService.report…

/// 상품 · 리더보드 ID(FeatureConfig.json — App Store Connect 와 같아야 한다)
struct FeatureConfig: Decodable {
    struct SkinProduct: Decodable { let key: String; let productID: String }
    struct Leaderboards: Decodable { let towerBest: String; let dailyTower: String; let runBest: String }
    let freeSkins: [String]
    let skins: [SkinProduct]
    let leaderboards: Leaderboards

    static let shared: FeatureConfig = {
        if let u = Bundle.main.url(forResource: "FeatureConfig", withExtension: "json"),
           let d = try? Data(contentsOf: u), let c = try? JSONDecoder().decode(FeatureConfig.self, from: d) { return c }
        // 설정 파일이 빠져도 게임은 돈다(유료 스킨은 잠긴 채 · 리더보드 기본 ID)
        return FeatureConfig(freeSkins: ["jw"], skins: [], leaderboards: .init(towerBest: "tower_best", dailyTower: "daily_tower", runBest: "run_best_score"))
    }()

    var free: Set<String> { Set(freeSkins) }
    func productID(_ skin: String) -> String? { skins.first { $0.key == skin }?.productID }
    func skin(forProduct id: String) -> String? { skins.first { $0.productID == id }?.key }
}

@MainActor @Observable
final class FeatureHub {
    static let shared = FeatureHub()

    /// 무도장에서 나가면 되돌아갈 곳(웹 stopDojo: 들어오기 전 판이 있으면 이어 하기, 없으면 — 네이티브는 타이틀 메뉴로)
    enum DojoReturn: Equatable { case resumeRun, title(MenuTab?) }
    var dojoReturn: DojoReturn = .title(.codex)
    /// 스킨 미리보기 중(무도장 위 스튜디오 — SimSnapshot.skinPv)
    var skinPreview = false
    /// 미리보기로 입혀 보는 스킨(잠긴 스킨도 볼 수 있다)
    var previewSkin = "jw"
    /// 무도장에서만 입는 스킨(잠긴 유료 스킨도 시험 — 착용 설정은 그대로, 저장 안 함 · 무도장을 나가면 지운다)
    var dojoSkin: String?
    /// 자세 편집기(개발자 도구 — 스킨 미리보기 스튜디오 위에서 PoseEditorPanel 을 보인다)
    var poseEditor = false
    /// 무도장 패널의 '스킨'으로 연 미리보기(닫으면 무도장으로 돌아간다 — 메뉴 · 설정에서 연 것은 무도장을 나간다)
    var previewFromDojo = false
    /// 무도장 패널 탭(웹 OPT.djTab)
    var dojoTab = "combo"
    #if DEBUG
    /// 점검용: 무도장 패널이 열릴 때 커스텀 콤보를 이것으로(저장하지 않음) · 단계 편집기를 이 칸(0부터)으로 연다
    @ObservationIgnored var debugCC: [String]?
    @ObservationIgnored var debugEdit: Int?
    /// -feature dojo-cc16 의 16단 예시(팔레트 값 — 주먹 콤보 · 발 · 잡기 · 네이티브 복싱 섞음)
    static let debugCC16 = ["nv_flick", "punch:0", "punch:1", "nv_liver", "punch:2", "upper:scoop", "skick", "cycle",
                            "axe", "kick", "round", "elbow", "knee", "nv_cork", "tetsu", "renkan"]
    #endif

    @ObservationIgnored private(set) weak var session: GameSession?
    @ObservationIgnored private var booted = false
    @ObservationIgnored private var catalogCache: DojoCatalog?
    var dojoCatalog: DojoCatalog {
        if let c = catalogCache { return c }
        let c = DojoCatalog(session?.store); if session != nil { catalogCache = c }; return c
    }

    /// GameSession init 끝에서 한 번. 무겁지 않게 — 저장 캐시만 읽고 StoreKit · Game Center 는 비동기
    func boot(_ s: GameSession) {
        guard !booted else { return }
        booted = true; session = s
        if let t = s.save?.options().extras["djTab"]?.stringValue { dojoTab = t }
        let store = SkinStore.shared
        store.onChange = { [weak self] in self?.enforceSkin() }
        store.boot(save: s.save)
        enforceSkin()
        PoseEditor.shared.boot(s.data)   // 자세 편집기 저장분('bbn-pose-edits')을 덮어쓰기 층에(없으면 아무것도 안 한다)
        #if DEBUG
        debugLaunch(s)
        if ProcessInfo.processInfo.arguments.contains("-nogamecenter") { return }
        #endif
        GameCenterService.shared.bestsProvider = { [weak s] in
            guard let s else { return nil }
            return LeaderboardScore.bests(s.meta, dailyKey: DailyKey.today())
        }
        GameCenterService.shared.authenticate()
    }

    /// 고른 스킨이 잠겨 있으면 기본으로(시험 기간에 골라 둔 유료 스킨 · 환불)
    func enforceSkin() {
        guard let s = session else { return }
        let C = s.content
        let eff = SkinStore.shared.unlocks.effectiveSkin(selected: s.settings.skin, free: FeatureConfig.shared.free, known: Set(C.skinKeys))
        if eff != s.settings.skin { s.settings.skin = eff; s.applySettings() }
    }

    #if DEBUG
    /// 점검용 실행 인자: -feature dojo | dojo-custom | dojo-move | dojo-react | dojo-cc16 | skinpv[-<스킨>] | share-tower
    ///   -dojoskin <스킨> = 무도장에서 그 스킨으로 '무도장에서 쓰기'까지 진행
    ///   dojo-cc16 = 커스텀 탭에 16단 예시 콤보를 깔고(저장 안 함) 한 번 실행 · -ccedit <n> = 단계 편집기를 n단(1부터)으로 연 채
    ///   -poseedit [자세] [-peset <조절 이름>=<값>[,…]] = 자세 편집기를 그 자세로 열고(저장 안 함) 슬라이더 값을 넣어 본다(예: -peset 앞 위팔=90,공중 높이=12) · -peview <도> = 보기 회전
    private func debugLaunch(_ s: GameSession) {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-poseedit") {
            let k = i + 1 < a.count && !a[i + 1].hasPrefix("-") ? a[i + 1] : nil
            let sets = a.firstIndex(of: "-peset").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                let ed = PoseEditor.shared
                ed.noSave = true
                if let k { ed.focus(pose: k, self) }
                self.openPoseEditor()
                if let j = a.firstIndex(of: "-peview"), j + 1 < a.count, let v = Double(a[j + 1]) {   // 보기 회전 점검
                    try? await Task.sleep(for: .milliseconds(800))
                    ed.view = v; s.enqueue(.skinPreview(.view(v)))
                }
                guard let sets else { return }
                try? await Task.sleep(for: .milliseconds(1500))
                for kv in sets.split(separator: ",") {
                    let p = kv.split(separator: "=", maxSplits: 1).map(String.init)
                    if p.count == 2, let v = Double(p[1]), let c = PoseEdit.controls.first(where: { $0.name == p[0] }) { ed.set(c, v) }
                }
                print("[features] 자세 편집기 \(ed.pose) 수정분 \(PoseEdit.diffLine(ed.pose, ed.diff(ed.pose)))")
            }
            return
        }
        guard let i = a.firstIndex(of: "-feature"), i + 1 < a.count else { return }
        let name = a[i + 1]
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if name.hasPrefix("dojo") {
                if name.hasPrefix("dojo-") { self.dojoTab = String(name.dropFirst(5)) }
                if name == "dojo-cc16" { self.dojoTab = "custom"; self.debugCC = Self.debugCC16 }
                if let j = a.firstIndex(of: "-ccedit"), j + 1 < a.count, let n = Int(a[j + 1]) { self.dojoTab = "custom"; self.debugEdit = n - 1 }
                s.openDojo()
                if name == "dojo-cc16" { try? await Task.sleep(for: .milliseconds(600)); s.enqueue(.dojo(.setCustom(Self.debugCC16))); s.dojo(.customRun) }
                if let j = a.firstIndex(of: "-dojoskin"), j + 1 < a.count {   // 무도장 스킨 버튼 → 미리보기 → '무도장에서 쓰기' 흐름 점검
                    try? await Task.sleep(for: .milliseconds(800)); self.openSkinPreview()
                    try? await Task.sleep(for: .milliseconds(1200)); self.previewSkinChange(a[j + 1])
                    try? await Task.sleep(for: .milliseconds(1200)); self.useInDojo(a[j + 1])
                    try? await Task.sleep(for: .milliseconds(600))
                    print("[features] 무도장 스킨 \(self.dojoSkin ?? "-") · 그리기 \(s.director.characters.heroSkin) · 착용 \(s.settings.skin) · 미리보기 \(self.skinPreview)")
                }
                if name == "dojo" { try? await Task.sleep(for: .milliseconds(600)); s.dojo(.combo(2)) }
                if name == "dojo-custom" { try? await Task.sleep(for: .milliseconds(600)); s.enqueue(.dojo(.setCustom(s.save?.customCombo().steps ?? []))); s.dojo(.customRun) }
            } else if name.hasPrefix("skinpv") {
                self.openSkinPreview(name.count > 7 ? String(name.dropFirst(7)) : nil)
            } else if name == "share-tower" {
                s.debugShowTower()
                try? await Task.sleep(for: .milliseconds(500))
                if case .tower(let r)? = s.result, let img = ResultShare.towerImage(r, session: s) { Self.dumpPNG(img, "share-tower") }
            } else if name == "share-news" {
                s.begin(RunRequest(), seed: 2026)
                try? await Task.sleep(for: .seconds(5))
                s.debugShowNews(win: false)
                try? await Task.sleep(for: .seconds(1))
                if case .news(let n)? = s.result, let img = ResultShare.newsImage(n, session: s) { Self.dumpPNG(img, "share-news") }
            }
        }
    }
    /// 공유 그림을 앱 Documents 에 PNG 로(점검용)
    static func dumpPNG(_ img: UIImage, _ name: String) {
        guard let d = img.pngData(), let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let u = dir.appendingPathComponent("\(name).png"); try? d.write(to: u)
        print("[features] 공유 그림 → \(u.path)")
    }
    #endif

    // MARK: 무도장

    /// GameSession.openDojo 갈고리: 무도장 밖에서 들어올 때만 되돌아갈 곳을 적는다
    func noteDojoEntry(fromRun: Bool, menu: MenuTab?) {
        dojoReturn = fromRun ? .resumeRun : .title(menu ?? .codex)
    }

    /// 무도장(또는 스킨 미리보기) 나가기 — 들어오기 전 판이 있었으면 이어 하기(Sim.resume), 아니면 타이틀 메뉴
    func exitDojo() {
        guard let s = session else { return }
        if skinPreview { s.enqueue(.skinPreview(.close)) }
        skinPreview = false; previewFromDojo = false; dojoSkin = nil; poseEditor = false
        s.director.characters.heroSkin = s.settings.skin
        s.audio.play(.click)
        switch dojoReturn {
        case .resumeRun where s.runSave != nil: s.continueRun()
        case .resumeRun: s.toTitle(openMenu: .run)
        case .title(let t): s.toTitle(openMenu: t)
        }
    }

    func setDojoTab(_ t: String) {
        dojoTab = t
        saveOption("djTab", .string(t))
    }

    func saveOption(_ k: String, _ v: BBPersistence.JSONValue) {
        guard let save = session?.save else { return }
        var o = save.options(); o.extras[k] = v; save.setOptions(o)
    }

    // MARK: 스킨 미리보기

    /// 스킨 미리보기 열기(설정 · 메뉴에서) — 무도장 판 위에서 주인공만 스튜디오로(SkinPreviewCommand.open)
    func openSkinPreview(_ skin: String? = nil) {
        guard let s = session else { return }
        if !skinPreview { previewFromDojo = s.current.mode == .dojo && s.sim != nil && s.phase != "over" }
        let k = skin ?? dojoSkin ?? s.settings.skin
        previewSkin = k
        s.openDojo(route: nil, skin: k)   // 진행 중인 판은 이어 하기로 저장 · 되돌아갈 곳 기록(무도장 안이면 그대로)
        s.director.characters.heroSkin = k
        s.enqueue(.skinPreview(.open))
        skinPreview = true
    }

    // MARK: 자세 편집기(웹 poseEdOpen · poseEdClose)

    /// 자세 편집기 열기 — 무도장으로 가서(없으면) 스튜디오를 열고 고른 자세를 고정한다
    func openPoseEditor() {
        guard let s = session else { return }
        openSkinPreview()
        poseEditor = true
        let ed = PoseEditor.shared
        ed.z1 = false; ed.view = 0
        ed.show(s)
        s.audio.play(.click)
    }
    /// 닫기(웹 poseEdClose = skinPvClose): 무도장에서 열었으면 무도장에 남고, 메뉴에서 열었으면 무도장을 나간다
    func closePoseEditor() {
        guard session != nil else { return }
        poseEditor = false
        if previewFromDojo { closeSkinPreview() } else { exitDojo() }
    }

    /// 미리보기 안에서 스킨 바꾸기 — 몸짓(gx_<스킨>)이 시뮬레이션 설정값이라 무도장을 그 스킨으로 다시 연다
    func previewSkinChange(_ k: String) {
        guard let s = session, k != previewSkin else { return }
        openSkinPreview(k)
        s.audio.play(.click)
    }

    /// 미리보기만 닫고 무도장에 남기 — 미리보기가 무도장을 그 스킨으로 다시 열었으니 무도장 스킨(없으면 착용 스킨)으로 되연다
    func closeSkinPreview() {
        guard let s = session else { return }
        s.enqueue(.skinPreview(.close))
        skinPreview = false; previewFromDojo = false; poseEditor = false
        let k = dojoSkin ?? s.settings.skin
        if previewSkin != k { s.openDojo(route: nil, skin: k) }
        s.director.characters.heroSkin = k
        s.audio.play(.click)
    }

    /// 무도장에서 이 스킨으로 싸우기(잠긴 것도 — 무도장 전용 시험, 착용은 바뀌지 않는다)
    func useInDojo(_ k: String) {
        guard let s = session else { return }
        dojoSkin = k == s.settings.skin ? nil : k
        previewSkin = k
        closeSkinPreview()
    }

    /// 스킨 입기(가진 것만) — 설정 저장(웹 OPT.skin)
    func equip(_ k: String) {
        guard let s = session, SkinStore.shared.unlocks.isUnlocked(k, free: FeatureConfig.shared.free) else { return }
        s.settings.skin = k; s.applySettings()
        if skinPreview { s.director.characters.heroSkin = k }
    }
}

// MARK: 무도장 데이터(웹 42-dojo.js DOJO · DJ_DUMMY · DEMO_BAGS · CC_MAX — 생성물 42-dojo.json)

struct DojoCatalog {
    struct Move: Hashable { let name: String; let id: String; let combo: Int? }
    var hero: [Move] = [], misc: [Move] = [], spc: [Move] = [], react: [Move] = [], foe: [Move] = []
    /// 커스텀 콤보 팔레트(이름 · 'punch:0' 꼴 값)
    var moves: [(name: String, value: String)] = []
    var combos: [String] = []
    var dummies: [(key: String, name: String)] = [("punk", "건달"), ("heavy", "덩치"), ("brute", "배불뚝이"), ("boss4", "두목")]
    var demoBags: [String] = []
    /// 커스텀 콤보 최대 단수(웹 CC_MAX 8 → 네이티브 16 — BBSim NativeContent.dojoCCMax)
    var ccMax = NativeContent.dojoCCMax

    init(_ store: ContentStore?) {
        guard let store, let D = (try? store.raw("DOJO"))?.object else { return }
        func list(_ k: String) -> [Move] {
            (D[k]?.array ?? []).compactMap { e in
                guard let a = e.array, a.count >= 2, let n = a[0].string, let id = a[1].string else { return nil }
                return Move(name: n, id: id, combo: a.count > 2 ? a[2].int : nil)
            }
        }
        hero = list("hero"); misc = list("misc"); spc = list("spc"); react = list("react"); foe = list("foe")
        moves = list("moves").map { ($0.name, $0.id) }
        combos = (D["combo"]?.array ?? []).compactMap { $0.array?.first?.string }
        if let dd = (try? store.raw("DJ_DUMMY"))?.array {
            let v = dd.compactMap { e -> (String, String)? in guard let a = e.array, a.count >= 2, let k = a[0].string, let n = a[1].string else { return nil }; return (k, n) }
            if !v.isEmpty { dummies = v.map { (key: $0.0, name: $0.1) } }
        }
        demoBags = ((try? store.raw("DEMO_BAGS"))?.array ?? []).compactMap { $0.object?["n"]?.string }
        if let m = (try? store.raw("CC_MAX"))?.int { ccMax = max(m, NativeContent.dojoCCMax) }
        // 네이티브 동작 개편(앱은 SimConfig.nativeMoves 를 켠다 — BBSim StoryData 와 같은 순서로 뒤에 붙인다)
        // 새 기술 · 새 콤보는 목록 맨 앞에(기존 30여 개 뒤에 숨지 않게) — 동작은 id 로 부르므로 순서를 바꿔도 된다
        hero = NativeContent.dojoHero.map { Move(name: $0.name, id: $0.id, combo: nil) } + hero
        moves = NativeContent.dojoMoves + moves
        combos += NativeContent.dojoCombos.map(\.name)
        demoBags += NativeContent.demoBags.map(\.n)
        spc = spc.map { $0.id == "fist" ? Move(name: NativeContent.dojoSpcFist, id: $0.id, combo: $0.combo) : $0 }
        // 상대: 기존 적 3(얍삽한 놈 · 권법가 · 롤러 폭주족) + 네이티브 새 적 3(스파링꾼 · 라인배커 · 신문팔이 소년)
        dummies += NativeContent.dojoDummies.filter { d in !dummies.contains { $0.key == d.key } }
    }

    func label(_ v: String) -> String { moves.first { $0.value == v }.map { tr($0.name) } ?? v }
}
