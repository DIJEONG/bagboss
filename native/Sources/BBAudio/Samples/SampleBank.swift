import Foundation
@preconcurrency import AVFoundation

/// 녹음 타격음 조각 이름표 — 파일은 Resources/Hits/<이름>.caf(모노 44.1kHz 16비트).
/// 원본: Pixabay 'freesound_community' 펀치 효과음 묶음(punch-sound-effects-28649 · Pixabay Content License) — docs/11 §녹음 타격음.
/// 원본 8조각(p00~p07)을 무음 간격으로 나눈 뒤 앞 잡음 · 겹 타격을 잘라 내고, 꼬리를 200~300ms 로 줄이고,
/// 앞 150ms RMS 를 −13 dBFS 에 맞췄다(피크 −1 dBFS 상한). 소리의 성격(밝기 · 저역)은 특징값으로 골랐다(귀로 고르지 않음).
public enum HitClip: UInt8, Sendable, CaseIterable {
    /// hit_jab — p00: 가장 밝고 가벼운 '탁'(영교차 3351/s · 저역 비율 .57)
    case jab
    /// hit_punch_a — p03: 어둡고 조인 '퍽'(앞 27ms 바람 소리 잘라 냄)
    case punchA
    /// hit_punch_b — p01: 중간 밝기 '퍽'(punchA 와 번갈아)
    case punchB
    /// hit_kick_a — p04: 가장 어둡고 묵직한 '퍽'(앞 36ms 잡음 잘라 냄)
    case kickA
    /// hit_kick_b — p02: 어두운 '퍽'(kickA 와 번갈아 · 몸통 치기 기본)
    case kickB
    /// hit_hammer — p05: 밝은 금속성 + 저역(앞 10ms 의 겹 타격을 잘라 한 방으로)
    case hammer
    /// hit_big — p06: 가장 크고 날카로운 시작 + 긴 몸통 '쾅'
    case big
    /// hit_upper — p07: 중간 밝기 · 길게 끄는 몸통(올려치기 · 띄우기)
    case upper

    /// 번들 파일 이름(확장자 제외)
    public var fileName: String {
        switch self {
        case .jab: "hit_jab"
        case .punchA: "hit_punch_a"
        case .punchB: "hit_punch_b"
        case .kickA: "hit_kick_a"
        case .kickB: "hit_kick_b"
        case .hammer: "hit_hammer"
        case .big: "hit_big"
        case .upper: "hit_upper"
        }
    }
}

/// 미리 디코딩한 PCM 조각 묶음(읽기 전용). 디코딩은 불러올 때 한 번 — 오디오 스레드는 포인터로 읽기만 한다(할당 · 잠금 없음).
/// SynthCore 가 강하게 쥐고 있는 동안 버퍼가 살아 있다.
public final class SampleBank: @unchecked Sendable {
    public struct Clip: @unchecked Sendable {   // 읽기 전용 버퍼 포인터
        public let samples: UnsafePointer<Float>
        public let count: Int
        public let sampleRate: Double
        public var duration: Double { Double(count) / sampleRate }
    }
    private let clips: [Clip?]
    private let owned: [UnsafeMutablePointer<Float>]

    /// 조각별 표본(테스트 · 다른 출처용)
    public init(_ pcm: [HitClip: [Float]], sampleRate: Double) {
        var cl = [Clip?](repeating: nil, count: HitClip.allCases.count), own: [UnsafeMutablePointer<Float>] = []
        for (c, x) in pcm where !x.isEmpty {
            let p = UnsafeMutablePointer<Float>.allocate(capacity: x.count)
            p.initialize(from: x, count: x.count)
            own.append(p)
            cl[Int(c.rawValue)] = Clip(samples: UnsafePointer(p), count: x.count, sampleRate: sampleRate)
        }
        clips = cl; owned = own
    }

    deinit { for p in owned { p.deallocate() } }

    public func clip(_ c: HitClip) -> Clip? { clips[Int(c.rawValue)] }
    /// 모든 조각이 있는가
    public var isComplete: Bool { clips.allSatisfy { $0 != nil } }

    /// 번들 조각 전부(앱 · 테스트가 같이 쓴다). 처음 부를 때 한 번 디코딩(조각 8개 · 약 0.2MB, 수 ms)
    public static let shared: SampleBank? = try? loadBundled()

    /// Resources/Hits/*.caf 를 Float32 로 디코딩한다. 하나라도 없으면 오류
    public static func loadBundled() throws -> SampleBank {
        var pcm: [HitClip: [Float]] = [:]
        var sr = 44_100.0
        for c in HitClip.allCases {
            guard let url = Bundle.module.url(forResource: c.fileName, withExtension: "caf", subdirectory: "Hits")
                    ?? Bundle.module.url(forResource: c.fileName, withExtension: "caf") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "Hits/\(c.fileName).caf"])
            }
            let f = try AVAudioFile(forReading: url)
            guard let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try f.read(into: b)
            guard let ch = b.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
            pcm[c] = Array(UnsafeBufferPointer(start: ch[0], count: Int(b.frameLength)))   // 첫 채널(모노)
            sr = f.processingFormat.sampleRate
        }
        return SampleBank(pcm, sampleRate: sr)
    }
}
