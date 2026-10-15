import Foundation
import BBContent
import BBAnim
import BBSim

// 인물 층(웹 render() 의 그림자 → drawChar(y 순) → 승객 소품). 애니메이션 상태는 시뮬레이션이 가진다:
//   스냅숏 ActorView.pose(동작 · 칸 · 보폭 …)를 그대로 받아 그리기 상태(블렌드 · 추종 · gres)만 여기서 이어 간다.
//   인물마다 CharacterRig 를 ActorID 로 붙잡아 두어 SecondaryMotion(강화 스프링) 상태가 프레임을 넘어 이어진다.
// 생김새(웹 defFor · LOOK_CACHE · PASS_MODEL · skinModel)는 BBAnim/Models 로 만든다 — modelFor(_:) 참고.

public struct CharacterLayer: Sendable {
    /// 그림자 쿼드(곱하기 블렌드 층)
    public var shadows: [SpriteDraw] = []
    /// 3D 리그 정점(MeshWriter.floats — 정점당 10 float)
    public var mesh: [Float] = []
    public var meshVertexCount: Int { mesh.count / 10 }
    /// 인물 뒤 앞 소품(신문 · 휴대폰)
    public var props: [SpriteDraw] = []
    /// 인물이 내는 동적 광원(휴대폰 화면)
    public var lights: [SceneLight] = []
    /// 그린 인물들 관절(타격 위치 · 말풍선 기준) — 머리 위치(장면 픽셀)
    public var heads: [ActorID: SIMD2<Double>] = [:]
    /// 그린 눈 자리(장면 픽셀 — CharacterRig.eyePoint · 야근 광선 출발점)
    public var eyes: [ActorID: SIMD2<Double>] = [:]
    /// 입 위치(장면 픽셀) · 앞 방향(단위 — 몸 기울기 반영). 머리뼈는 턱 밑에 있다 → 위로 3.5 · 앞으로 4.5(리그 배율) — 눈 승강장 입김
    public var mouths: [ActorID: (p: SIMD2<Double>, fwd: SIMD2<Double>)] = [:]
    /// 인물마다 mesh 안 float 범위(타격감 묶음 — 찌그러짐 · 달아오름이 그 인물 정점만 고친다, docs/11)
    public var ranges: [ActorID: Range<Int>] = [:]
}

public final class CharacterStage {
    public var style: MotionStyle
    /// 네이티브 발밑 접지 그림자(강화 켜짐에서만): 땅에 닿으면 발밑 가운데를 한 겹 더 짙게 · 뜨면 작은 그림자로(높을수록 · 웹은 늘 큰 그림자)
    public var contactShadow = true
    let tables: AnimTables
    private var defs: [String: CharacterDef] = [:]
    private var rigs: [ActorID: CharacterRig] = [:]
    private let store: ContentStore
    /// 생김새 모델 캐시(웹 LOOK_CACHE · SKIN_CACHE)
    private var models = CharacterModelCache()
    /// 인물마다 지금 쓰는 모델 열쇠(바뀌면 리그의 모델을 갈아 끼운다 — 스킨 바꾸기)
    private var modelKeys: [ActorID: String] = [:]
    /// 주인공 스킨(웹 OPT.skin — jw · gala · rain · chicago). 앱이 옵션에서 넣는다
    public var heroSkin: String = "jw"
    static let downPoses: Set<String> = ["kd3", "kd4", "kd5", "stp0", "slm0", "sp_hit", "sp_bounce", "sp_land", "sp_lie"]

    public init(store: ContentStore, tables: AnimTables, style: MotionStyle = .on) throws {
        self.store = store; self.tables = tables; self.style = style
        for k in ["JW_HERO", "JW_THUG", "JW_BOSS", "NOIR_THUG"] { defs[k] = try CharacterDef.load(store, k) }
    }

    public var liveRigs: Int { rigs.count }

    private func def(_ key: String) -> CharacterDef? {
        if let d = defs[key] { return d }
        if let d = try? CharacterDef.load(store, key) { defs[key] = d; return d }
        return defs["JW_THUG"]
    }

    /// 인물 모델 고르기(웹 mkActor 에 넘기는 def.model3):
    ///   적 · 장치 인물 생김새(look 열쇠) → defFor 모델 · 승객(NOIR_THUG) → PASS_MODEL · 주인공(jw 정의) → 스킨 · 그 밖 → 정의 기본 모델
    func modelFor(_ a: SimSnapshot.ActorView, def d: CharacterDef) -> (key: String, model: Model3) {
        if let L = a.look, let m = models.look(key: L) { return ("look:" + L, m) }
        if a.isHero && d.jw == true { return ("skin:" + heroSkin, models.skin(heroSkin)) }
        if let i = a.passModel {   // 웹 PASS_MODEL[k%3](enterCar) · [(k+GS.uid)%3](boardAt) — BBSim 이 만들 때 정한 번호
            return ("pass:\(i)", models.passenger(i))
        }
        return ("def:" + a.def, d.model3)
    }

