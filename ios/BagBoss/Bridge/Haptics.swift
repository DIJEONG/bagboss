import UIKit

/// 게임의 buzz(ms | [on, off, on, …]) 패턴 → UIImpactFeedbackGenerator.
/// 지금 게임이 쓰는 값: 16(넘어뜨림 · 치명타) · 28(큰 치명타) · 25(주인공 피격 — 가장 잦음) · 50(KA-BOOM!) · 70(두목 등장)
///                   [40,30,60](필살기) · [50,30,80](차 부수기)
/// 매핑(1단계 초안 — 실기기에서 손맛 보고 조정): ~19ms 가볍게 · ~35ms 중간 · ~60ms 무겁게 · 그 이상 무겁게 최대
@MainActor
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private var lastFire: CFTimeInterval = 0
    var enabled = true
    /// 너무 촘촘한 연타(다단 히트)는 뭉갠다
    var minInterval: CFTimeInterval = 0.045

    func prepare() {
        light.prepare(); medium.prepare(); heavy.prepare()
    }

    func play(pattern: [Int]) {
        guard enabled, !pattern.isEmpty else { return }
        let now = CACurrentMediaTime()
        if now - lastFire < minInterval { return }
        lastFire = now

        var offsetMs = 0
        for (index, ms) in pattern.enumerated() {
            defer { offsetMs += max(0, ms) }
            guard index % 2 == 0, ms > 0 else { continue }      // 짝수 칸 = 울림, 홀수 칸 = 쉼
            let delay = offsetMs
            if delay == 0 {
                fire(ms)
            } else {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
                    self?.fire(ms)
                }
            }
        }
    }

    private func fire(_ ms: Int) {
        let (generator, intensity): (UIImpactFeedbackGenerator, CGFloat)
        switch ms {
        case ..<20: (generator, intensity) = (light, 0.75)
        case ..<36: (generator, intensity) = (medium, 0.85)
        case ..<61: (generator, intensity) = (heavy, 0.9)
        default:    (generator, intensity) = (heavy, 1.0)
        }
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }
}
