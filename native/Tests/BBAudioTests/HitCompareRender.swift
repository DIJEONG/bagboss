import Foundation
import Testing
import BBCore
@testable import BBAudio

/// 귀 없이 비교하기: 타격 스타일마다 '웹 합성(끔)' → '녹음 겹침(켬)' 순서로 오프라인 렌더해 WAV 로 쓴다.
/// `BB_HITS_RENDER=1 swift test --filter HitCompareRender` → tools/js/out/audio/hits_compare.wav · hits/<스타일>_{old,new}.wav · hits_levels.txt
/// (스펙트로그램 시트는 스크래치 spec 도구로 hits/*.wav 를 묶어 hits_compare.png — docs/11 §녹음 타격음)
@Suite struct HitCompareRender {
    static let sr = 44_100.0
    /// (이름, 이름표, 동작, 카운터)
    static let styles: [(String, SfxCue, String, Bool)] = [
        ("jab", .hit3(tier: 0, combo: 1), "jab", false),
        ("punch", .hit3(tier: 1, combo: 2), "cross", false),
        ("kick", .hit3(tier: 1, combo: 2), "kick", false),
        ("body", .hit3(tier: 1, combo: 2), "nv_liver", false),
        ("upper", .hit3(tier: 2, combo: 3), "upper", false),
        ("hammer", .hitK(.hammer, crit: false, combo: 0), "", false),
        ("big", .hit3(tier: 2, combo: 3, big: true), "throw", false),
        ("crit", .hit3(tier: 2, crit: true, combo: 3), "cross", false),
        ("counter", .hit3(tier: 1, combo: 1), "hook", true),
        ("bossbreak", .hitK(.big, crit: true, combo: 0), "", false),
    ]

    static func render(_ cue: SfxCue, move: String, counter: Bool, on: Bool, seconds: Double, seed: UInt64 = 21) -> [Float] {
        let s = SynthCore(sampleRate: sr, samples: SampleBank.shared)
        s.setMix(SoundSettings(), immediate: true)
        var r = SplitMix64(seed: seed); var b = SfxBank()
        s.play(b.expand(cue, context: HitContext(move: move, counter: counter), sampleHits: on, rng: &r).voices)
        return s.renderOffline(frames: Int(seconds * sr))
    }

    static func writeWAV(_ x: [Float], to url: URL) throws {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + x.count * 2)); d.append(contentsOf: Array("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(UInt32(sr)); u32(UInt32(sr) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(x.count * 2))
        for v in x { u16(UInt16(bitPattern: Int16(max(-1, min(1, v)) * 32767))) }
        try d.write(to: url)
    }

    static func stats(_ x: [Float]) -> (peakDb: Double, rmsDb: Double) {
        let pk = Double(x.map { abs($0) }.max() ?? 0)
        let n = min(x.count, Int(0.15 * sr))
        let rms = (x.prefix(n).reduce(0) { $0 + Double($1 * $1) } / Double(max(1, n))).squareRoot()
        return (20 * log10(max(pk, 1e-9)), 20 * log10(max(rms, 1e-9)))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BB_HITS_RENDER"] == "1"))
    func renderCompare() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../tools/js/out/audio").standardized
        let dir = root.appendingPathComponent("hits")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var seq: [Float] = [], log = "스타일      합성(끔) 피크/RMS150   녹음(켬) 피크/RMS150   (dBFS · master .8 · sfx .8 · 컴프레서 뒤)\n"
        let gap = [Float](repeating: 0, count: Int(0.15 * Self.sr))
        for (name, cue, move, counter) in Self.styles {
            let old = Self.render(cue, move: move, counter: counter, on: false, seconds: 0.45)
            let new = Self.render(cue, move: move, counter: counter, on: true, seconds: 0.45)
            try Self.writeWAV(old, to: dir.appendingPathComponent("\(name)_old.wav"))
            try Self.writeWAV(new, to: dir.appendingPathComponent("\(name)_new.wav"))
            seq += old + gap + new + gap + gap
            let a = Self.stats(old), b = Self.stats(new)
            log += String(format: "%-10@  %6.1f / %6.1f        %6.1f / %6.1f\n", name as NSString, a.peakDb, a.rmsDb, b.peakDb, b.rmsDb)
        }
        try Self.writeWAV(seq, to: root.appendingPathComponent("hits_compare.wav"))
        // 빠른 연타(70ms 간격 12타) 겹침 피크
        for on in [false, true] {
            let s = SynthCore(sampleRate: Self.sr, samples: SampleBank.shared)
            s.setMix(SoundSettings(), immediate: true)
            var r = SplitMix64(seed: 11); var b = SfxBank(); var out: [Float] = []
            let moves = ["jab", "jab", "cross", "hook", "kick", "upper", "round_air", "throw", "nv_liver", "upper", "nv_rise", "suplex"]
            for (i, m) in moves.enumerated() {
                let tier = i < 2 ? 0 : i < 5 ? 1 : 2
                s.play(b.expand(.hit3(tier: tier, crit: i % 3 == 2, combo: i + 1, air: i == 6 || i == 7, big: i >= 7), context: HitContext(move: m, counter: i == 3), sampleHits: on, rng: &r).voices)
                out += s.renderOffline(frames: 3087)
            }
            out += s.renderOffline(frames: Int(Self.sr))
            try Self.writeWAV(out, to: root.appendingPathComponent(on ? "hits_combo_new.wav" : "hits_combo_old.wav"))
            let st = Self.stats(out)
            let clip = out.filter { abs($0) >= 1 }.count
            log += String(format: "연타 12타 %@: 피크 %.1f dBFS · 0dBFS 넘은 표본 %d\n", on ? "녹음(켬)" : "합성(끔)", st.peakDb, clip)
        }
        try log.write(to: root.appendingPathComponent("hits_levels.txt"), atomically: true, encoding: .utf8)
        print(log)
    }
}
