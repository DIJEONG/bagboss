import Foundation

/// 웹 BiquadFilterNode.type (게임이 쓰는 것 + 쓸 만한 것)
public enum FilterType: UInt8, Sendable {
    case none, lowpass, highpass, bandpass, peaking

    public init?(web: String) {
        switch web {
        case "lowpass": self = .lowpass
        case "highpass": self = .highpass
        case "bandpass": self = .bandpass
        case "peaking": self = .peaking
        default: return nil
        }
    }
}

/// 2차 IIR 필터 — 계수식은 Web Audio 명세(= Chromium Biquad.cc)와 같다.
/// lowpass · highpass 의 Q 는 데시벨(공진), bandpass · peaking 의 Q 는 보통의 Q. 직접형 I, 상태는 Double.
struct Biquad {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    private(set) var lastFreq = -1.0

    /// 계수 계산. freq(Hz) 는 [0, 나이퀴스트]로 자른다.
    mutating func set(_ type: FilterType, freq: Double, q: Double, gainDb: Double = 0, sampleRate: Double) {
        lastFreq = freq
        let nyq = sampleRate / 2
        let f = max(0, min(1, freq / nyq))      // 정규화 주파수
        var nb0 = 1.0, nb1 = 0.0, nb2 = 0.0, na0 = 1.0, na1 = 0.0, na2 = 0.0
        switch type {
        case .none:
            break
        case .lowpass:
            if f >= 1 { break }                  // 통과
            if f > 0 {
                let w0 = Double.pi * f, alpha = 0.5 * sin(w0) * pow(10, -0.05 * q), k = cos(w0)
                nb0 = (1 - k) / 2; nb1 = 1 - k; nb2 = (1 - k) / 2
                na0 = 1 + alpha; na1 = -2 * k; na2 = 1 - alpha
            } else { nb0 = 0 }
        case .highpass:
            if f >= 1 { nb0 = 0; break }
            if f > 0 {
                let w0 = Double.pi * f, alpha = 0.5 * sin(w0) * pow(10, -0.05 * q), k = cos(w0)
                nb0 = (1 + k) / 2; nb1 = -(1 + k); nb2 = (1 + k) / 2
                na0 = 1 + alpha; na1 = -2 * k; na2 = 1 - alpha
            }
        case .bandpass:
            if f > 0 && f < 1 {
                if q > 0 {
                    let w0 = Double.pi * f, alpha = sin(w0) / (2 * q), k = cos(w0)
                    nb0 = alpha; nb1 = 0; nb2 = -alpha
                    na0 = 1 + alpha; na1 = -2 * k; na2 = 1 - alpha
                }
            } else { nb0 = 0 }
        case .peaking:
            let A = pow(10, gainDb / 40)
            if f > 0 && f < 1 {
                if q > 0 {
                    let w0 = Double.pi * f, alpha = sin(w0) / (2 * q), k = cos(w0)
                    nb0 = 1 + alpha * A; nb1 = -2 * k; nb2 = 1 - alpha * A
                    na0 = 1 + alpha / A; na1 = -2 * k; na2 = 1 - alpha / A
                } else { nb0 = A * A }
            }
        }
        b0 = nb0 / na0; b1 = nb1 / na0; b2 = nb2 / na0; a1 = na1 / na0; a2 = na2 / na0
    }

    @inline(__always) mutating func process(_ x: Float) -> Float {
        let xd = Double(x)
        let y = b0 * xd + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = xd; y2 = y1; y1 = y
        return Float(y)
    }

    mutating func reset() { x1 = 0; x2 = 0; y1 = 0; y2 = 0 }
}
