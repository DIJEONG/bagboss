import Testing
import Foundation
@testable import BBSim
import BBContent
@testable import BBAnim

/// 네이티브 새 적(스파링꾼 · 라인배커 · 신문팔이 소년) · 무도장 상대 추가 검사 — 깃발(nativeMoves) 켠 쪽만 바뀐다.
///  ① 콘텐츠 분리(끈 쪽은 웹 그대로 · 켠 쪽 노선 웨이브 크기 동일) ② 실전 등장 · 공격(신문 뭉치 투사체) ③ 생김새 모델 · 몸 크기 · 색 겹침 없음
///  ④ 무도장 상대 6종 ⑤ 밸런스(새 적 넣기 전/후 — BB_NV_STATS=1 이면 표본을 늘리고 tools/js/out/enemies/balance.md)
@Suite struct NativeEnemiesTests {
    static let base = SimRunTests.data
    static let on = base.variant(nativeMoves: true)
    static let ids = NativeContent.enemyIDs
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // MARK: ① 콘텐츠

    @Test func contentSplit() throws {
        #expect(Self.ids == ["nv_spar", "nv_lineback", "nv_newsboy"])
        for id in Self.ids { #expect(Self.base.game.enemies[id] == nil); #expect(Self.on.game.enemies[id] != nil) }
        #expect(Array(Self.on.game.enemies.keys.prefix(Self.base.game.enemies.count)) == Self.base.game.enemies.keys)   // 웹 순서 그대로 뒤에
        #expect(try GameContent(Self.base.store).stages == Self.base.game.stages)                                      // 끈 쪽 노선 = 생성물
        for (a, b) in zip(Self.base.game.stages, Self.on.game.stages) {
            #expect(a.key == b.key && a.line.count == b.line.count && a.reinf == b.reinf)
            for (x, y) in zip(a.line, b.line) {   // 바꿔 넣기만 — 웨이브 수 · 크기 · 짧은 정차 수는 같다(난수 소비 수 그대로)
                #expect(x.waves.map(\.count) == y.waves.map(\.count))
                #expect(x.fight?.count == y.fight?.count && x.quick?.count == y.quick?.count)
            }
        }
        // 바꾸기가 하나도 건너뛰어지지 않았다(자리 번호가 맞다)
        for P in NativeContent.stagePatches {
            let S = Self.on.game.stages.first { $0.key == P.stage }!
            switch P.target {
            case .wave(let c, let w): #expect(S.line[c].waves[w] == P.types)
            case .fight(let c): #expect(S.line[c].fight == P.types)
            case .quick(let c, let k): #expect(S.line[c].quick?[k].array?[2].array?.compactMap(\.string) == P.types)
            case .reinf: #expect(S.reinf == P.types)
            }
        }
        // 새 적은 모두 어딘가에 나온다
        for id in Self.ids { #expect(Self.on.game.stages.contains { S in S.line.contains { $0.waves.joined().contains(id) || ($0.fight ?? []).contains(id) } }) }
    }

    // MARK: ② 실전 등장 · 공격

    struct Fight { var moves = Set<String>(), news = 0, taken = 0.0, look = "" }
    /// 첫 칸 싸움에서 기존 적을 치우고 t 하나만 세워 seconds 동안 — 체력은 넉넉히(공격을 다 보려고)
    static func fight(_ t: String, seconds: Double = 30, seed: UInt32 = 3) -> Fight {
        var c = SimRunTests.harnessConfig(); c.nativeMoves = true; c.nativeGuard = false   // 공방 층(docs/08)은 따로 검사 — 여기는 새 적의 공격 종류만
        let sim = Sim(data: on, seed: seed, config: c), w = sim.w
        for _ in 0..<400 { sim.step(); if w.state == "fight" && w.legT > 2 { break } }
        w.ents = w.ents.filter { $0.e == nil }; w.nextWaveAt = 1e9; w.maxHP = 9999; w.hp = 9999
        w.spawnWave([t], fromDoors: false)
        var r = Fight()
        guard let A = w.foes().first(where: { $0.e?.t == t }) else { return r }
        A.e!.hp = 9999; A.e!.max = 9999; r.look = A.def.look ?? ""
        let hp0 = w.hp
        for _ in 0..<Int(seconds * 60) {
            sim.step(); w.nextWaveAt = 1e9
            if let m = A.lastMove { r.moves.insert(m) }
            r.news += w.shots.filter { $0.kind == "news" && $0.t < 1.0 / 30 }.count
            if w.hp < 2000 { w.hp = 9999 }
        }
        r.taken = hp0 - w.hp
        return r
    }

    @Test func spawnAndAttack() {
        let s = Self.fight("nv_spar")
        #expect(s.look.hasPrefix("nv_spar|"))
        #expect(s.moves.contains("jab") && (s.moves.contains("hook") || s.moves.contains("upper")), Comment(rawValue: "\(s.moves)"))
        let l = Self.fight("nv_lineback")
        #expect(l.look.hasPrefix("nv_lineback|"))
        #expect(l.moves.contains("hbutt") || l.moves.contains("charge"), Comment(rawValue: "\(l.moves)"))
        let n = Self.fight("nv_newsboy")
        #expect(n.look.hasPrefix("nv_newsboy|"))
        #expect(n.news > 0, Comment(rawValue: "신문 뭉치를 던진다 \(n.moves)"))
    }

    /// 신문 뭉치는 병보다 약하다(5 vs 7) · 깃발이 꺼지면 병만 있다
    @Test func paperShotIsLighter() {
        func hit(_ kind: String) -> Double {
            var c = SimRunTests.harnessConfig(); c.nativeMoves = true
            let sim = Sim(data: Self.on, seed: 11, config: c), w = sim.w
            for _ in 0..<400 { sim.step(); if w.state == "fight" && w.legT > 2 { break } }
            w.ents = w.ents.filter { $0.e == nil }; w.nextWaveAt = 1e9
            let H = w.hero!, hp0 = w.hp
            w.shots = [Shot(x: H.x + 20, y: H.y - 52, vx: -150, kind: kind)]
            w.manualT = 9   // 자동 쭈그리기 끔
            for _ in 0..<30 { sim.step() }
            return hp0 - w.hp
        }
        let b = hit(""), p = hit("news")
        #expect(p > 0 && p < b, Comment(rawValue: "병 \(b) · 신문 \(p)"))
    }

    // MARK: ③ 생김새

    @Test func looksBuildAndDiffer() throws {
        let w = Sim(data: Self.on, seed: 1, config: SimRunTests.harnessConfig()).w
        var sigs: [String: String] = [:]
        let tables = Self.on.animTables
        func sig(_ m: Model3, remap: Int) -> String {   // 머리 · 몸통 재질 묶음(재질 바꾸기 적용) — 실루엣 색 서명
            ["head", "torso", "thighF"].map { k in Set((m[k] ?? []).map { tables.remapMaterial(remap, $0.mat) }).sorted().map { String(Int($0)) }.joined(separator: ",") }.joined(separator: "/")
        }
        for (k, T) in Self.on.game.enemies.ordered {
            let L = LookSpec(key: w.defFor(T, 0).look ?? "") ?? LookSpec()
            sigs[k] = sig(CharacterModels.look(L), remap: T.remap)
        }
        for id in Self.ids {
            let L = LookSpec(key: w.defFor(Self.on.game.enemies[id]!, 0).look!)!
            #expect(NativeLooks.hairs.contains(L.hair ?? ""))
            let m = CharacterModels.look(L)
            #expect(m != noirModel(L.options))
            #expect((m["head"]?.count ?? 0) > 6 && m["skirtF"]?.isEmpty == true)
            // 다른 어떤 적과도 머리 · 몸통 · 다리 재질 묶음이 겹치지 않는다
            let other = sigs.filter { $0.key != id && $0.value == sigs[id] }.map(\.key)
            #expect(other.isEmpty, Comment(rawValue: "\(id) 색 서명이 \(other) 와 같다"))
        }
        // 몸 크기: 신문팔이 0.8 · 라인배커 1.08 — 리그 · 모델 같은 배율, 발(0) 기준
        #expect(NativeLooks.scale(hair: "nv_newsboy") == 0.8 && NativeLooks.scale(hair: "nv_lineback") == 1.08 && NativeLooks.scale(hair: "nv_spar") == nil)
        let R = Self.on.heroRig, R2 = NativeLooks.scaled(R, 0.8)
        #expect(abs(R2.hip - R.hip * 0.8) < 1e-9 && abs((R2.sc ?? 0) - (R.sc ?? 1) * 0.8) < 1e-9 && abs((R2.thigh ?? 0) - (R.thigh ?? 6) * 0.8) < 1e-9)
        let small = CharacterModels.look(LookSpec(key: "nv_newsboy|||||")!), raw = NativeLooks.newsboy()
        #expect(abs(small["head"]![1].c.y - raw["head"]![1].c.y * 0.8) < 1e-9)
        #expect(NativeLooks.scale(lookKey: "nv_newsboy||WOOD|||") == 0.8 && NativeLooks.scale(lookKey: "pomp||COAT|||") == nil)
    }

    // MARK: ④ 무도장 상대

    @Test func dojoOpponents() {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        let list = w.sd.djDummy.map(\.0)
        #expect(Array(list.prefix(4)) == ["punk", "heavy", "brute", "boss4"])   // 웹 목록이 앞
        for (k, _) in NativeContent.dojoDummies {
            #expect(list.contains(k))
            sim.apply(.dojo(.dummy(k))); DojoNativeTests.run(sim, 5)
            #expect(w.dojoDummy()?.e?.t == k)
            #expect(w.dojoDummy()?.e?.dojoOff == true)   // 허수아비는 막기 · 피하기를 끈다(스파링꾼 evade · parry 도)
        }
        sim.apply(.dojo(.dummy("nv_spar"))); sim.apply(.dojo(.foe("hook"))); DojoNativeTests.run(sim, 90)
        #expect(w.dojoDummy()?.e?.t == "nv_spar")
        // 깃발 끔: 웹 목록 그대로 · 새 적은 못 고른다
        let off = DojoNativeTests.dojo(false)
        #expect(off.w.sd.djDummy.map(\.0) == ["punk", "heavy", "brute", "boss4"])
        off.apply(.dojo(.dummy("nv_spar"))); DojoNativeTests.run(off, 5)
        #expect(off.w.dojoDummy()?.e?.t != "nv_spar")
    }

    // MARK: ⑤ 밸런스

    struct Res { var alive = 0.0, kills = 0.0, taken = 0.0, ci = 0.0 }
    static func run(_ data: SimData, seed: UInt32, seconds: Double, stage: Int) -> Res {
        var c = SimRunTests.harnessConfig(stage: stage); c.nativeMoves = true; c.autoSpecial = true
        let sim = Sim(data: data, seed: seed, config: c)
        for _ in 0..<Int(seconds * 60) { sim.step(); if sim.state == "over" || sim.state == "end" { break } }
        let s = sim.snapshot
        return Res(alive: s.hp > 0 ? 1 : 0, kills: Double(s.kills), taken: s.stats.taken, ci: Double(s.car))
    }

    @Test func balanceHolds() throws {
        let big = ProcessInfo.processInfo.environment["BB_NV_STATS"] == "1"
        let before = try SimData(store: Self.base.store, nativeMoves: true, nativeFoes: false)
        // (이름, 판 수, 초, 노선 인덱스 — STAGES 순서 D · 4 · 6 · 7 · L)
        let sets: [(String, Int, Double, Int)] = big
            ? [("D 노선 240초", 40, 240, 0), ("4 노선 240초", 30, 240, 1), ("7 노선 240초", 30, 240, 3), ("L 노선 240초", 30, 240, 4)]
            : [("D 노선 150초", 8, 150, 0), ("7 노선 150초", 6, 150, 3)]
        var md = "| 묶음 | 지표 | 새 적 전 | 새 적 후 | z |\n|---|---|---:|---:|---:|\n"
        for (name, n, sec, st) in sets {
            var A: [Res] = [], B: [Res] = []
            for k in 0..<n { let seed = UInt32(7000 + k * 13); A.append(Self.run(before, seed: seed, seconds: sec, stage: st)); B.append(Self.run(Self.on, seed: seed, seconds: sec, stage: st)) }
            for (key, f) in [("처치", \Res.kills), ("받은 피해", \Res.taken), ("생존율", \Res.alive), ("도달 칸", \Res.ci)] as [(String, KeyPath<Res, Double>)] {
                let a = A.map { $0[keyPath: f] }, b = B.map { $0[keyPath: f] }
                func ms(_ v: [Double]) -> (Double, Double) { let m = v.reduce(0, +) / Double(v.count); return (m, sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(1, v.count - 1)))) }
                let (am, asd) = ms(a), (bm, bsd) = ms(b)
                let se = sqrt((asd * asd + bsd * bsd) / Double(n)), z = se > 0 ? (bm - am) / se : 0
                md += "| \(name) (\(n)판) | \(key) | \(String(format: "%.2f ± %.2f", am, asd)) | \(String(format: "%.2f ± %.2f", bm, bsd)) | \(String(format: "%+.2f", z)) |\n"
                if key == "생존율" { #expect(abs(bm - am) <= 0.3, Comment(rawValue: "\(name) \(key) \(am) → \(bm)")) }
                else if key != "도달 칸" { #expect(abs(bm - am) <= max(4, am * 0.35) || abs(z) < 2, Comment(rawValue: "\(name) \(key) \(am) → \(bm) · z \(z)")) }   // 8판 표본: 유의하지 않은 차(|z| < 2)는 잡음
            }
        }
        print(md)
        if big {
            let url = Self.root.appending(path: "tools/js/out/enemies/balance.md")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try md.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
