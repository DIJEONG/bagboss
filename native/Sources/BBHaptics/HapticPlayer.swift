import Foundation

#if os(iOS)
import CoreHaptics
import UIKit

/// 진동 재생(iOS). Core Haptics 를 우선 쓰고, 지원하지 않는 기기는 UIImpactFeedbackGenerator 로 대체한다.
@MainActor
public final class HapticPlayer {
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .heavy)
    public init() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { @Sendable [weak self] in Task { @MainActor in try? self?.engine?.start() } }
            try? engine?.start()
        }
        fallback.prepare()
    }

    public func play(_ pulses: [HapticPulse]) {
        guard !pulses.isEmpty else { return }
        guard let engine else {
            for p in pulses {   // 대체: 세기만 반영
                let f = fallback
                if p.offset == 0 { f.impactOccurred(intensity: p.intensity) }
                else { Task { @MainActor in try? await Task.sleep(nanoseconds: UInt64(p.offset * 1e9)); f.impactOccurred(intensity: p.intensity) } }
            }
            return
        }
        var events: [CHHapticEvent] = []
        for p in pulses {
            let params = [CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(p.intensity)),
                          CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(p.sharpness))]
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: p.offset))
            if p.tail > 0 {   // 여운: 충격 직후 낮고 짧게
                let tail = [CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(p.intensity * 0.45)),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(max(0, p.sharpness - 0.25)))]
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: tail, relativeTime: p.offset + 0.01, duration: p.tail))
            }
        }
        do { try engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: CHHapticTimeImmediate) }
        catch { try? engine.start() }
    }
}
#endif
