import Foundation
import BBSim

// 카메라 연출(웹 render() 의 SHK · zoomK/zoomC · camZ/camC · invF · CAMX).
// 규칙은 CameraKick 이벤트(의도)만 내고, 실제 보간 값은 여기서 가진다(docs/06 §2.3 '연출 값 분리').
//  · 흔들림: 웹 shakeX 는 화면 전체 정지(freeze) 칸 동안만 ±shakeAmp 로 번갈아 흔들린다 + 맞은 쪽으로 미는 shoveX(규칙 상태)
//  · 줌 펀치: CameraKick.zoomMode(더하기 · 최댓값 · 덮어쓰기 + 상한 — 웹 자리별 식) 로 합치고 화면 프레임마다 ×0.86 — 필살기 줌(camZ)은 규칙 값, 중심(camC)은 주인공을 따라간다
//  · 반전(임팩트 프레임): invertFrames 만큼 — 장면 구성(subwayFX)이 한 칸씩 깎는다

public struct CameraFrame: Sendable, Equatable {
    /// 화면 흔들림(픽셀, 웹 SHK — 스프라이트 · 인물 · 광원 · 빛줄기 공통)
    public var shake: Double
    public var view: StageView
}

public struct CameraDirector: Sendable {
    public private(set) var zoomK = 0.0
    public private(set) var zoomC: SIMD2<Double> = [0.5, 0.5]
    public private(set) var shakeAmp = 1.0
    /// 화면 반전 남은 프레임(웹 GS.invF) — 장면 구성 뒤 새 값으로 갱신한다
    public var invF = 0
    public private(set) var camC: SIMD2<Double>?
    /// 섬광 끔(웹 OPT.noFlash)
    public var noFlash = false
    /// 화면 움직임 배율(네이티브 '화면 흔들림 줄이기' — 1 = 웹 그대로). 흔들림 · 줌 펀치에 곱한다(필살기 줌은 그대로)
    public var motionScale = 1.0
    public var visibleWidth = 360.0
    /// 시뮬레이션 카메라 창 폭(SimConfig.viewWidth — 웹 VW 360). 보이는 폭이 이보다 좁거나 넓으면(네이티브 세로 배치 · docs/09)
    /// 같은 가운데를 두고 잘라 보이고, 좁을 때는 주인공이 가장자리 밖으로 나가지 않게 민다. 같으면 웹 그대로
    public var simViewWidth = 360.0
    public init() {}

    // MARK: 날림 추적(네이티브 — 2026-10-14 감독: 멀리 날린 적이 화면 밖으로 나가 안 보인다)
    // 주인공이 크게 날린 적의 착지 · 벽꿍이 화면 밖이면: 타격 정지 동안 그대로(0.08초) → 날아가는 적을 따라간다(주인공도 같이 담기면 함께 · 아니면 적 우선 ·
    // 무도장 확대 중이면 잠깐 줌아웃) → 벽에 박히거나 바닥에 닿으면 멈춰 보여 준다(0.4초) → 부드럽게 주인공 중심으로(0.5초 · 주인공이 다음 동작을 하면 빨리).
    // 규칙 카메라 값(camX · camZoom)은 그대로 두고 화면 값만 섞는다(가중치 w 0 → 1 → 0).
    struct Follow: Sendable { var id: ActorID; var t = 0.0, w = 0.0, phase = 0, phaseT = 0.0; var heroAnim: String; var to: StageView? = nil }
    var follow: Follow?
    /// 날림 추적 스위치(기본 켬 — 점검 · 비교용)
    public var flightFollow = true
    /// 날림 추적 값: 타격 정지 동안 기다림 · 따라가는 빠르기(초당) · 멈춤 · 돌아오기(초) · 적 · 주인공 둘레 여백(px) · 최대 길이(초)
    static let ffDelay = 0.08, ffRate = 9.0, ffHold = 0.4, ffBack = 0.5, ffMargin = 30.0, ffHeroMargin = 16.0, ffMax = 2.4
    /// 크게 날리는 기술(반응이 rBlast · 넉백이 아니어도 멀리 날아가는 것)
    static let ffMoves: Set<String> = ["nv_stamp", "nv_punt", "nv_cork", "tetsu", "nv_kneelift", "nv_beam", "charge", "charge_air", "round", "round_air", "fkick", "bkick", "kick"]

