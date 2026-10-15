import Foundation
import Testing
@testable import BBAudio

/// DSP 핵심 부품: 자동화(명세 의미) · 필터 계수 · 파형표 · 컴프레서
@Suite struct DSPTests {
    @Test func paramTimelineFollowsWebAudioSpec() {
        var tl = ParamTimeline(1)
        tl.set(0, at: 0); tl.linear(to: 0.5, at: 0.01); tl.exponential(to: 0.001, at: 0.5)
        #expect(tl.value(at: -0.1) == 1)                         // 첫 사건 전: 기본값
        #expect(abs(tl.value(at: 0.005) - 0.25) < 1e-12)          // 선형 중간
        #expect(abs(tl.value(at: 0.01) - 0.5) < 1e-12)
        let mid = 0.01 + 0.49 / 2                                  // 지수 중간 = 기하 평균
        #expect(abs(tl.value(at: mid) - (0.5 * 0.001).squareRoot()) < 1e-9)
        #expect(tl.value(at: 9) == 0.001)                          // 끝난 뒤: 마지막 값 유지
        // 부호가 다르거나 0 에서 시작하는 지수 램프: 끝날 때까지 앞 값 유지
        var z = ParamTimeline(1); z.set(0, at: 0); z.exponential(to: 1, at: 1)
        #expect(z.value(at: 0.5) == 0)
        #expect(z.value(at: 1) == 1)
    }

    @Test func cursorMatchesTimelinePerSample() {
        var tl = ParamTimeline(440)
        tl.set(300, at: 0); tl.exponential(to: 2600, at: 0.08); tl.exponential(to: 500, at: 0.7)
        for off in [0.0, 0.5] {
            var c = ParamCursor(tl, sampleRate: 22050, offsetFrames: off)
            var worst = 0.0
            for n in 0..<22050 {
                let a = c.next(), b = tl.value(at: (Double(n) + off) / 22050)
                worst = max(worst, abs(a - b) / b)
            }
            #expect(worst < 1e-9, "증분 계산 오차 \(worst)")
        }
    }

    @Test func targetParamIsExponentialApproach() {
        var p = TargetParam(0)
        p.setTarget(1, tc: 0.1, sampleRate: 1000)
        for _ in 0..<100 { p.step() }
        #expect(abs(p.value - (1 - exp(-1))) < 1e-9)              // τ 만큼 지나면 63.2%
        var q = TargetParam(0); q.setTarget(1, tc: 0.1, sampleRate: 1000); q.step(100)
        #expect(abs(q.value - p.value) < 1e-12)
    }

    /// 주파수 응답(정상 상태 사인 입력의 이득)
    static func gain(_ type: FilterType, f0: Double, q: Double, at f: Double, sr: Double = 48000) -> Double {
        var b = Biquad(); b.set(type, freq: f0, q: q, sampleRate: sr)
        var peak: Float = 0
        for n in 0..<Int(sr) {
            let y = b.process(Float(sin(2 * .pi * f * Double(n) / sr)))
            if n > Int(sr) / 2 { peak = max(peak, abs(y)) }
        }
        return Double(peak)
    }

    @Test func biquadResponses() {
        #expect(abs(Self.gain(.lowpass, f0: 1000, q: 0, at: 50) - 1) < 0.01)       // 통과 대역 1
        #expect(Self.gain(.lowpass, f0: 1000, q: 0, at: 8000) < 0.03)               // 12 dB/oct
        #expect(abs(Self.gain(.lowpass, f0: 1000, q: 0, at: 1000) - pow(10, 0 / 20.0) / 1) < 0.02)   // Q 0 dB → 차단 주파수 이득 1(공진 0 dB)
        #expect(abs(Self.gain(.lowpass, f0: 1000, q: 6, at: 1000) - pow(10, 6 / 20.0)) < 0.05)       // Q 는 dB 공진
        #expect(Self.gain(.highpass, f0: 1000, q: 0, at: 50) < 0.01)
        #expect(abs(Self.gain(.bandpass, f0: 1000, q: 4, at: 1000) - 1) < 0.01)     // 중심 이득 1
        #expect(Self.gain(.bandpass, f0: 1000, q: 4, at: 4000) < 0.1)
        #expect(abs(Self.gain(.peaking, f0: 1000, q: 1, at: 1000) - 1) < 0.01)      // 이득 0 dB 면 평탄
    }

    @Test func waveformsAreNormalizedAndStartAtZero() {
        let t = WaveTableSet.shared(sampleRate: 22050)
        for w in Waveform.allCases {
            var o = Oscillator(w, tables: t)
            var peak: Float = 0, first: Float = 9, sum = 0.0
            for n in 0..<22050 {
                let v = o.next(freq: 110, sampleRate: 22050)
                if n == 0 { first = v }
                peak = max(peak, abs(v)); sum += Double(v)
            }
            #expect(abs(first) < 1e-6, "\(w) 첫 값 \(first)")
            #expect(peak > 0.97 && peak < 1.03, "\(w) 최댓값 \(peak)")     // 깁스 넘침 포함 최댓값 ≈ 1
            #expect(abs(sum / 22050) < 0.01, "\(w) 직류")
        }
        // 높은 음: 배음이 나이퀴스트를 넘지 않는다(4kHz 사각 → 3배음 12kHz > 11.025kHz 라 사인에 가까워야)
        var sq = Oscillator(.square, tables: t)
        var e3 = 0.0
        let x = (0..<2048).map { _ in Double(sq.next(freq: 4000, sampleRate: 22050)) }
        let m = x.indices.map { i in x[i] * (0.5 - 0.5 * cos(2 * .pi * Double(i) / 2048)) }
        let mag = AudioFeatures.fftMag2(m)
        for k in mag.indices where Double(k) * 22050 / 2048 > 6000 { e3 += mag[k] }
        #expect(e3 / mag.reduce(0, +) < 1e-3, "4kHz 사각의 접힘 에너지 \(e3 / mag.reduce(0, +))")
    }

    @Test func compressorStaticCurveAndMakeup() {
        // 조용한 소리: 문턱(−14 dB) 아래 → 보정 이득만큼 커진다(약 +0.6 dB)
        let c = Compressor(sampleRate: 22050)
        var outPeak: Float = 0
        for n in 0..<22050 { outPeak = max(outPeak, abs(c.process(0.05 * Float(sin(2 * .pi * 440 * Double(n) / 22050))))) }
        let lift = 20 * log10(Double(outPeak) / 0.05)
        #expect(lift > 0.2 && lift < 1.2, "보정 이득 \(lift) dB")
        // 큰 소리(0 dBFS)는 눌린다
        let c2 = Compressor(sampleRate: 22050)
        var p2: Float = 0
        for n in 0..<22050 { let y = c2.process(Float(sin(2 * .pi * 440 * Double(n) / 22050))); if n > 11025 { p2 = max(p2, abs(y)) } }
        let loudGain = 20 * log10(Double(p2))
        #expect(loudGain < lift - 0.5, "0 dBFS 이득 \(loudGain) dB · 조용한 소리 \(lift) dB")    // 큰 소리일수록 덜 키운다(무릎 30 dB 라 완만 — 웹 wet 대조가 곡선 자체를 검증)
        #expect(p2 <= 1.0)
    }
}
