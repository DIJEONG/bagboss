import Foundation
@testable import BBAudio
import BBCore
import BBContent

/// tools/js/extract/sfx.mjs 의 특징 계산과 같은 식(RMS 포락 · 스펙트럼 무게중심 · 최댓값 · 길이).
struct AudioFeatures: Equatable {
    var env: [Double]
    var peakDb: Double
    var dur: Double
    var centroid: Double

    static func of(_ renders: [[Float]], sr: Double, hopMs: Double = 5, win: Int = 512, hop: Int = 256) -> AudioFeatures {
        let h = Int((sr * hopMs / 1000).rounded())
        let envs: [[Double]] = renders.map { x in
            stride(from: 0, to: x.count, by: h).map { i in
                let e = min(x.count, i + h)
                var s = 0.0; for j in i..<e { s += Double(x[j]) * Double(x[j]) }
                return s / Double(e - i)
            }
        }
        let n = envs.map(\.count).min() ?? 0
        let env = (0..<n).map { i in (envs.reduce(0) { $0 + $1[i] } / Double(envs.count)).squareRoot() }
        let peak = renders.reduce(0.0) { $0 + Double($1.map { abs($0) }.max() ?? 0) } / Double(renders.count)
        var fp = 0.0, p = 0.0
        for x in renders {
            var i = 0
            while i + win <= x.count {
                let w = (0..<win).map { j in Double(x[i + j]) * (0.5 - 0.5 * cos(2 * .pi * Double(j) / Double(win))) }
                let m = fftMag2(w)
                for k in 1..<m.count { fp += Double(k) * sr / Double(win) * m[k]; p += m[k] }
                i += hop
            }
        }
        let emax = env.max() ?? 0
        var last = 0
        for (i, e) in env.enumerated() where e > emax * pow(10, -40.0 / 20) { last = i }
        return AudioFeatures(env: env, peakDb: 20 * log10(peak + 1e-12), dur: Double(last + 1) * hopMs / 1000, centroid: p > 0 ? fp / p : 0)
    }

    /// 실수 입력 → |X|²(0…N/2), 단순 radix-2
    static func fftMag2(_ input: [Double]) -> [Double] {
        let N = input.count
        var re = input, im = [Double](repeating: 0, count: N)
        var j = 0
        for i in 1..<N {
            var b = N >> 1
            while j & b != 0 { j ^= b; b >>= 1 }
            j ^= b
            if i < j { re.swapAt(i, j) }
        }
        var len = 2
        while len <= N {
            let a = -2 * Double.pi / Double(len)
            for i in stride(from: 0, to: N, by: len) {
                for k in 0..<(len / 2) {
                    let wr = cos(a * Double(k)), wi = sin(a * Double(k))
                    let u = i + k, v = i + k + len / 2
                    let xr = re[v] * wr - im[v] * wi, xi = re[v] * wi + im[v] * wr
                    re[v] = re[u] - xr; im[v] = im[u] - xi; re[u] += xr; im[u] += xi
                }
            }
            len <<= 1
        }
        return (0...(N / 2)).map { re[$0] * re[$0] + im[$0] * im[$0] }
    }

    /// 피어슨 상관(짧은 쪽 길이까지)
    static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 1 else { return 0 }
        let ma = a[..<n].reduce(0, +) / Double(n), mb = b[..<n].reduce(0, +) / Double(n)
        var sab = 0.0, saa = 0.0, sbb = 0.0
        for i in 0..<n { let x = a[i] - ma, y = b[i] - mb; sab += x * y; saa += x * x; sbb += y * y }
        return saa > 0 && sbb > 0 ? sab / (saa * sbb).squareRoot() : 0
    }
}

/// 웹 픽스처(native/Tests/Fixtures/audio/sfx.json)
struct SfxFixture: Decodable {
    struct Feat: Decodable { let env: [Double]; let peakDb: Double; let dur: Double; let centroid: Double }
    struct Item: Decodable { let id: String; let code: String; let dur: Double; let dry: Feat; let wet: Feat?; let samples: String? }
    let sourceSha16: String
    let sr: Double
    let wetPreroll: Int
    let envHopMs: Double
    let seeds: Int
    let items: [Item]

    static let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/audio/sfx.json")
    static let shared: SfxFixture = try! JSONDecoder().decode(SfxFixture.self, from: Data(contentsOf: url))

    func item(_ id: String) -> Item { items.first { $0.id == id }! }

    /// base64 Int16 → Float
    static func decodeSamples(_ b64: String) -> [Float] {
        let d = Data(base64Encoded: b64)!
        return d.withUnsafeBytes { raw in raw.bindMemory(to: Int16.self).map { Float($0) / 32767 } }
    }
}

