import Foundation
import Testing
@testable import BBAudio

/// 파형표 누적합 생성(시작 시간 최적화 — docs/06 §8)이 예전 방식(범위마다 1부터 다시 더하기)과 비트 단위로 같은지
@Suite struct WaveTableSpeedTests {
    /// 예전 구현 그대로(범위 r 하나의 곧은 표 — 정규화 전)
    static func legacy(size: Int, shape: Waveform, range r: Int) -> [Double] {
        let half = size / 2
        let sinT = (0..<size).map { sin(2 * Double.pi * Double($0) / Double(size)) }
        let coef: [Double] = (0..<half).map { n in
            guard n > 0 else { return 0 }
            let pn = Double.pi * Double(n)
            switch shape {
            case .square: return n & 1 == 1 ? 4 / pn : 0
            case .sawtooth: return (n & 1 == 1 ? 2 : -2) / pn
            case .triangle: return n & 1 == 1 ? (8 / (pn * pn)) * (n & 2 != 0 ? -1 : 1) : 0
            case .sine: return n == 1 ? 1 : 0
            }
        }
        var buf = [Double](repeating: 0, count: size)
        let partials = min(half - 1, Int(pow(2, -Double(r) / 3) * Double(half)))
        if partials >= 1 {
            for n in 1...partials where coef[n] != 0 {
                let c = coef[n]; var idx = 0
                for i in 0..<size { buf[i] += c * sinT[idx]; idx += n; if idx >= size { idx -= size } }
            }
        }
        return buf
    }

    @Test("24kHz(표 2048) 모든 모양 · 범위가 예전 구현과 비트 단위로 같다") func matchesLegacy() {
        let t = WaveTableSet(sampleRate: 22_050)
        for (si, shape) in [Waveform.square, .sawtooth, .triangle].enumerated() {
            let r0 = Self.legacy(size: t.size, shape: shape, range: 0)
            let scale = 1 / max(1e-12, r0.map { abs($0) }.max() ?? 1)
            for r in [0, 1, 2, 5, 9, 17, t.ranges - 2, t.ranges - 1] {
                let want = Self.legacy(size: t.size, shape: shape, range: r).map { Float($0 * scale) }
                let got = t.rawTable(shape: si, range: r)
                #expect(Array(got.prefix(t.size)) == want, "모양 \(si) 범위 \(r)")
                #expect(got[t.size] == got[0])
            }
        }
    }
}
