import Foundation
import Testing
import BBCore
import BBContent
@testable import BBAudio

/// 녹음 타격음(docs/11 §녹음 타격음): 조각 불러오기 · 스타일 매핑 · 끄면 합성 그대로 · 결정적 흔들림 · 겹침 피크
@Suite struct HitSampleTests {
    static var bank: SampleBank { SampleBank.shared! }

    static func synth(_ sr: Double = 44_100, samples: SampleBank? = HitSampleTests.bank, compressor: Bool = true) -> SynthCore {
        var o = SynthCore.Options(); o.compressor = compressor
        let s = SynthCore(sampleRate: sr, options: o, samples: samples)
        s.setMix(SoundSettings(), immediate: true)   // 앱 기본 볼륨(master .8 · sfx .8)
        return s
    }

    // MARK: 조각

    @Test func clipsLoadAndAreTrimmedAndLeveled() throws {
        let b = try SampleBank.loadBundled()
        #expect(b.isComplete)
        for c in HitClip.allCases {
            let clip = try #require(b.clip(c))
            #expect(clip.sampleRate == 44_100)
            #expect(clip.duration >= 0.15 && clip.duration <= 0.31, "\(c.fileName) 길이 \(clip.duration)")
            let x = UnsafeBufferPointer(start: clip.samples, count: clip.count)
            let peak = x.map { abs($0) }.max() ?? 0
            #expect(peak > 0.7 && peak <= 0.892, "\(c.fileName) 피크 \(peak)")                      // −1 dBFS 상한
            let n = min(clip.count, 6615)
            let rms = (x.prefix(n).reduce(0) { $0 + Double($1 * $1) } / Double(n)).squareRoot()
            #expect(abs(20 * log10(rms) + 13) < 1.5, "\(c.fileName) RMS \(20 * log10(rms))")             // 앞 150ms RMS ≈ −13 dBFS
            #expect(abs(x[0]) < 0.02 && abs(x[clip.count - 1]) < 0.01)                                  // 잘린 곳 딸깍 없음(페이드)
        }
    }

    // MARK: 매핑