/// 네이티브 쪽: 픽스처 id → 같은 소리
enum NativeSfx {
    static let content: ContentStore = try! ContentStore.bundled()
    static let blip: BlipVoice = try! BlipVoice(content: content)

    static func cue(_ id: String) -> SfxCue? {
        switch id {
        case "clack": .clack(speed: 600)
        case "hit_light": .hit(heavy: false, crit: false)
        case "hit_heavy": .hit(heavy: true, crit: false)
        case "hit_heavy_crit": .hit(heavy: true, crit: true)
        case "hitK_jab": .hitK(.jab, crit: false, combo: 0)
        case "hitK_punch": .hitK(.punch, crit: false, combo: 0)
        case "hitK_hammer": .hitK(.hammer, crit: false, combo: 0)
        case "hitK_kick": .hitK(.kick, crit: false, combo: 0)
        case "hitK_throw": .hitK(.big, crit: false, combo: 0)
        case "hitK_punch_crit_c5": .hitK(.punch, crit: true, combo: 5)
        case "hit3_0": .hit3(tier: 0)
        case "hit3_1": .hit3(tier: 1)
        case "hit3_2": .hit3(tier: 2)
        case "hit3_2_big": .hit3(tier: 2, big: true)
        case "hit3_1_air_c4": .hit3(tier: 1, combo: 4, air: true)
        case "hit3_0_crit": .hit3(tier: 0, crit: true)
        case "just": .just
        case "floor_05": .floor(0.5)
        case "floor_15": .floor(1.5)
        case "thud": .thud
        case "swing": .swing
        case "hurt": .hurt(heavy: false)
        case "hurt_heavy": .hurt(heavy: true)
        case "glass": .glass
        case "boom": .boom
        case "whoosh": .whoosh
        case "dodge": .dodge
        case "press": .press
        case "chime": .chime
        case "door_open": .door(open: true)
        case "door_close": .door(open: false)
        case "click": .click
        case "coin": .coin
        case "merge_ok": .merge(ok: true)
        case "merge_fail": .merge(ok: false)
        case "clear": .clear
        case "slowIn": .slowIn
        case "carHit": .carHit(heavy: false)
        case "carHit_heavy": .carHit(heavy: true)
        case "gong": .gong
        case "ready": .ready
        case "brass": .brass
        case "rage": .rage
        case "hiss": .hiss
        case "pass": .pass
        case "zap": .zap
        case "unlock": .unlock
        case "skTone_glint": .skTone(f0: 1500, f1: 2200, dur: 0.07, wave: .sine, vol: 0.05)
        case "skNoise_rain": .skNoise(dur: 0.55, f: 130, g: 0.14)
        case "beep_final": .countdownBeep(final: true)
        case "door_creak": .doorCreak
        default: nil
        }
    }

    /// 픽스처 하나를 네이티브로 그린다(웹 하네스와 같은 조건: 기본 볼륨 · master 1 · dry 는 컴프레서 없이)
    static func render(_ id: String, dur: Double, sr: Double, seed: UInt64, wet: Bool = false, preroll: Int = 0) -> [Float] {
        var o = SynthCore.Options(); o.compressor = wet; o.warmCompressor = false; o.chromeQuantumQuirk = true
        let synth = SynthCore(sampleRate: sr, options: o)
        synth.setMix(SoundSettings(vol: .init(master: 1)), immediate: true)
        if preroll > 0 { _ = synth.renderOffline(frames: preroll) }
        var rng = SplitMix64(seed: seed)
        var bank = SfxBank()
        if let cue = cue(id) {
            let e = bank.expand(cue, now: 0, rng: &rng)
            synth.play(e.voices)
            if let d = e.duck { synth.duck(d) }
        } else if id.hasPrefix("blip_") {
            let (who, ch): (String, Character) = switch id {
            case "blip_cond": ("cond", "가")
            case "blip_saboo": ("saboo", "하")
            case "blip_minnie": ("minnie", "A")
            default: ("me", "오")
            }
            synth.play(blip.voice(who: who, char: ch, rng: &rng)!)
        } else if id == "duck_big" {
            var bg = VoiceSpec(source: .osc(.sine), stop: 100)
            bg.bus = .music; bg.freq = .constant(110); bg.gain = .constant(0.25)
            synth.play(bg)
            synth.duck(Duck(k: 0.32, hold: 0.14, rel: 0.36))
        } else {
            fatalError("모르는 픽스처 id \(id)")
        }
        return synth.renderOffline(frames: Int((sr * dur).rounded()))
    }
}
