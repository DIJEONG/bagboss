import Foundation
import Testing
@testable import BBAudio

/// 웹 효과음(OfflineAudioContext) ↔ 네이티브 DSP 대조. 기준: tools/js/extract/sfx.mjs → Fixtures/audio/sfx.json
/// 무작위가 섞인 소리는 시드 여러 개의 평균 특징끼리 비교한다(웹 · 네이티브 모두 같은 개수).
@Suite struct SfxParityTests {
    static let fx = SfxFixture.shared

    struct Result: CustomStringConvertible {
        let id: String
        let corr: Double, dPeak: Double, centroidRatio: Double, dDur: Double
        var description: String {
            String(format: "%-20@ 상관 %.3f · 최댓값 %+.2f dB · 무게중심 ×%.3f · 길이 %+.0f ms", id as NSString, corr, dPeak, centroidRatio, dDur * 1000)
        }
    }

    static func compare(_ web: SfxFixture.Feat, _ nat: AudioFeatures, id: String) -> Result {
        Result(id: id, corr: AudioFeatures.correlation(web.env, nat.env), dPeak: nat.peakDb - web.peakDb,
               centroidRatio: web.centroid > 0 ? nat.centroid / web.centroid : 1, dDur: nat.dur - web.dur)
    }

    static func native(_ it: SfxFixture.Item, wet: Bool) -> AudioFeatures {
        let renders = (0..<fx.seeds).map { s in
            NativeSfx.render(it.id, dur: it.dur, sr: fx.sr, seed: UInt64(1000 + s), wet: wet, preroll: wet ? fx.wetPreroll : 0)
        }
        return AudioFeatures.of(renders, sr: fx.sr, hopMs: fx.envHopMs)
    }

    @Test("dry 대조: 포락 상관 > 0.95 · 최댓값 ±1.5 dB · 무게중심 ±15% · 길이 ±max(25ms, 10%)", arguments: SfxFixture.shared.items.map(\.id))
    func dry(_ id: String) {
        let it = Self.fx.item(id)
        let r = Self.compare(it.dry, Self.native(it, wet: false), id: id)
        print("[dry] \(r)")
        #expect(r.corr > 0.95, "\(r)")
        #expect(abs(r.dPeak) <= 1.5, "\(r)")
        #expect(abs(r.centroidRatio - 1) <= 0.15, "\(r)")
        #expect(abs(r.dDur) <= max(0.025, it.dry.dur * 0.1), "\(r)")   // 포락 칸 5ms · 무작위 지연 소리 여유
    }

    @Test("wet 대조(컴프레서 포함)", arguments: SfxFixture.shared.items.filter { $0.wet != nil }.map(\.id))
    func wet(_ id: String) {
        let it = Self.fx.item(id)
        let r = Self.compare(it.wet!, Self.native(it, wet: true), id: id)
        print("[wet] \(r)")
        #expect(r.corr > 0.95, "\(r)")
        #expect(abs(r.dPeak) <= 1.5, "\(r)")
        #expect(abs(r.centroidRatio - 1) <= 0.15, "\(r)")
    }

    /// 잡음 없는 소리는 표본 그대로 비교한다(시드 1000 한 번)
    @Test("표본 대조(잡음 없는 소리)", arguments: SfxFixture.shared.items.filter { $0.samples != nil && $0.id != "duck_big" }.map(\.id))
    func samples(_ id: String) {
        let it = Self.fx.item(id)
        let web = SfxFixture.decodeSamples(it.samples!)
        let nat = NativeSfx.render(id, dur: it.dur, sr: Self.fx.sr, seed: 1000)
        let c = AudioFeatures.correlation(web.map(Double.init), nat.map(Double.init))
        var err = 0.0, ref = 0.0
        for i in 0..<min(web.count, nat.count) { err += Double(web[i] - nat[i]) * Double(web[i] - nat[i]); ref += Double(web[i]) * Double(web[i]) }
        let snr = 10 * log10(ref / max(err, 1e-20))
        print(String(format: "[표본] %@ 상관 %.4f · 신호 대 오차 %.1f dB", id, c, snr))
        #expect(c > 0.98, "\(id) 상관 \(c)")
    }

    /// 덕킹: 110Hz 배경음이 k=.32 로 눌렸다 되돌아오는 모양(표본 포락)
    @Test func duckEnvelope() {
        let it = Self.fx.item("duck_big")
        let web = SfxFixture.decodeSamples(it.samples!)
        let nat = NativeSfx.render("duck_big", dur: it.dur, sr: Self.fx.sr, seed: 1000)
        let c = AudioFeatures.correlation(web.map(Double.init), nat.map(Double.init))
        #expect(c > 0.995, "덕킹 표본 상관 \(c)")
    }
}