    @Test func everyHitKindResolvesToAClip() {
        for k in SfxCue.HitKind.allCases {
            let s = HitSampleMap.style(for: .hitK(k, crit: false, combo: 0))
            #expect(s != nil)
            for c in HitSampleMap.clips(s!) { #expect(Self.bank.clip(c) != nil) }
        }
        #expect(HitSampleMap.style(for: .hitK(.hammer, crit: false, combo: 0)) == .hammer)
        #expect(HitSampleMap.style(for: .hitK(.big, crit: true, combo: 0)) == .big)
        for s in HitStyle.allCases { #expect(!HitSampleMap.clips(s).isEmpty) }
        // 타격음이 아니면 nil
        #expect(HitSampleMap.style(for: .glass) == nil && HitSampleMap.style(for: .thud) == nil)
    }

    @Test func movesMapToStyles() {
        func st(_ m: String, tier: Int = 1) -> HitStyle? { HitSampleMap.style(for: .hit3(tier: tier), context: HitContext(move: m)) }
        #expect(st("jab", tier: 0) == .jab && st("nv_flick", tier: 0) == .jab)
        #expect(st("cross") == .punch && st("hook") == .punch && st("elbow", tier: 0) == .punch)
        #expect(st("kick") == .kick && st("round", tier: 2) == .kick && st("round_air", tier: 2) == .kick && st("knee") == .kick)
        for m in ["upper", "nv_rise", "nv_kneelift", "nv_duckup"] { #expect(st(m, tier: 2) == .upper, "\(m)") }
        #expect(st("nv_liver") == .body && st("nv_roll") == .body)
        #expect(st("throw", tier: 2) == .big && st("suplex", tier: 2) == .big && st("axe_air", tier: 2) == .big)
        // 모르는 동작 · 맥락 없음: 등급으로(0 탁 · 1 퍽 · 2 쾅)
        #expect(st("??", tier: 0) == .jab && st("??", tier: 1) == .punch && st("??", tier: 2) == .big)
        #expect(HitSampleMap.style(for: .hit3(tier: 2)) == .big)
    }

    // MARK: 끄면 합성 그대로

    static let hitCues: [SfxCue] = [
        .hitK(.jab, crit: false, combo: 0), .hitK(.punch, crit: true, combo: 5), .hitK(.hammer, crit: false, combo: 2),
        .hitK(.kick, crit: false, combo: 0), .hitK(.big, crit: true, combo: 0),
        .hit3(tier: 0), .hit3(tier: 1, crit: true, combo: 3), .hit3(tier: 2, big: true), .hit3(tier: 1, combo: 4, air: true), .hit3(tier: 0, crit: true),
    ]

    @Test func offIsExactlyTheSynthRecipe() {
        for cue in Self.hitCues + [.glass, .floor(1), .just] {
            var r1 = SplitMix64(seed: 99), r2 = SplitMix64(seed: 99)
            var b1 = SfxBank(), b2 = SfxBank()
            let off = b1.expand(cue, context: HitContext(move: "upper", counter: true), sampleHits: false, rng: &r1)
            let web = b2.expand(cue, rng: &r2)
            #expect(off.voices == web.voices && off.duck == web.duck, "\(cue)")
            #expect(r1.nextUInt64() == r2.nextUInt64())                     // 난수 소비도 같다
            #expect(!off.voices.contains { if case .sample = $0.source { true } else { false } })
        }
        // 렌더도: 조각 묶음을 쥔 합성기 = 없는 합성기(합성 처방만이면)
        func render(_ samples: SampleBank?) -> [Float] {
            let s = Self.synth(samples: samples); var r = SplitMix64(seed: 5); var b = SfxBank()
            for c in Self.hitCues { s.play(b.expand(c, context: nil, sampleHits: false, rng: &r).voices) }
            return s.renderOffline(frames: 22_050)
        }
        #expect(render(Self.bank) == render(nil))
    }

    // MARK: 켜면

    static func samples(_ e: SfxBank.Expansion) -> [VoiceSpec] { e.voices.filter { if case .sample = $0.source { true } else { false } } }

    @Test func layeredKeepsSynthBodyAndCritCrack() {
        var r = SplitMix64(seed: 1), r0 = SplitMix64(seed: 1)
        var b = SfxBank(), b0 = SfxBank()
        let cue = SfxCue.hit3(tier: 1, crit: true, combo: 2)
        let web = b0.expand(cue, rng: &r0)
        let on = b.expandLayered(cue, context: HitContext(move: "cross"), rng: &r)
        // 치명 '짝'(끝 3개)은 그대로
        #expect(Array(on.voices.filter { if case .sample = $0.source { false } else { true } }.suffix(3)) == Array(web.voices.suffix(3)))
        // 대역 통과 '퍽' 잡음은 빠지고, 사인 '쿵'은 남는다
        #expect(on.voices.contains { if case .osc = $0.source { true } else { false } })
        #expect(!on.voices.dropLast(5).contains { $0.source == .white && $0.filter == .bandpass && $0.filterFreq.startValue > 1000 })
        // 조각: 본 조각 + 치명 겹 = 2개
        let s = Self.samples(on)
        #expect(s.count == 2)
        if case .sample(let c) = s[0].source { #expect([.punchA, .punchB].contains(c)) }
        // 덕킹은 합성과 같다
        var r2 = SplitMix64(seed: 3), r3 = SplitMix64(seed: 3)
        #expect(b.expandLayered(.hit3(tier: 2, big: true), rng: &r2).duck == b0.expand(.hit3(tier: 2, big: true), rng: &r3).duck)
    }

    @Test func counterAddsALayer() {
        var r = SplitMix64(seed: 1), r2 = SplitMix64(seed: 1)
        var b = SfxBank()
        let a = Self.samples(b.expandLayered(.hit3(tier: 1), context: HitContext(move: "hook"), rng: &r))
        let c = Self.samples(b.expandLayered(.hit3(tier: 1), context: HitContext(move: "hook", counter: true), rng: &r2))
        #expect(c.count == a.count + 1)
        #expect(c[0].gain.initial > a[0].gain.initial * 1.1)   // 같은 난수 → 카운터만큼 크다
    }

    @Test func variationIsDeterministicAndBounded() {
        func run(_ seed: UInt64) -> [VoiceSpec] {
            var r = SplitMix64(seed: seed); var b = SfxBank()
            return (0..<24).flatMap { _ in Self.samples(b.expandLayered(.hit3(tier: 1), context: HitContext(move: "cross"), rng: &r)) }
        }
        let a = run(42), b = run(42), c = run(43)
        #expect(a == b)                              // 같은 씨앗 = 같은 소리
        #expect(a != c)
        let rates = a.map(\.rate), gains = a.map(\.gain.initial)
        #expect(Set(rates).count > 20)               // 반복해도 같은 높이가 아니다
        #expect(rates.allSatisfy { abs($0 - 1) <= 0.045 + 1e-9 })
        #expect(gains.allSatisfy { abs($0 / 0.5 - 1) <= 0.1 + 1e-9 })
        // 두 조각을 번갈아 쓴다
        let clips = Set(a.compactMap { if case .sample(let c) = $0.source { c } else { nil } })
        #expect(clips == [.punchA, .punchB])
    }

    @Test func comboPitchUpIsKept() {
        func meanRate(_ combo: Int) -> Double {
            var r = SplitMix64(seed: 8); var b = SfxBank()
            let v = (0..<40).map { _ in Self.samples(b.expandLayered(.hit3(tier: 1, combo: combo), rng: &r))[0].rate }
            return v.reduce(0, +) / Double(v.count)
        }
        #expect(abs(meanRate(10) / meanRate(0) - 1.22) < 0.01)
    }

    @Test func sampleVoiceRendersAndEnds() {
        let s = Self.synth(48_000, compressor: false)
        s.play(SfxBank.sampleVoice(.jab, gain: 1, rate: 1, lowpass: nil))
        let x = s.renderOffline(frames: 48_000)
        let dur = Self.bank.clip(.jab)!.duration
        let live = x.lastIndex { abs($0) > 1e-6 } ?? 0
        #expect(abs(Double(live) / 48_000 - dur) < 0.01)   // 표본율이 달라도 길이 그대로(44.1k → 48k)
        #expect(s.activeVoices == 0)
        // 조각 묶음이 없으면 조용히 끝난다
        let q = Self.synth(samples: nil, compressor: false)
        q.play(SfxBank.sampleVoice(.big, gain: 1, rate: 1, lowpass: nil))
        #expect(q.renderOffline(frames: 4410).allSatisfy { $0 == 0 })
    }

    /// 빠른 연타 겹침(70ms 간격 12타 · 치명 · 쾅 섞어) — 컴프레서 · master 뒤 피크.
    /// 웹 합성도 이 극단 연타에서 0 dBFS 를 살짝 넘는다(컴프레서 시작이 느려 첫 순간이 지나간다) → 녹음 겹침이 합성보다 1 dB 넘게 높지 않을 것
    @Test func fastComboDoesNotClip() {
        var peaks: [Float] = []
        for on in [false, true] {
            let s = Self.synth()
            var r = SplitMix64(seed: 11); var b = SfxBank()
            let seq: [(SfxCue, String)] = [(.hit3(tier: 0, combo: 1), "jab"), (.hit3(tier: 0, combo: 2), "jab"), (.hit3(tier: 1, combo: 3), "cross"),
                                           (.hit3(tier: 1, crit: true, combo: 4), "hook"), (.hit3(tier: 1, combo: 5), "kick"), (.hit3(tier: 2, crit: true, combo: 6), "upper"),
                                           (.hit3(tier: 2, combo: 7, air: true), "round_air"), (.hit3(tier: 2, crit: true, combo: 8, air: true, big: true), "throw"),
                                           (.hitK(.big, crit: true, combo: 0), ""), (.hit3(tier: 1, crit: true, combo: 9), "nv_liver"),
                                           (.hit3(tier: 2, crit: true, combo: 10, big: true), "nv_rise"), (.hit3(tier: 2, crit: true, combo: 10, big: true), "suplex")]
            var out: [Float] = []
            for (c, m) in seq {
                s.play(b.expand(c, context: HitContext(move: m, counter: m == "hook"), sampleHits: on, rng: &r).voices)
                out += s.renderOffline(frames: 3087)   // 70ms
            }
            out += s.renderOffline(frames: 44_100)
            peaks.append(out.map { abs($0) }.max()!)
        }
        #expect(peaks[0] < 1.12 && peaks[1] <= peaks[0] * 1.122, "연타 피크 합성 \(peaks[0]) · 녹음 \(peaks[1])")
    }
}