    /// 한 틱 이벤트 반영
    public mutating func apply(_ events: [SimEvent], width W: Double = 480, height H: Double = 270) {
        for e in events {
            if case let .hit(h) = e, flightFollow, h.attackerIsHero, !h.heroWasHit,
               h.reaction == "rBlast" || ((h.knock || h.big) && Self.ffMoves.contains(h.attackerAnim)) {
                if follow?.id != h.target { follow = Follow(id: h.target, heroAnim: h.attackerAnim) } else { follow!.t = 0; follow!.phase = 0; follow!.phaseT = 0 }
                continue
            }
            if case let .groundImpact(_, _, p) = e { shakeAmp = max(shakeAmp, 1 + 1.6 * p); continue }   // 웹 groundImpact: shakeAmp = max(shakeAmp, 1+1.6p)
            guard case .camera(let k) = e else { continue }
            if k.shake > 0 { shakeAmp = k.shakeSet ? k.shake : max(shakeAmp, k.shake) }   // 웹: 대부분 max · damage 는 덮어쓰기
            if k.zoom > 0 {
                switch k.zoomMode {
                case .add(let cap): zoomK = min(cap, zoomK + k.zoom)              // 웹 치명 · 넉백: min(cap, zoomK + z)
                case .max(let cap): zoomK = min(cap, max(zoomK, k.zoom))          // 웹 ATK_FEEL · 무거운 적 공격: min(cap, max(zoomK, z))
                case .set: zoomK = k.zoom                                          // 웹 마지막 일격 zoomK = .12
                case .legacy:
                    // 모드를 안 정한 자리(보너스 차 · 네이티브 러시): 값 크기로 상한을 고른다
                    let cap = k.zoom >= 0.1 ? k.zoom : k.zoom >= 0.05 ? 0.09 : 0.06
                    zoomK = k.zoom >= 0.1 ? k.zoom : max(zoomK, min(cap, zoomK + k.zoom))
                }
                if let f = k.focus { zoomC = [f.x / W, f.y / H] }
            }
            if k.invertFrames > 0 && !noFlash { invF = max(invF, k.invertFrames) }
        }
    }

    /// 화면 프레임 하나 — snapshot 은 이번 프레임 마지막 틱 뒤 상태, dt = 화면 프레임 길이(초)
    public mutating func frame(_ s: SimSnapshot, dt: Double, width W: Double = 480, height H: Double = 270) -> CameraFrame {
        let shakeX = s.freeze > 0 ? (s.freeze % 2 == 1 ? shakeAmp : -shakeAmp) : 0
        var shk = max(-5, min(5, shakeX + (s.shoveX + 0.5).rounded(.down)))
        if motionScale < 1 { shk = (shk * motionScale).rounded() }   // 줄이기: 정수 픽셀로(도트 흔들림 유지)
        // 필살기 줌 중심: 주인공 머리 쪽을 부드럽게 따라간다(웹 spcCamTick 의 GS.camC)
        let cz = s.camZoom > 1 ? s.camZoom - 1 : 0
        if let h = s.actors.first(where: { $0.isHero }) {
            let t: SIMD2<Double> = [h.x / W, (h.y - 44) / H]
            if let c = camC, cz > 0 { camC = c + (t - c) * min(1, dt * 6) } else { camC = t }
        }
        var cx = s.camX
        if visibleWidth != simViewWidth {   // 네이티브 세로 배치: 시뮬레이션 창 가운데 기준으로 다시 맞춘다(규칙 값은 그대로)
            cx += (simViewWidth - visibleWidth) / 2
            if visibleWidth < simViewWidth, let h = s.actors.first(where: { $0.isHero }) {
                let m = min(48, visibleWidth * 0.18)
                cx = max(h.x - visibleWidth + m, min(h.x - m, cx))
            }
        }
        var v = StageView(sceneWidth: W, sceneHeight: H, visibleWidth: visibleWidth,
                          cameraX: max(0, min(W - visibleWidth, cx)))
        v.zoom = 1 + zoomK * motionScale + cz
        v.zoomCenter = cz > 0 ? (camC ?? [0.5, 0.5]) : zoomC
        if follow != nil { flightFollow(&v, s, dt: dt, W: W) }
        zoomK *= pow(0.86, dt * 60)   // 웹은 그리는 프레임마다 ×0.86(60Hz 기준)
        if zoomK < 1e-4 { zoomK = 0 }
        return CameraFrame(shake: shk, view: v)
    }

