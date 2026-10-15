import Foundation
import BBContent

/// 동작 시퀀스 한 칸: (키 포즈, 길이, 깜빡임)
public struct SeqStep: Sendable, Equatable {
    public var pose: String, length: Double, blink: Bool
}

/// 동작 시퀀스 표 — 3D 인물(jw)은 JW_SEQ(길이 = ms), 없으면 옛 표(12fps 칸)
public struct SequenceTable: Sendable {
    public internal(set) var jw: [String: [SeqStep]]
    /// JW_SEQ 에 없는 동작(옛 mma 표 중 3D 인물이 실제로 쓰는 것)
    public let legacy: [String: [SeqStep]]

    public init(_ s: ContentStore) throws {
        let raw: [String: [[JSONValue]]] = try s.decode("JW_SEQ")
        jw = raw.mapValues { $0.map { SeqStep(pose: $0[0].string ?? "", length: $0[1].double ?? 0, blink: $0.count > 2 && $0[2].string == "blink") } }
        func st(_ a: [(String, Double)]) -> [SeqStep] { a.map { SeqStep(pose: $0.0, length: $0.1, blink: false) } }
        legacy = ["walk": st([("b_walk0", 2), ("b_walk1", 2), ("b_walk2", 2), ("b_walk3", 2)]),
                  "down": st([("death2", 9999)])]
    }
    public func steps(_ anim: String) -> [SeqStep]? { jw[anim] ?? legacy[anim] }
}

/// 웹 enterStep / advance 의 기본 경로(동작 요청 · 큐 · 큐 프레임 콜백 없이). 애니메이션 한 칸(게임 20fps)마다 advance().
/// 게임 시뮬레이션은 BBSim 의 자체 플레이어(동작 요청 · 큐 · 큐 프레임 포함)를 쓴다 — 이것은 실험실 · 뷰어용.
public struct SequencePlayer: Sendable {
    public var si = 0
    public var hold = 1
    public var after: String?
    /// 애니메이션 칸 속도(웹 animFps) — 게임 20, 엔진 실험실 12
    public var fps: Double
    public init(fps: Double = 20) { self.fps = fps }

    /// 웹 setAnim
    public mutating func set(_ name: String, on a: inout ActorPose, table: SequenceTable, loop: Set<String>) {
        a.anim = name; si = 0; enter(&a, table: table, loop: loop)
    }
    /// 웹 advance — 애니메이션 한 칸(1/fps초)
    public mutating func advance(_ a: inout ActorPose, table: SequenceTable, loop: Set<String>) {
        a.k += 1; hold -= 1
        if hold > 0 { return }
        si += 1; enter(&a, table: table, loop: loop)
    }
    mutating func enter(_ a: inout ActorPose, table: SequenceTable, loop: Set<String>) {
        var guardN = 0
        while guardN < 8 {
            guardN += 1
            let seq = table.steps(a.anim) ?? []
            if si >= seq.count {
                if loop.contains(a.anim) { si = 0; continue }
                if let n = after { a.anim = n; after = nil; si = 0; continue }
                a.anim = "idle"; si = 0; continue
            }
            let s = seq[si]
            if s.length <= 0 { si += 1; continue }
            a.prev = a.pose; a.pose = s.pose
            hold = max(1, Int(jsRound(s.length * fps / 1000)))   // 3D 인물은 길이가 ms(d.msT)
            a.phaseN = hold; a.k = 0
            return
        }
    }
}
