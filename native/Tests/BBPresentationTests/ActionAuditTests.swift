import Testing
import Foundation
import Metal
import ImageIO
@preconcurrency import CoreText
import UniformTypeIdentifiers
import BBCore
import BBContent
import BBAnim
@testable import BBSim
@testable import BBPresentation
@testable import BBRender

/// 동작 점검(에이전트 R · docs/07-동작-점검.md): 웹 audit.mjs 가 남긴 대본(tools/js/out/audit/web/plan.json)을 같은 씨앗 · 같은 틱으로 BBSim 에 넣고,
/// StageDirector 둘(강화 끔 = 웹 대조 기준 · 강화 켬 = 앱 기본)로 장면 + HUD 를 그려 웹 띠 그림과 나란히 붙인다.
///   tools/js/out/audit/<동작>.png        [웹 | 네이티브(강화 끔) | 네이티브(강화 켬)] × 표본 틱 — 빨간 테두리 = 큐(피해) 틱, 노란 테두리 = 자세가 웹과 다른 틱
///   tools/js/out/audit/report.json       동작마다 타이밍(큐 · 끝 · 경직 · 첫 어긋남) · 연출 이벤트 비교(이름별 개수 · 첫 틱)
///   tools/js/out/audit/summary.md        위 표 요약
/// 실행: `node tools/js/extract/audit.mjs` 다음 `BB_AUDIT=1 swift test --filter ActionAuditTests` (BB_AUDIT_ONLY=이름,이름 으로 그림만 일부)
@Suite(.serialized) struct ActionAuditTests {
    static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let out = root.appending(path: "tools/js/out/audit")

    // MARK: 기록 형식

    struct ActorRow: Equatable { var anim = "", pose = "", si = 0, x = 0.0, y = 0.0, flip = false, hs = 0, jug: Double?, airOv = 0.0, act = "", wpn = "" }
    struct Row { var H = ActorRow(), D: ActorRow?, dhp = 0.0, hp = 0.0, freeze = 0, shake = 0.0, zoomK = 0.0, invF = 0, slowT = 0.0, spcTime = 1.0, camX = 0.0
        var cut: String?, spc = false, seq: Int?, canAct = false }

    static func actorRow(_ a: Actor) -> ActorRow {
        ActorRow(anim: a.anim, pose: a.pose, si: a.si, x: a.x, y: a.y, flip: a.flip, hs: a.hs, jug: a.jug?.h, airOv: a.airOv,
                 act: a.action.map { $0.fired ? "F" : "A" } ?? "", wpn: a.wpn ?? a.action?.wpn ?? "")
    }
    static func webActor(_ v: Any?) -> ActorRow? {
        guard let a = v as? [Any], a.count >= 11 else { return nil }
        func d(_ x: Any) -> Double { (x as? NSNumber)?.doubleValue ?? 0 }
        return ActorRow(anim: a[0] as? String ?? "", pose: a[1] as? String ?? "", si: Int(d(a[2])), x: d(a[3]), y: d(a[4]), flip: d(a[5]) == 1, hs: Int(d(a[6]).rounded()),
                        jug: a[7] is NSNull ? nil : d(a[7]), airOv: d(a[8]), act: a[9] as? String ?? "", wpn: a[10] as? String ?? "")
    }

    /// 웹 연출 기록 → 비교 이름
    static func webName(_ e: [Any]) -> String? {
        guard let k = e.first as? String else { return nil }
        let a = e.dropFirst().map { "\($0)" }
        switch k {
        case "sfx":
            let id = a.first ?? "?"
            if id == "hitK" { return "snd:hitK:\(a.count > 1 ? a[1] : "?")" }
            if ["click", "clack", "chime", "hiss", "press"].contains(id) { return nil }   // 무도장 배경 · UI 소리
            return "snd:" + id
        case "fx": return "fx:" + (a.first ?? "?")
        case "pop": return "pop:" + (a.first ?? "?")
        case "comic": return "comic:" + (a.first ?? "?")
        case "bubble": return "bubble:" + (a.first ?? "?")
        case "dust", "spark", "ring", "burstRing", "bit": return "p:" + k
        case "critFx": return "critFx"
        case "sw": return "shockwave"
        case "smear": return "smear"
        case "cut": return "cut:" + (a.first ?? "?")
        case "vib": return "vib"
        case "cmd": return "cmd"
        default: return k
        }
    }
    static func soundName(_ c: SoundCue) -> String? {
        switch c {
        case .hit3: return "snd:hit3"
        case .hitK(let k, _, _): return "snd:hitK:\(k)"
        case .hurt: return "snd:hurt"
        case .just: return "snd:just"
        case .floor: return "snd:floor"
        case .clack, .click, .chime, .press: return nil
        case .door: return "snd:door"
        case .merge: return "snd:merge"
        case .panClang: return "snd:panClang"
        case .tetsu: return nil   // 웹은 skTone · skNoise 직접 호출이라 sfx 기록이 없다(같은 소리)
        case .other(let id): return "snd:" + id
        default:
            let s = "\(c)"; return "snd:" + (s.split(separator: "(").first.map(String.init) ?? s)
        }
    }

