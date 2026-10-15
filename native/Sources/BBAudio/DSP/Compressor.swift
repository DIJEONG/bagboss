import Foundation

/// 웹 DynamicsCompressorNode(threshold −14 dB · ratio 4 · 나머지 기본값: knee 30 · attack 3ms · release 250ms)를
/// Chromium DynamicsCompressorKernel 의 알고리즘대로 옮긴 것(모노). 무릎 곡선 · 자동 보정 이득(makeup^0.6) ·
/// 6ms 미리 보기 · 적응형 해제(4차 다항식) · 32표본 단위 엔벌로프까지 같다.
/// 차이: Chromium 은 검출기가 0(최대 감쇠)에서 시작해 맨 앞 0.1초를 크게 누른다 — `warm: true`(기본)면 1에서 시작해 그 시동 잡음을 없앤다.
/// 오디오 스레드에서 할당 없이 돈다(미리 보기 버퍼는 init 에서 한 번).
final class Compressor {
    // 정적 곡선
    private let linearThreshold: Double, kneeThreshold: Double, kneeThresholdDb: Double, ykneeThresholdDb: Double
    private let slope: Double, k: Double
    private let masterLinearGain: Float
    // 동적
    private let attackFrames: Float, satReleaseFrames: Float
    private let kA: Float, kB: Float, kC: Float, kD: Float, kE: Float
    private var detectorAverage: Float
    private var compressorGain: Float = 1
    private var maxAttackCompressionDiffDb: Float = -1
    private var envelopeRate: Float = 1
    private var divisionLeft = 0
    // 미리 보기
    private let delay: UnsafeMutablePointer<Float>
    private let mask: Int
    private let preDelay: Int
    private var w = 0

    init(sampleRate sr: Double, threshold: Double = -14, knee: Double = 30, ratio: Double = 4,
         attack: Double = 0.003, release: Double = 0.25, warm: Bool = true) {
        func db2lin(_ d: Double) -> Double { pow(10, 0.05 * d) }
        func lin2db(_ l: Double) -> Double { 20 * log10(l) }
        let lt = db2lin(threshold)
        let kneeCurve = { (x: Double, k: Double) -> Double in x < lt ? x : lt + (1 - exp(-k * (x - lt))) / k }
        let slopeAt = { (x: Double, k: Double) -> Double in
            if x < lt { return 1 }
            let x2 = x * 1.001
            return (lin2db(kneeCurve(x2, k)) - lin2db(kneeCurve(x, k))) / (lin2db(x2) - lin2db(x))
        }
        let ktDb = threshold + knee, kt = db2lin(ktDb)
        var minK = 0.1, maxK = 10000.0, kk = 5.0
        for _ in 0..<15 {
            if slopeAt(kt, kk) < 1 / ratio { maxK = kk } else { minK = kk }
            kk = (minK * maxK).squareRoot()
        }
        linearThreshold = lt; kneeThreshold = kt; kneeThresholdDb = ktDb; slope = 1 / ratio; k = kk
        ykneeThresholdDb = lin2db(kneeCurve(kt, kk))
        // 자동 보정 이득
        let full = Self.saturate(1, k: kk, lt: lt, kt: kt, ktDb: ktDb, yktDb: lin2db(kneeCurve(kt, kk)), slope: 1 / ratio)
        masterLinearGain = Float(pow(1 / full, 0.6))
        attackFrames = Float(max(0.001, attack) * sr)
        satReleaseFrames = Float(0.0025 * sr)
        let rf = sr * release
        let y1 = Float(rf * 0.09), y2 = Float(rf * 0.16), y3 = Float(rf * 0.42), y4 = Float(rf * 0.98)
        kA = 0.9999999999999998 * y1 + 1.8432219684323923e-16 * y2 - 1.9373394351676423e-16 * y3 + 8.824516011816245e-18 * y4
        kB = -1.5788320352845888 * y1 + 2.3305837032074286 * y2 - 0.9141194204840429 * y3 + 0.1623677525612032 * y4
        kC = 0.5334142869106424 * y1 - 1.272736789213631 * y2 + 0.9258856042207512 * y3 - 0.18656310191776226 * y4
        kD = 0.08783463138207234 * y1 - 0.1694162967925622 * y2 + 0.08588057951595272 * y3 - 0.00429891410546283 * y4
        kE = -0.042416883008123074 * y1 + 0.1115693827987602 * y2 - 0.09764676325265872 * y3 + 0.028494263462021576 * y4
        detectorAverage = warm ? 1 : 0
        preDelay = Int(0.006 * sr)
        var n = 1; while n < preDelay * 2 + 2 { n <<= 1 }
        mask = n - 1
        delay = .allocate(capacity: n); delay.initialize(repeating: 0, count: n)
    }
    deinit { delay.deallocate() }