    /// 한 화면 프레임 인물 층. dt = 화면 프레임 길이(강화 스프링) · time = 게임 시계(웹 gameTime)
    /// zBack = 인물별 깊이(GL z) 밀기 — 네이티브 지붕 뚫기로 천장을 뚫고 나가는 몸을 천장 앞 입술 뒤로(NativeRiseArt)
    public func build(_ s: SimSnapshot, dt: Double, zBack: [ActorID: Double] = [:]) -> CharacterLayer {
        var out = CharacterLayer()
        var w = MeshWriter()
        var seen = Set<ActorID>()
        // 웹: ACT().slice().sort((a,b)=>a.d.y-b.d.y) — 안정 정렬
        let order = s.actors.enumerated().sorted { l, r in l.element.y != r.element.y ? l.element.y < r.element.y : l.offset < r.offset }.map(\.element)
        var shadowList: [(Double, Double, Bool)] = []   // (x, y, small) — 그림자는 원래 순서(ACT())로 그린다
        var drawnX: [ActorID: Double] = [:]
        var zRanges: [(Int, Int, Float)] = []
        let riseOn = s.actors.contains { $0.isHero && $0.pose.anim == "nv_rise" }
        for a in order {
            seen.insert(a.id)
            guard !a.hidden, let d = def(a.def) else { continue }
            let mk = modelFor(a, def: d)
            var rig = rigs[a.id] ?? {
                var r = CharacterRig(model: mk.model, rig: d.rig, traits: ActorTraits(gait: d.gait ?? false, jw: d.jw ?? false, isHero: a.isHero),
                                     actor: a.pose, x: a.x, y: a.y, flip: a.flip)
                r.hasFace = d.face ?? false
                return r
            }()
            if modelKeys[a.id] != mk.key {
                rig.model = mk.model; modelKeys[a.id] = mk.key
                // 네이티브 전용 적의 몸 크기(신문팔이 소년 0.8 · 라인배커 1.08) — 모델과 같은 배율로 리그 치수를 바꾼다
                let k = a.look.flatMap { NativeLooks.scale(lookKey: $0) }
                rig.rig = k.map { NativeLooks.scaled(d.rig, $0) } ?? d.rig
            }
            // 시뮬레이션이 정하는 값만 덮는다(그리기 상태 vr · va · 블렌드 · lastPose · gres 는 이어 간다)
            var p = rig.actor, q = a.pose
            p.anim = q.anim; p.pose = q.pose; p.prev = q.prev; p.k = q.k; p.phaseN = q.phaseN
            p.gph = q.gph; p.guardW = q.guardW; p.runU = q.runU; p.legRun = q.legRun
            p.hasJug = q.hasJug; p.jugRoll = q.jugRoll; p.jugKick = q.jugKick; p.airOv = q.airOv; p.tilt = q.tilt
            // 스킨 미리보기 · 자세 편집기: 한 바퀴 돌기(spin) + 보기 회전(view°) — 웹 17-light-frame(P.spin += view/360) · charBones(+ skinPv.spin)
            p.viewSpin = a.isHero ? s.skinPv.map { $0.view / 360 + $0.spin } : nil
            // 웹 drawChar: 정지 중 떨림 — 땅에선 가로, 공중에선 세로
            var x = a.x
            if a.shake != 0 { if q.hasJug || (q.airOv ?? 0) > 2 { p.airOv = (p.airOv ?? 0) + a.shake } else { x += a.shake } }
            rig.actor = p
            // 네이티브 퇴근 승천권(nv_rise 는 깃발 켜짐에만 있다): 맞은 적 온몸 흰 번쩍임을 끈다(섬광 줄임 — 주인공이 묻히지 않게)
            rig.x = x; rig.y = a.y; rig.flip = a.flip; rig.remap = a.remap; rig.flash = riseOn && !a.isHero ? 0 : a.flash; rig.weaponSprite = a.weaponSprite
            let v0 = w.floats.count
            rig.emit(time: s.gameTime, dt: dt, style: style, tables: tables, into: &w)
            if let dz = zBack[a.id] { zRanges.append((v0, w.floats.count, Float(dz))) }
            out.ranges[a.id] = v0..<w.floats.count
            if a.shake != 0 && (q.hasJug || (q.airOv ?? 0) > 2) { rig.actor.airOv = q.airOv }
            rigs[a.id] = rig
            drawnX[a.id] = a.x
            if let e = rig.eyePoint { out.eyes[a.id] = e }
            if let j = rig.joints {
                let f: Double = a.flip ? -1 : 1
                out.heads[a.id] = [a.x + f * j.head.x, a.y + j.head.y]
                // 몸통 위 방향(골반 → 목)으로 머리 기울기를 따른다(숙이기 · 달리기 앞 기울기)
                var up = SIMD2(f * (j.neck.x - j.hips.x), j.neck.y - j.hips.y)
                let n = (up * up).sum().squareRoot(); up = n > 0.5 ? up / n : [0, -1]
                let fwd = SIMD2(-up.y * f, up.x * f), sc = rig.rig.sc ?? 1
                out.mouths[a.id] = (out.heads[a.id]! + fwd * 4.5 * sc + up * 3.5 * sc, fwd)
            }
        }
        // 그림자(웹: 인물 그리기 전 · ACT() 순서 · curPose 의 골반 앞뒤 b[0] + r)
        for a in s.actors where !a.hidden {
            guard let rig = rigs[a.id] else { continue }
            let P = rig.actor.lastPose
            let sc = rig.rig.sc ?? 1
            let sx = a.x + (a.flip ? -1 : 1) * jsRound(((P?.b?.x ?? 0) + (P?.r ?? 0)) * sc)
            guard style.enabled && contactShadow else { shadowList.append((sx, a.y, sc < 1)); continue }
            let air = ((P?.air ?? 0) + (a.pose.airOv ?? 0)) * sc + a.airOv
            if air > 10 || sc < 1 { shadowList.append((sx, a.y, true)) }            // 떠 있다: 작은 그림자 하나
            else {
                shadowList.append((sx, a.y, false))
                if air < 3 { shadowList.append((sx, a.y, true)) }                   // 땅에 닿음: 발밑 가운데 한 겹 더(접지)
            }
        }
        out.shadows = shadowList.map { sx, y, small in small ? SpriteDraw(name: "shadow_s", x: sx - 5, y: y - 1) : SpriteDraw(name: "shadow", x: sx - 11, y: y - 2) }
        out.mesh = w.floats
        for (a, b, dz) in zRanges { for i in stride(from: a + 2, to: b, by: 10) { out.mesh[i] += dz } }
        // 승객 소품: 신문(가끔 넘긴다) · 휴대폰(얼굴 옆 + 화면 불빛)
        for a in s.actors where a.isPassenger && !a.hidden {
            guard let prop = a.idleProp, a.pose.pose == "sb_sit" || a.pose.pose == "sb_strap" || a.pose.anim == "pass" else { continue }
            let f: Double = a.flip ? -1 : 1, sit = a.pose.pose.hasPrefix("sb_sit") || a.y < 221
            if prop == "paper" {
                let flipPage = Int(jsFloor((s.time + a.x) / 4)) % 2 != 0
                out.props.append(SpriteDraw(name: flipPage ? "sb_news" : "sb_news2", x: jsRound(a.x + f * (sit ? 7 : -3)) - 5, y: jsRound(a.y + (sit ? -42 : -52))))
            } else if prop == "phone" {
                out.props.append(SpriteDraw(name: "sb_phone", x: jsRound(a.x + f * (sit ? 6 : -6)) - 2, y: jsRound(a.y + (sit ? -36 : -50))))
                out.lights.append(SceneLight(x: a.x + f * 6, y: a.y - 36, z: 12, r: 18, c: [0.75, 0.85, 1], i: 0.6))
            }
        }
        for k in rigs.keys where !seen.contains(k) { rigs[k] = nil; modelKeys[k] = nil }   // 사라진 인물
        _ = drawnX
        return out
    }