    /// 표현 계층 상태에서 이번 틱에 새로 생긴 것(apply 직후 · frame 전)
    struct Seen { var pops = Set<Int>(), words = Set<Int>(), bubbles = Set<Int>(), sw = Set<String>(), cut: String?, smear: Double?, cmd = 0 }
    static func freshNames(_ d: StageDirector, _ ev: [SimEvent], _ cues: [SoundCue], seen: inout Seen) -> [String] {
        var n: [String] = []
        let H = d.hud.state
        for f in H.hitFx where f.t == 0 { n.append("fx:" + f.k) }
        for p in H.pops where !seen.pops.contains(p.id) { seen.pops.insert(p.id); n.append("pop:" + p.style) }
        for w in H.words where !seen.words.contains(w.id) { seen.words.insert(w.id); n.append("comic:" + w.word) }
        for b in H.bubbles where !seen.bubbles.contains(b.id) { seen.bubbles.insert(b.id); n.append("bubble:" + b.kind) }
        for c in H.critFx where c.t == 0 { _ = c; n.append("critFx") }
        for s in H.shockwaves { let k = "\(s.t0),\(s.x),\(s.r1)"; if !seen.sw.contains(k) { seen.sw.insert(k); n.append("shockwave") } }
        if let s = H.smear, s.t0 != seen.smear { seen.smear = s.t0; n.append("smear") }
        if let c = H.cut, seen.cut == nil { n.append("cut:" + c.k) }
        seen.cut = H.cut?.k
        if H.cmdLog.count > 0 { let fresh = H.cmdLog.filter { $0.age == 0 }.count; for _ in 0..<fresh { n.append("cmd") } }
        for x in d.fx.dusts where x.age == 0 { _ = x; n.append("p:dust") }
        for x in d.fx.sparks where x.age == 0 { _ = x; n.append("p:spark") }
        for x in d.fx.rings where x.age == 0 { n.append(x.burst ? "p:burstRing" : "p:ring") }
        for x in d.fx.bits where x.t == 0 { _ = x; n.append("p:bit") }
        // 진동: 앱 BBHaptics.HapticPlanner.pattern(for:) 과 같은 판정(이 테스트 타깃은 BBHaptics 를 모른다 — 웹 buzz 자리와 비교)
        for e in ev {
            switch e {
            case .hit(let h) where !h.heroWasHit: if h.attackerIsHero && (h.knock || h.crit || h.reactOpt == "launch") { n.append("vib") }   // = HapticPlanner.heroHitBuzzes
            case .heroHurt, .bossAppear, .specialUsed, .haptic: n.append("vib")
            case .comicWord(let w, _, _) where w == "KA-BOOM!": n.append("vib")
            default: break
            }
        }
        n += cues.compactMap(soundName)
        return n
    }

    // MARK: 그림