    /// 보이는 무대 구간(장면 px) — 세로 크롭 cameraX · 줌(zoom · zoomCenter) 반영
    static func span(_ v: StageView) -> (l: Double, r: Double) {
        let z = max(v.zoom, 1), W = v.sceneWidth
        func u(_ c: Double) -> Double { ((c / W - v.zoomCenter.x) / z + v.zoomCenter.x) * W }
        return (u(v.cameraX), u(v.cameraX + v.visibleWidth))
    }

    /// 날림 추적 한 프레임: 단계 진행 → 적(과 주인공)을 담는 화면 값 → 지금 화면과 가중치로 섞는다
    mutating func flightFollow(_ v: inout StageView, _ s: SimSnapshot, dt: Double, W: Double) {
        guard var F = follow, let T = s.actors.first(where: { $0.id == F.id }), !T.hidden,
              let H = s.actors.first(where: { $0.isHero }), F.t < Self.ffMax else { follow = nil; return }
        let g = max(0, min(0.1, dt))
        F.t += g; F.phaseT += g
        let heroBusy = H.pose.anim != F.heroAnim && !["idle", "walk", "nv_go", "nv_step", "nv_skid", "nv_skidEnd"].contains(H.pose.anim)
        let onWall = T.pose.pose.hasPrefix("nv_wsplat")
        switch F.phase {
        case 0:   // 따라가기(타격 정지 동안은 그대로) → 벽에 박히거나 바닥에 닿으면 멈춤
            if F.t > Self.ffDelay { F.w += (1 - F.w) * min(1, g * Self.ffRate) }
            if F.t > 0.2 && (onWall || !T.pose.hasJug) { F.phase = 1; F.phaseT = 0 }
            if heroBusy && F.t > 0.3 { F.phase = 2; F.phaseT = 0 }
        case 1:   // 멈춰 보여 준다(벽에 붙은 동안은 조금 더)
            F.w += (1 - F.w) * min(1, g * Self.ffRate)
            if (F.phaseT > Self.ffHold && !onWall) || F.phaseT > Self.ffHold + 0.3 || heroBusy { F.phase = 2; F.phaseT = 0 }
        default:  // 돌아오기(부드럽게 — 주인공이 다음 동작을 하면 빨리)
            F.w = max(0, F.w - g / (heroBusy ? 0.2 : Self.ffBack))
            if F.w <= 0 { follow = nil; return }
        }
        follow = F
        // 담을 화면: 적이 지금 화면 안(여백 포함)이면 마지막으로 잡은 화면을 그대로 쓴다(없으면 손대지 않는다 — 튀지 않게)
        let base = v, sp = Self.span(base), m = Self.ffMargin, hm = Self.ffHeroMargin
        if T.x >= sp.l + m && T.x <= sp.r - m { if let to = F.to { blend(&v, base, to, F.w) }; return }
        let dir: Double = T.x >= H.x ? 1 : -1
        let need = abs(T.x - H.x) + m + hm
        var z = max(base.zoom, 1)
        if z > 1 && motionScale >= 1 && need > base.visibleWidth / z { z = max(1, min(z, base.visibleWidth / need)) }   // 무도장 확대: 잠깐 줌아웃
        let vw = base.visibleWidth / z
        _ = need
        var L = dir > 0 ? T.x + m - vw : T.x - m          // 적을 바깥쪽 가장자리(여백) 안에 — 주인공은 폭이 되면 같이 담긴다
        L = max(0, min(W - vw, L))
        var to = base; to.zoom = z
        if z <= 1.0001 {
            to.cameraX = max(0, min(W - base.visibleWidth, L))
        } else {
            let zc = base.zoomCenter.x
            var c = (L / W - zc * (1 - 1 / z)) * W * z
            c = max(0, min(W - base.visibleWidth, c))
            to.cameraX = c
            to.zoomCenter.x = max(0, min(1, (L / W - c / (W * z)) / (1 - 1 / z)))
        }
        follow?.to = to
        blend(&v, base, to, F.w)
    }
    /// 섞기(부드러운 계단 · 움직임 줄이기면 이동 폭도 줄인다)
    func blend(_ v: inout StageView, _ base: StageView, _ to: StageView, _ w: Double) {
        let k = w * w * (3 - 2 * w) * (motionScale < 1 ? 0.6 : 1)
        v.cameraX = base.cameraX + (to.cameraX - base.cameraX) * k
        v.zoom = base.zoom + (to.zoom - base.zoom) * k
        v.zoomCenter.x = base.zoomCenter.x + (to.zoomCenter.x - base.zoomCenter.x) * k
    }
}
