import Foundation

// 소리 원천: 발진기(웹 OscillatorNode 4종) · 백색/갈색 잡음.

/// 웹 OscillatorNode.type
public enum Waveform: UInt8, Sendable, CaseIterable {
    case sine, square, sawtooth, triangle

    /// 웹 문자열('sine' · 'square' · 'sawtooth' · 'triangle')에서
    public init?(web: String) {
        switch web {
        case "sine": self = .sine
        case "square": self = .square
        case "sawtooth": self = .sawtooth
        case "triangle": self = .triangle
        default: return nil
        }
    }
}

/// 발진기 — Chromium 내장 파형과 같은 모양 · 위상 · 크기(WaveTableSet 참고).
/// 모두 위상 0 에서 0 으로 시작한다(사인 · 삼각 · 톱니는 올라가며, 사각은 앞 반주기 +).
/// 표 참조는 unowned(unsafe) — 오디오 스레드에서 복사해도 참조 계수를 건드리지 않는다(표는 SynthCore 가 쥐고 있다).
struct Oscillator {
    var wave: Waveform
    var phase = 0.0   // [0, 1)
    unowned(unsafe) let tables: WaveTableSet

    init(_ wave: Waveform, tables: WaveTableSet, phase: Double = 0) { self.wave = wave; self.tables = tables; self.phase = phase }

    /// 현재 위상의 값을 내고 freq(Hz)만큼 나아간다(웹과 같은 순서: 출력 → 위상 증가).
    @inline(__always) mutating func next(freq: Double, sampleRate: Double) -> Float {
        let v = tables.sample(wave, phase: phase, freq: freq)
        phase += freq / sampleRate
        phase -= phase.rounded(.down)
        return v
    }
}

/// 작은 결정적 난수(xorshift32) — 오디오 스레드에서 표본마다 부른다. 씨앗은 주입받은 GameRandom 에서 꺼낸다.
struct NoiseRNG {
    var s: UInt32
    init(seed: UInt32) { s = seed == 0 ? 0x9E37_79B9 : seed }
    /// 백색 잡음 [−1, 1) — 웹 `Math.random()*2-1`
    @inline(__always) mutating func white() -> Float {
        s ^= s << 13; s ^= s >> 17; s ^= s << 5
        return Float(s >> 8) * (2.0 / 16_777_216.0) - 1
    }
}

/// 웹 SND.brown 과 같은 식: last = (last + .02·w)/1.02, 출력 last·3.5
struct BrownNoise {
    var last: Float = 0
    @inline(__always) mutating func next(_ w: Float) -> Float {
        last = (last + 0.02 * w) / 1.02
        return last * 3.5
    }
}