    nonisolated(unsafe) static let font = CTFontCreateWithName("AppleSDGothicNeo-Regular" as CFString, 15, nil)
    nonisolated(unsafe) static let fontB = CTFontCreateWithName("AppleSDGothicNeo-Bold" as CFString, 22, nil)
    static func text(_ ctx: CGContext, _ s: String, x: Double, y: Double, H: Int, bold: Bool = false, color: CGColor = CGColor(gray: 0.92, alpha: 1)) {
        let attr = [kCTFontAttributeName: bold ? fontB : font, kCTForegroundColorAttributeName: color] as CFDictionary
        let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString, attr))
        ctx.textPosition = CGPoint(x: x, y: Double(H) - y)
        CTLineDraw(line, ctx)
    }
    static func image(_ px: [UInt8], w: Int, h: Int) -> CGImage {
        var p = px
        let c = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return c.makeImage()!
    }
    /// 장면(480×270 위→아래) 자르기 + UI(VW·3) 얹기 → 2배 칸(웹 audit.mjs capture 와 같은 식)
    static func composite(scene: [UInt8], ui: [UInt8], uiW: Int, uiH: Int, camX: Double, x0: Int, y0: Int, cw: Int, ch: Int, sc: Int) -> [UInt8] {
        let ow = cw * sc, oh = ch * sc
        var o = [UInt8](repeating: 255, count: ow * oh * 4)
        let ux0 = Int((Double(x0) - camX) * 3 + 0.5), uy0 = y0 * 3   // 웹 Math.round
        for y in 0..<oh { for x in 0..<ow {
            let sx = x0 + x / sc, sy = y0 + y / sc, si = (sy * 480 + sx) * 4
            let ux = ux0 + Int((Double(x) + 0.5) * 3 / Double(sc)), uy = uy0 + Int((Double(y) + 0.5) * 3 / Double(sc))
            var a = 0.0, u: (Double, Double, Double) = (0, 0, 0)
            if ux >= 0 && ux < uiW && uy >= 0 && uy < uiH { let k = (uy * uiW + ux) * 4; a = Double(ui[k + 3]) / 255; u = (Double(ui[k]), Double(ui[k + 1]), Double(ui[k + 2])) }
            let d = (y * ow + x) * 4
            o[d] = UInt8(min(255, (Double(scene[si]) * (1 - a) + u.0 * a).rounded()))
            o[d + 1] = UInt8(min(255, (Double(scene[si + 1]) * (1 - a) + u.1 * a).rounded()))
            o[d + 2] = UInt8(min(255, (Double(scene[si + 2]) * (1 - a) + u.2 * a).rounded()))
        } }
        return o
    }

    // MARK: 실행

    @Test("웹 대본으로 모든 동작을 돌려 나란히 그리고 타이밍 · 연출을 비교한다(BB_AUDIT=1)") func audit() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["BB_AUDIT"] == "1" else { return }
        let webDir = Self.out.appending(path: "web")
        guard let pd = try? Data(contentsOf: webDir.appending(path: "plan.json")),
              let plan = try JSONSerialization.jsonObject(with: pd) as? [String: Any], let actions = plan["actions"] as? [[String: Any]] else {
            Issue.record("plan.json 없음 — 먼저 node tools/js/extract/audit.mjs"); return
        }
        let only = Set((env["BB_AUDIT_ONLY"] ?? "").split(separator: ",").map(String.init))
        let crop = plan["crop"] as! [String: Any]
        let cw = (crop["w"] as! NSNumber).intValue, up = (crop["up"] as! NSNumber).intValue, dn = (crop["dn"] as! NSNumber).intValue
        let sc = (crop["scale"] as! NSNumber).intValue, per = (crop["perRow"] as! NSNumber).intValue, ch = up + dn
        let seed = UInt32((plan["seed"] as! NSNumber).intValue), warm = (plan["warm"] as! NSNumber).intValue

        let store = try ContentStore.bundled(), data = try SimData.bundled(), content = try SceneContent.bundled()
        func director(_ st: MotionStyle) throws -> StageDirector {
            let d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK, style: st)
            d.hud.art = try HUDArt(store: store); d.hud.playSpeed = 1; d.playSpeed = 1; return d
        }
        let dOff = try director(.off), dOn = try director(.on)
        let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
        let fr = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()), ov = try OverlayRenderer(device: device)
        let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)

        var cfg = SimConfig(); cfg.playSpeed = 1; cfg.autoAdvance = true; cfg.trackDrawnPose = true; cfg.skipTalks = true; cfg.kit = "basic"
        cfg.harnessWarmup = true; cfg.mode = .dojo
        let sim = Sim(data: data, seed: seed, config: cfg)
        sim.apply(.setSpeed(1))
        let w = sim.w
        var tick = 0
        var seenOff = Seen(), seenOn = Seen()
        func step() -> (ev: [SimEvent], names: [String]) {
            let ev = sim.step(), s = sim.snapshot, now = Double(tick) / 60
            let cues = dOff.apply(ev, snapshot: s, now: now)
            let names = Self.freshNames(dOff, ev, cues, seen: &seenOff)
            _ = dOn.apply(ev, snapshot: s, now: now); _ = Self.freshNames(dOn, ev, [], seen: &seenOn)
            tick += 1
            return (ev, names)
        }
        func frames() -> (StageFrame, StageFrame) {
            let s = sim.snapshot, now = Double(tick) / 60
            return (dOff.frame(s, dt: 1.0 / 60, now: now), dOn.frame(s, dt: 1.0 / 60, now: now))
        }
        func shot(_ d: StageDirector, _ f: StageFrame, x0: Int, y0: Int) throws -> [UInt8] {
            let s = sim.snapshot
            var rf = RenderFrame(stage: f, atlas: content.sprites); rf.applyHUD(d.hud.state, now: s.time)
            let cb = try #require(q.makeCommandBuffer()); try fr.encode(rf, targets: tg, into: cb); cb.commit(); cb.waitUntilCompleted()
            let scene = try fr.readBack(tg.output(for: rf), queue: q)
            let F = d.hud.frame(s, view: f.view, shake: f.shake), list = HUDOverlay.build(d.hud.state, F, art: d.hud.art!)
            let ui = try ov.render(list, atlas: d.hud.art!.atlas, queue: q)
            return Self.composite(scene: scene, ui: ui, uiW: list.width, uiH: list.height, camX: f.view.cameraX, x0: x0, y0: y0, cw: cw, ch: ch, sc: sc)
        }
        for _ in 0..<warm { _ = step(); _ = frames() }

        var report: [[String: Any]] = []
        var md = "| 동작 | 분류 | 큐 틱 웹/네이티브 | 끝 웹/네이티브 | 상태 첫 어긋남 | 자세 다른 틱 | 웹에만 | 네이티브에만 | 개수 · 시점 차 |\n|---|---|---|---|---|---|---|---|---|\n"
        for A in actions {
            let name = A["name"] as! String
            let wurl = webDir.appending(path: "\(name).json")
            guard let wd = try? Data(contentsOf: wurl), let W = try JSONSerialization.jsonObject(with: wd) as? [String: Any] else { Issue.record("웹 기록 없음 \(name)"); continue }
            let win = (A["win"] as! NSNumber).intValue, cmds = A["cmds"] as! [[Any]], dummy = A["dummy"] as! String, trig = A["trig"] as? String
            let t0 = (W["t0"] as! NSNumber).intValue
            #expect(t0 == tick, "\(name): 시작 틱 웹 \(t0) ≠ 네이티브 \(tick)")
            let cx = (W["cx"] as! NSNumber).intValue, gy = (W["gy"] as! NSNumber).intValue
            let x0 = max(0, min(480 - cw, cx - cw / 2)), y0 = max(0, min(270 - ch, gy - up))
            let webShots = (W["shots"] as! [NSNumber]).map(\.intValue)
            let wrows = W["rows"] as! [[Any]]
            var wev: [Int: [String]] = [:]
            for e in W["evs"] as! [[Any]] { let i = (e[0] as! NSNumber).intValue; wev[i] = (e[1] as! [[Any]]).compactMap(Self.webName) }
            let wCueH = (W["cueH"] as? NSNumber)?.intValue, wCueF = (W["cueF"] as? NSNumber)?.intValue, wCalm = (W["calm"] as! NSNumber).intValue

            if w.dojoDummy()?.e?.t != dummy { w.dojoSetDummy(dummy) }
            w.hp = 9999; w.maxHP = 9999   // 웹 audit.mjs 와 같게(필살기 시연 뒤 체력 120 → 적 공격 시연에 죽는 것 방지)
            var ci = 0, trigDone = false
            var rows: [Row] = [], nev: [Int: [String]] = [:]
            var cueH: Int?, cueF: Int?
            var cells: [Int: ([UInt8], [UInt8])] = [:]
            // 보여 줄 표본: 큐 앞뒤 · 처음 45틱은 3틱(20fps), 그 뒤는 6틱 — 끝(가라앉음) + 6 까지
            let endT = min(win - 1, max(wCalm, 20) + 6), cue0 = wCueH ?? wCueF
            var want = Set(webShots.filter { i in i <= endT && (i < 45 || (cue0.map { abs(i - $0) <= 15 } ?? false) || (i + 1) % 6 == 0) })
            if let c = cue0 { want.insert(c) }
            for i in 0..<win {
                while ci < cmds.count && (cmds[ci][0] as! NSNumber).intValue == i {
                    let c = cmds[ci]; ci += 1
                    let k = c[1] as! String
                    func s(_ j: Int) -> String { c[j] as? String ?? "" }
                    func n(_ j: Int) -> Int? { (c[j] as? NSNumber)?.intValue }
                    switch k {
                    case "combo": w.dojoCombo(n(2)!)
                    case "hero": w.dojoHero(s(2), n(3))
                    case "misc": w.dojoMisc(s(2))
                    case "special": w.dojoSpc(s(2))
                    case "react": w.dojoReact(s(2))
                    case "foe": w.dojoFoe(s(2))
                    case "dummy": w.dojoSetDummy(s(2))
                    case "reset": w.dojoReset(24)
                    case "dummyX": if let D = w.dojoDummy(), let H = w.hero { D.x = Double(n(2)!); w.face(D, H.x) }
                    default: Issue.record("모르는 명령 \(k)")
                    }
                }
                if let tk = trig, !trigDone, let D = w.dojoDummy(), let H = w.hero, let Ac = D.action, !Ac.fired, let tt = w.timeToCue(D) {
                    if tk == "just" && tt <= 0.06 { trigDone = true; w.manual(D.x >= H.x ? 1 : -1) }
                    if tk == "duck" && tt <= 0.2 { trigDone = true; _ = w.heroDuck(true) }
                }
                let bD = w.dojoDummy()?.e?.hp ?? 0, bH = w.hp
                let r = step()
                let (fo, fn) = frames()
                let D = w.dojoDummy()
                if cueH == nil, let D, (D.e?.hp ?? 0) < bD - 1e-6 { cueH = i }
                if cueF == nil, w.hp < bH - 1e-6 { cueF = i }
                var row = Row()
                row.H = Self.actorRow(w.hero!); row.D = D.map(Self.actorRow); row.dhp = D?.e?.hp ?? 0; row.hp = w.hp
                row.freeze = w.freeze; row.shake = fo.shake; row.zoomK = dOff.camera.zoomK; row.invF = dOff.camera.invF; row.slowT = max(0, w.slowT); row.spcTime = w.spcTime
                row.camX = fo.view.cameraX; row.cut = w.cut?.k; row.spc = w.spc != nil; row.seq = w.dj?.seq?.i; row.canAct = w.canAct(w.hero!)
                rows.append(row)
                if !r.names.isEmpty { nev[i] = r.names }
                let draw = only.isEmpty || only.contains(name)
                if draw && (want.contains(i) || i == cueH || i == cueF) {
                    cells[i] = (try shot(dOff, fo, x0: x0, y0: y0), try shot(dOn, fn, x0: x0, y0: y0))
                }
            }
            // 끝(가라앉음) — 웹 audit.mjs runAction 과 같은 판정
            var calm = -1
            for k in stride(from: rows.count - 1, through: 0, by: -1) {
                let r = rows[k]
                let quiet = r.canAct && r.H.anim == "idle" && r.D != nil && r.D!.jug == nil && ["idle", "walk"].contains(r.D!.anim) && r.cut == nil && !r.spc && r.seq == nil
                if !quiet { calm = k + 1; break }
            }
            // 상태 비교
            var firstDiff: (Int, String)?, poseDiff: Set<Int> = []
            for (i, wr) in wrows.enumerated() where i < rows.count {
                let wH = Self.webActor(wr[1]), wD = Self.webActor(wr[2]), r = rows[i]
                if let h = wH, h.anim != r.H.anim || h.pose != r.H.pose { poseDiff.insert(i) }
                if let d = wD, let n = r.D, d.anim != n.anim || d.pose != n.pose { poseDiff.insert(i) }
                if firstDiff == nil {
                    var why: [String] = []
                    if let h = wH { if h.anim != r.H.anim || h.pose != r.H.pose { why.append("H \(h.anim)/\(h.pose)≠\(r.H.anim)/\(r.H.pose)") }
                        if abs(h.x - r.H.x) > 0.02 { why.append("H.x \(h.x)≠\(JSFormat.fixed(r.H.x, 2))") }
                        if h.hs != r.H.hs { why.append("H.hs \(h.hs)≠\(r.H.hs)") } }
                    if let d = wD, let n = r.D { if d.anim != n.anim || d.pose != n.pose { why.append("D \(d.anim)/\(d.pose)≠\(n.anim)/\(n.pose)") }
                        if abs(d.x - n.x) > 0.02 { why.append("D.x \(d.x)≠\(JSFormat.fixed(n.x, 2))") }
                        if (d.jug == nil) != (n.jug == nil) || abs((d.jug ?? 0) - (n.jug ?? 0)) > 0.02 { why.append("D.jug \(d.jug.map { "\($0)" } ?? "-")≠\(n.jug.map { JSFormat.fixed($0, 2) } ?? "-")") } }
                    if !why.isEmpty { firstDiff = (i, why.joined(separator: " · ")) }
                }
            }
            // 경직(hitstop) · 회복
            func hsSpan(_ get: (Int) -> Int) -> (max: Int, ticks: Int) { var m = 0, t = 0; for i in 0..<rows.count { let v = get(i); m = max(m, v); if v > 0 { t += 1 } }; return (m, t) }
            let nH = hsSpan { rows[$0].H.hs }, nD = hsSpan { rows[$0].D?.hs ?? 0 }
            let wH = hsSpan { Self.webActor(wrows[$0][1])?.hs ?? 0 }, wD = hsSpan { Self.webActor(wrows[$0][2])?.hs ?? 0 }
            // 연출 이벤트 비교(이름별 개수 · 첫 틱)
            func agg(_ m: [Int: [String]]) -> [String: (n: Int, first: Int)] {
                var o: [String: (n: Int, first: Int)] = [:]
                for (i, L) in m { for x in L { if let p = o[x] { o[x] = (p.n + 1, min(p.first, i)) } else { o[x] = (1, i) } } }
                return o
            }
            let aw = agg(wev), an = agg(nev)
            var onlyWeb: [String] = [], onlyNat: [String] = [], diffs: [String] = []
            for k in Set(aw.keys).union(an.keys).sorted() {
                switch (aw[k], an[k]) {
                case let (a?, nil): onlyWeb.append("\(k)×\(a.n)@\(a.first)")
                case let (nil, b?): onlyNat.append("\(k)×\(b.n)@\(b.first)")
                case let (a?, b?):
                    if k.hasPrefix("fx:streak") || k.hasPrefix("fx:drop") { if a.first != b.first { diffs.append("\(k) 첫 \(a.first)→\(b.first)") }; continue }   // 개수는 연출 난수
                    if a.n != b.n || a.first != b.first { diffs.append("\(k) \(a.n)@\(a.first)→\(b.n)@\(b.first)") }
                default: break
                }
            }
            func heroRuns(_ get: (Int) -> ActorRow?) -> [String] {
                var L: [String] = [], last = ""
                for i in 0..<rows.count { guard let a = get(i) else { continue }; let k = "\(a.anim):\(a.pose)"; if k != last { L.append("\(i):\(k)"); last = k } }
                return L
            }
            report.append([
                "name": name, "cat": A["cat"] as! String, "label": A["label"] as! String, "dummy": dummy, "t0": t0,
                "cue": ["webHero": wCueH as Any, "natHero": cueH as Any, "webFoe": wCueF as Any, "natFoe": cueF as Any],
                "calm": ["web": wCalm, "nat": calm],
                "firstDiff": firstDiff.map { ["tick": $0.0, "why": $0.1] } as Any,
                "poseDiffTicks": poseDiff.count,
                "hitstop": ["webHero": [wH.max, wH.ticks], "natHero": [nH.max, nH.ticks], "webDummy": [wD.max, wD.ticks], "natDummy": [nD.max, nD.ticks]],
                "heroRunsWeb": heroRuns { Self.webActor(wrows[$0][1]) }, "heroRunsNat": heroRuns { rows[$0].H },
                "dummyRunsWeb": heroRuns { Self.webActor(wrows[$0][2]) }, "dummyRunsNat": heroRuns { rows[$0].D },
                "eventsWeb": wev.keys.sorted().map { ["t": $0, "e": wev[$0]!] }, "eventsNat": nev.keys.sorted().map { ["t": $0, "e": nev[$0]!] },
                "onlyWeb": onlyWeb, "onlyNat": onlyNat, "diffs": diffs,
                "maxShake": [rows.map(\.shake).map(abs).max() ?? 0, wrows.map { abs(($0[7] as? NSNumber)?.doubleValue ?? 0) }.max() ?? 0],
                "maxZoom": [rows.map(\.zoomK).max() ?? 0, wrows.map { ($0[8] as? NSNumber)?.doubleValue ?? 0 }.max() ?? 0],
            ])
            func c(_ v: Int?) -> String { v.map(String.init) ?? "-" }
            let cueS = (wCueH != nil || cueH != nil) ? "\(c(wCueH))/\(c(cueH))" : "\(c(wCueF))/\(c(cueF))(피격)"
            md += "| \(name) | \(A["cat"] as! String) | \(cueS) | \(wCalm)/\(calm) | \(firstDiff.map { "\($0.0): \($0.1)" } ?? "없음") | \(poseDiff.count) | \(onlyWeb.joined(separator: " ")) | \(onlyNat.joined(separator: " ")) | \(diffs.joined(separator: " · ")) |\n"

            // 접촉 띠 그림
            guard only.isEmpty || only.contains(name), let webImg = CGImageSourceCreateWithURL(webDir.appending(path: "\(name).png") as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else { continue }
            let ticks = Array(Set(cells.keys)).sorted()
            let ow = cw * sc, oh = ch * sc, left = 120, band = 60, head = 96, nRow = (ticks.count + per - 1) / per
            let IW = left + per * ow, IH = head + nRow * (3 * oh + band)
            let ctx = CGContext(data: nil, width: IW, height: IH, bitsPerComponent: 8, bytesPerRow: IW * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.setFillColor(CGColor(gray: 0.08, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: IW, height: IH))
            func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> CGRect { CGRect(x: x, y: IH - y - h, width: w, height: h) }
            let title = "\(name) · \(A["label"] as! String)\(dummy != "punk" ? " · 상대 \(dummy)" : "")   큐 웹/네이티브 \(cueS) · 끝 \(wCalm)/\(calm) 틱(60Hz, 동작 시작=0)"
            Self.text(ctx, title, x: 12, y: 34, H: IH, bold: true)
            Self.text(ctx, "경직(hs 최대·틱) 주인공 웹 \(wH.max)·\(wH.ticks) / 네이티브 \(nH.max)·\(nH.ticks) · 상대 웹 \(wD.max)·\(wD.ticks) / 네이티브 \(nD.max)·\(nD.ticks) · 상태 첫 어긋남: \(firstDiff.map { "\($0.0) \($0.1)" } ?? "없음")", x: 12, y: 60, H: IH)
            Self.text(ctx, "웹에만: \(onlyWeb.prefix(8).joined(separator: " "))   네이티브에만: \(onlyNat.prefix(8).joined(separator: " "))", x: 12, y: 84, H: IH, color: CGColor(red: 1, green: 0.8, blue: 0.5, alpha: 1))
            for (j, t) in ticks.enumerated() {
                let gx = left + (j % per) * ow, gy0 = head + (j / per) * (3 * oh + band)
                if j % per == 0 {
                    for (r, lab) in ["웹", "네이티브", "강화 켬"].enumerated() { Self.text(ctx, lab, x: 8, y: Double(gy0 + r * oh + oh / 2), H: IH, bold: true) }
                }
                if let wk = webShots.firstIndex(of: t), let cim = webImg.cropping(to: CGRect(x: (wk % per) * ow, y: (wk / per) * oh, width: ow, height: oh)) {
                    ctx.draw(cim, in: rect(gx, gy0, ow, oh))
                }
                if let (a, b) = cells[t] { ctx.draw(Self.image(a, w: ow, h: oh), in: rect(gx, gy0 + oh, ow, oh)); ctx.draw(Self.image(b, w: ow, h: oh), in: rect(gx, gy0 + 2 * oh, ow, oh)) }
                let isCue = t == wCueH || t == wCueF || t == cueH || t == cueF
                ctx.setLineWidth(4)
                if isCue { ctx.setStrokeColor(CGColor(red: 1, green: 0.15, blue: 0.1, alpha: 1)); ctx.stroke(rect(gx + 2, gy0 + 2, ow - 4, 3 * oh - 4)) }
                if poseDiff.contains(t) { ctx.setStrokeColor(CGColor(red: 1, green: 0.9, blue: 0, alpha: 1)); ctx.stroke(rect(gx + 6, gy0 + oh + 4, ow - 12, oh - 8)) }
                ctx.setStrokeColor(CGColor(gray: 0.3, alpha: 1)); ctx.setLineWidth(1); ctx.stroke(rect(gx, gy0, ow, 3 * oh))
                let r = rows[t]
                Self.text(ctx, "\(t) (\(JSFormat.fixed(Double(t) / 60, 3))s)\(isCue ? " ★큐" : "")  H \(r.H.pose)\(r.H.hs > 0 ? " hs\(r.H.hs)" : "")", x: Double(gx + 6), y: Double(gy0 + 3 * oh + 18), H: IH,
                          color: isCue ? CGColor(red: 1, green: 0.5, blue: 0.4, alpha: 1) : CGColor(gray: 0.92, alpha: 1))
                Self.text(ctx, "D \(r.D?.anim ?? "-"):\(r.D?.pose ?? "-")\(r.D?.jug.map { " h\(Int($0))" } ?? "")", x: Double(gx + 6), y: Double(gy0 + 3 * oh + 36), H: IH)
                let we = (max(0, t - 2)...t).flatMap { wev[$0] ?? [] }.filter { !$0.hasPrefix("fx:streak") && !$0.hasPrefix("fx:drop") }
                Self.text(ctx, Array(Set(we)).sorted().prefix(4).joined(separator: " "), x: Double(gx + 6), y: Double(gy0 + 3 * oh + 54), H: IH, color: CGColor(gray: 0.65, alpha: 1))
            }
            let url = Self.out.appending(path: "\(name).png")
            let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        }
        let rd = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try rd.write(to: Self.out.appending(path: "report.json"))
        try md.write(to: Self.out.appending(path: "summary.md"), atomically: true, encoding: .utf8)
        print("[audit] \(report.count) 동작 → \(Self.out.path)")
    }

    /// 깃발 켜짐(SimConfig.nativeMoves — 앱 기본) 짧은 점검: 새 복싱 기술 · 막차 러시(뎀프시) · 이동 판단. 웹 대조가 없어 [강화 끔 | 강화 켬] 두 줄만.
    /// BB_AUDIT_NV=1 → tools/js/out/audit/nv/<동작>.png · nv/report.json(주인공 자세 흐름 · 큐 틱 · 이동 상태)
    @Test("깃발 켜짐: 새 기술 · 러시 · 이동(BB_AUDIT_NV=1)") func auditNativeMoves() throws {
        guard ProcessInfo.processInfo.environment["BB_AUDIT_NV"] == "1" else { return }
        let store = try ContentStore.bundled(), data = try SimData(store: store, nativeMoves: true), content = try SceneContent.bundled()
        func director(_ st: MotionStyle) throws -> StageDirector {
            let d = try StageDirector(content: content, store: store, tables: data.animTables, catalog: HUDCatalog(data), heavyReactions: data.heavyRK, style: st)
            d.hud.art = try HUDArt(store: store); d.hud.playSpeed = 1; d.playSpeed = 1; return d
        }
        let dOff = try director(.off), dOn = try director(.on)
        let device = try #require(MTLCreateSystemDefaultDevice()), q = try #require(device.makeCommandQueue())
        let fr = try FrameRenderer(device: device, atlas: try AtlasMeta.bundled()), ov = try OverlayRenderer(device: device)
        let tg = try FrameRenderer.Targets(device: device, width: 480, height: 270)
        var cfg = SimConfig(); cfg.playSpeed = 1; cfg.skipTalks = true; cfg.mode = .dojo; cfg.nativeMoves = true
        let sim = Sim(data: data, seed: 9311, config: cfg); sim.apply(.setSpeed(1))
        let w = sim.w
        let out = Self.out.appending(path: "nv"); try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        typealias Cmd = (Int, (World) -> Void)
        let hero: (String) -> [Cmd] = { id in [(0, { $0.dojoReset(24) }), (0, { $0.dojoHero(id, nil) })] }
        let far: (Double, String) -> [Cmd] = { dx, id in [(0, { $0.dojoReset(24) }), (0, { w in if let D = w.dojoDummy(), let H = w.hero { D.x = 250 + dx; w.face(D, H.x) } }), (1, { $0.dojoHero(id, id == "punch" ? 0 : nil) })] }
        let list: [(String, [Cmd], Int)] = [
            ("nv_flick", hero("nv_flick"), 150), ("nv_liver", hero("nv_liver"), 200), ("nv_cork", hero("nv_cork"), 220), ("upper_nv", hero("upper"), 220),
            ("nv_roll", hero("nv_roll"), 200), ("nv_rise", hero("nv_rise"), 200), ("spc_fist_rush", [(0, { $0.dojoSpc("fist") })], 480),
            ("dojo_stomp", hero("stomp"), 200), ("dojo_cycle", hero("cycle"), 200), ("dojo_fkick", hero("fkick"), 160),
            ("dojo_polespin", [(0, { $0.dojoMisc("polespin") })], 90), ("dojo_hangkick", [(0, { $0.dojoMisc("hangkick") })], 90),
            ("dojo_rSpike", [(0, { $0.dojoReact("rSpike") })], 110), ("dojo_fall", [(0, { $0.dojoReact("fall") })], 90),
            ("move_40", far(40, "kick"), 200), ("move_70", far(70, "kick"), 220), ("move_140", far(140, "kick"), 260), ("move_150_jab", far(150, "punch"), 260),
            ("nv_kneelift", hero("nv_kneelift"), 200), ("nv_duckup", hero("nv_duckup"), 220),   // 버추어 파이터 참고 두 기술(docs/07 §7-VF) — 끝에 붙여 앞 항목 결과는 그대로
        ]
        for _ in 0..<30 { let ev = sim.step(), s = sim.snapshot; _ = dOff.apply(ev, snapshot: s, now: 0); _ = dOn.apply(ev, snapshot: s, now: 0); _ = dOff.frame(s, dt: 1.0 / 60, now: 0); _ = dOn.frame(s, dt: 1.0 / 60, now: 0) }
        var rep: [[String: Any]] = []
        let cw = 208, ch = 124, sc = 2, per = 10, ow = cw * sc, oh = ch * sc
        for (name, cmds, win) in list {
            w.hp = 9999; w.maxHP = 9999
            var cells: [(Int, [UInt8], [UInt8], String)] = [], runs: [String] = [], last = "", cue: Int?, modes: [String] = [], lastMode = -1
            var cx = 0, gy = 0
            for i in 0..<win {
                for c in cmds where c.0 == i { c.1(w) }
                let bD = w.dojoDummy()?.e?.hp ?? 0
                let ev = sim.step(), s = sim.snapshot, now = Double(i) / 60
                _ = dOff.apply(ev, snapshot: s, now: now); _ = dOn.apply(ev, snapshot: s, now: now)
                let fo = dOff.frame(s, dt: 1.0 / 60, now: now), fn = dOn.frame(s, dt: 1.0 / 60, now: now)
                let H = w.hero!, D = w.dojoDummy()
                if i == 0 { cx = Int(((H.x + (D?.x ?? H.x)) / 2).rounded()); gy = Int(H.y.rounded()) }
                if cue == nil, let D, (D.e?.hp ?? 0) < bD - 1e-6 { cue = i }
                let k = "\(H.anim):\(H.pose)"; if k != last { runs.append("\(i):\(k)"); last = k }
                let m = H.nvm.mode; if m != lastMode { modes.append("\(i):\(["서기", "걷기", "질주", "미끄러짐"][min(3, m)])"); lastMode = m }
                if i % 3 == 2 && cells.count < 60 {
                    let x0 = max(0, min(480 - cw, cx - cw / 2)), y0 = max(0, min(270 - ch, gy - 112))
                    func shot(_ d: StageDirector, _ f: StageFrame) throws -> [UInt8] {
                        var rf = RenderFrame(stage: f, atlas: content.sprites); rf.applyHUD(d.hud.state, now: s.time)
                        let cb = try #require(q.makeCommandBuffer()); try fr.encode(rf, targets: tg, into: cb); cb.commit(); cb.waitUntilCompleted()
                        let scene = try fr.readBack(tg.output(for: rf), queue: q)
                        let F = d.hud.frame(s, view: f.view, shake: f.shake), L = HUDOverlay.build(d.hud.state, F, art: d.hud.art!)
                        return Self.composite(scene: scene, ui: try ov.render(L, atlas: d.hud.art!.atlas, queue: q), uiW: L.width, uiH: L.height, camX: f.view.cameraX, x0: x0, y0: y0, cw: cw, ch: ch, sc: sc)
                    }
                    cells.append((i, try shot(dOff, fo), try shot(dOn, fn), "\(H.pose)\(D.map { " / \($0.pose)" } ?? "")"))
                }
            }
            rep.append(["name": name, "cue": cue as Any, "heroRuns": runs, "moveModes": modes])
            let left = 120, band = 40, head = 50, nRow = (cells.count + per - 1) / per, IW = left + per * ow, IH = head + nRow * (2 * oh + band)
            let ctx = CGContext(data: nil, width: IW, height: IH, bitsPerComponent: 8, bytesPerRow: IW * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.setFillColor(CGColor(gray: 0.08, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: IW, height: IH))
            Self.text(ctx, "\(name) · 깃발 켜짐(nativeMoves) · 큐 \(cue.map(String.init) ?? "-") · 이동 \(modes.joined(separator: " "))", x: 12, y: 34, H: IH, bold: true)
            for (j, c) in cells.enumerated() {
                let gx = left + (j % per) * ow, gy0 = head + (j / per) * (2 * oh + band)
                if j % per == 0 { Self.text(ctx, "강화 끔", x: 8, y: Double(gy0 + oh / 2), H: IH, bold: true); Self.text(ctx, "강화 켬", x: 8, y: Double(gy0 + oh + oh / 2), H: IH, bold: true) }
                ctx.draw(Self.image(c.1, w: ow, h: oh), in: CGRect(x: gx, y: IH - gy0 - oh, width: ow, height: oh))
                ctx.draw(Self.image(c.2, w: ow, h: oh), in: CGRect(x: gx, y: IH - gy0 - 2 * oh, width: ow, height: oh))
                Self.text(ctx, "\(c.0) \(c.3)", x: Double(gx + 6), y: Double(gy0 + 2 * oh + 20), H: IH, color: c.0 >= (cue ?? 9999) && c.0 < (cue ?? 9999) + 3 ? CGColor(red: 1, green: 0.5, blue: 0.4, alpha: 1) : CGColor(gray: 0.92, alpha: 1))
            }
            let dst = CGImageDestinationCreateWithURL(out.appending(path: "\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
        }
        try JSONSerialization.data(withJSONObject: rep, options: [.prettyPrinted]).write(to: out.appending(path: "report.json"))
    }
}