    private static func saturate(_ x: Double, k: Double, lt: Double, kt: Double, ktDb: Double, yktDb: Double, slope: Double) -> Double {
        if x < kt { return x < lt ? x : lt + (1 - exp(-k * (x - lt))) / k }
        let xDb = 20 * log10(x)
        return pow(10, 0.05 * (yktDb + slope * (xDb - ktDb)))
    }
    @inline(__always) private func saturate(_ x: Float) -> Float {
        Float(Self.saturate(Double(x), k: k, lt: linearThreshold, kt: kneeThreshold, ktDb: kneeThresholdDb, yktDb: ykneeThresholdDb, slope: slope))
    }

    /// 32표본마다: 원하는 이득 · 공격/해제 속도 다시 잡기
    private func updateDivision() {
        let desired = detectorAverage
        let scaledDesired = asin(min(1, max(0, desired))) / (0.5 * .pi)
        let releasing = scaledDesired > compressorGain
        var diffDb = 20 * log10(compressorGain / scaledDesired)
        if releasing {
            maxAttackCompressionDiffDb = -1
            if !diffDb.isFinite { diffDb = -1 }
            var x = min(0, max(-12, diffDb))
            x = 0.25 * (x + 12)
            let x2 = x * x, x3 = x2 * x, x4 = x2 * x2
            let releaseFrames = kA + kB * x + kC * x2 + kD * x3 + kE * x4
            envelopeRate = powf(10, 0.05 * (5 / releaseFrames))
        } else {
            if !diffDb.isFinite { diffDb = 1 }
            if maxAttackCompressionDiffDb == -1 || maxAttackCompressionDiffDb < diffDb { maxAttackCompressionDiffDb = diffDb }
            let eff = max(0.5, maxAttackCompressionDiffDb)
            envelopeRate = 1 - powf(0.25 / eff, 1 / attackFrames)
        }
        scaledDesiredGain = scaledDesired
    }
    private var scaledDesiredGain: Float = 1

    /// 표본 하나 처리
    @inline(__always) func process(_ x: Float) -> Float {
        if divisionLeft == 0 { updateDivision(); divisionLeft = 32 }
        divisionLeft -= 1
        // 미리 보기: 지금 입력은 넣고, preDelay 전 입력을 내보낸다
        delay[w & mask] = x
        let delayed = delay[(w - preDelay) & mask]
        w &+= 1
        // 검출기(지연 전 입력)
        let absIn = abs(x)
        let attenuation: Float = absIn <= 0.0001 ? 1 : saturate(absIn) / absIn
        let attDb = max(2, -20 * log10(attenuation))
        let satReleaseRate = powf(10, 0.05 * (attDb / satReleaseFrames)) - 1
        let rate: Float = attenuation > detectorAverage ? satReleaseRate : 1
        detectorAverage += (attenuation - detectorAverage) * rate
        detectorAverage = min(1, detectorAverage)
        if detectorAverage.isNaN { detectorAverage = 1 }
        // 이득 엔벌로프
        if envelopeRate < 1 { compressorGain += (scaledDesiredGain - compressorGain) * envelopeRate }
        else { compressorGain = min(1, compressorGain * envelopeRate) }
        let post = sinf(0.5 * .pi * compressorGain)
        return delayed * masterLinearGain * post
    }
}