    /// 피격 반응 다양화(docs/11 §9): 서서 맞는 타격마다 변형을 고른다(그림 상태만 — 규칙은 모른다).
    /// 연출 감독이 깃발 켜짐(HUDCatalog.native)일 때만 부른다. 아직 그린 적 없는 인물(리그 없음)은 건너뛴다
    public func react(_ events: [SimEvent], _ s: SimSnapshot) {
        guard style.enabled && style.hitReact else { return }
        for case let .hit(h) in events {
            guard var rig = rigs[h.target], let T = s.actors.first(where: { $0.id == h.target }), let R = HitReactMap.read(h, target: T) else { continue }
            rig.react.trigger(actor: h.target, zone: R.zone, dir: R.dir, tier: R.tier, mass: R.mass, time: s.gameTime, hold: R.hold)
            rigs[h.target] = rig
        }
    }
    /// 점검용(테스트): 인물의 반응 상태
    public func reactState(_ id: ActorID) -> HitReactState? { rigs[id]?.react }

    /// 점검용(테스트): 마지막으로 그린 관절 — 인물 발밑 기준 지역 좌표(x 앞 · y 아래, 리그 배율 반영)
    func drawnJoints(_ id: ActorID) -> Joints? { rigs[id]?.joints }

    /// 판이 바뀌면 그리기 상태를 버린다
    public func reset() { rigs = [:]; modelKeys = [:] }

    /// 웹 isDown 근사(장면 구성 foes[].down — 손전등 · 쓰러짐)
    public static func isDown(_ a: SimSnapshot.ActorView) -> Bool { downPoses.contains(a.pose.pose) }
}
