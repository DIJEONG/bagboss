import Foundation

/// 인물 한 명을 그리는 데 필요한 것 전부: 모델 · 리그 · 성질 · 애니메이션 상태 · 2차 운동 상태.
/// 한 화면 프레임마다 `emit` 한 번 — 포즈 평가 → 관절 → 뼈 → (강화) → 3D 메시 · 얼굴.
public struct CharacterRig: Sendable {
    public var model: Model3 { didSet { neckRead = false } }
    public var rig: RigDims
    public var traits: ActorTraits
    public var actor: ActorPose
    public var motion = SecondaryMotion()
    /// 강화: 피격 반응 변형 상태(HitReact — 연출 감독이 trigger 한다)
    public var react = HitReactState()
    /// 발 위치(장면 픽셀) · 방향
    public var x: Double, y: Double, flip: Bool
    public var remap = 0
    public var flash = 0.0
    public var weaponSprite: String?
    public var hasFace = true

    public init(model: Model3, rig: RigDims, traits: ActorTraits, actor: ActorPose, x: Double, y: Double, flip: Bool) {
        self.model = model; self.rig = rig; self.traits = traits; self.actor = actor; self.x = x; self.y = y; self.flip = flip
    }

    /// 마지막으로 푼 관절(타격 위치 · 이펙트 기준점용)
    public private(set) var joints: Joints?
    /// 마지막으로 그린 눈 자리(장면 픽셀 — 얼굴 그리기와 같은 머리 뼈 변환 · 눈 줄 가운데). 네이티브 야근 광선 출발점
    public private(set) var eyePoint: SIMD2<Double>?
    /// 마지막으로 그린 뼈(강화까지 얹은 것 — 점검용)
    public private(set) var skeleton: Skeleton?
    /// 목 조각 치수(모델에서 한 번 읽는다 — 모델이 바뀌면 다시)
    private var neckSpec: NeckSpec?, neckRead = false

    /// - time: 게임 시간(초) · dt: 지난 화면 프레임 이후(초) · drawOX: 화면 오프셋(웹 drawOX)
    public mutating func emit(time: Double, dt: Double, style: MotionStyle, shades: Bool = false, drawOX: Double = 0,
                              tables: AnimTables, into w: inout MeshWriter) {
        var ev = evaluatePose(&actor, traits: traits, rig: rig, time: time, tables: tables)
        if style.enabled && style.hitReact && react.active { react.apply(&ev.pose, time: time, anim: actor.anim) }   // 강화: 피격 반응 변형(보이는 자세만)
        let (j, _) = solveJoints(ev.pose, rig: rig, input: JointInput(tilt: actor.tilt, airOv: actor.airOv,
                                                                       walkResidual: ev.walkGait ? actor.gres : nil, weaponSprite: weaponSprite))
        joints = j
        var sk = makeSkeleton(j, pose: ev.pose)
        let f: Double = flip ? -1 : 1
        motion.apply(&sk, style: style, anim: actor.anim, pose: ev.pose, hipsWorldX: x + f * j.hips.x, facing: f,
                     dt: dt, time: time, reacts: tables.reacts)
        let place = MeshPlacement(x: x + drawOX, y: y, flip: flip, remap: remap, flash: flash > 0)
        let neckOn = style.enabled && style.neck
        if neckOn {   // 강화: 목(꺼짐 = 웹 그대로) — 지나치게 늘어난 목은 머리를 부드럽게 당긴다(관절 머리 · 입 위치도 같이)
            if !neckRead { neckSpec = NeckSpec(model: model); neckRead = true }
            if let N = neckSpec {
                let mv = NeckRig.soften(N, &sk, maxLen: style.neckMax, give: style.neckGive)
                if mv != .zero { joints?.head += mv }
            }
        }
        emitModel(model, sk, at: place, tables: tables, into: &w)
        skeleton = sk
        if let head = sk["head"] {   // emitFace 의 얼굴 기준점 A(눈 줄) + 눈 가운데 칸
            let A = boneTransform(head, style.enabled ? sk.spin : nil, style.enabled ? sk.roll : nil, [4.3, -8.6, 3.2])
            eyePoint = SIMD2(x + drawOX + f * (A.x + 2.5), y + A.y + 0.5)
        } else { eyePoint = nil }
        if neckOn, let N = neckSpec { NeckRig.emit(N, sk, at: place, tables: tables, into: &w) }
        if hasFace && !(flash > 0), let head = sk["head"] {
            let key = faceKey(anim: actor.anim, flash: flash, footX: x, time: time, tables: tables)
            // 강화: 얼굴도 몸 전체 회전(spin · roll)을 따른다 — 꺼짐은 웹처럼 회전을 빼서 얼굴이 화면 쪽에 남는다(웹 버그)
            emitFace(key: key, head: head, spin: style.enabled ? sk.spin : nil, roll: style.enabled ? sk.roll : nil, at: place, shades: shades, isHero: traits.isHero, tables: tables, into: &w)
        }
    }
}
