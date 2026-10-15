import Testing
@testable import BBCore

@Suite struct RNGTests {
    /// 웹 mulberry(seed) 의 처음 네 값(node 로 뽑은 기준값)과 비트 단위로 같아야 한다.
    @Test(arguments: [
        (Int32(5150), [0.3736589092295617, 0.6026743419934064, 0.17008373467251658, 0.9058269723318517]),
        (Int32(0), [0.26642920868471265, 0.0003297457005828619, 0.2232720274478197, 0.1462021479383111]),
        (Int32(-7), [0.43306733411736786, 0.32539576734416187, 0.5442695003002882, 0.48018999374471605]),
        (Int32(20261009), [0.2487912888173014, 0.41786690312437713, 0.04105158778838813, 0.2528557500336319]),
    ])
    func mulberryMatchesWeb(seed: Int32, expected: [Double]) {
        var r = Mulberry32(seed: seed)
        #expect((0..<4).map { _ in r.next() } == expected)
    }

    @Test func splitMixKnownVector() {
        var r = SplitMix64(seed: 0)
        #expect(r.nextUInt64() == 0xE220_A839_7B1D_CDAF)
    }

    @Test func splitStreamsAreIndependentAndRepeatable() {
        var a = SplitMix64(seed: 42), b = SplitMix64(seed: 42)
        var fxA = a.split(), fxB = b.split()
        #expect(a.nextUInt64() == b.nextUInt64())
        #expect(fxA.nextUInt64() == fxB.nextUInt64())
        var c = SplitMix64(seed: 42); _ = c.split()
        // 연출 스트림을 더 뽑아도 규칙 스트림은 그대로
        _ = fxA.nextUInt64(); _ = fxA.nextUInt64()
        #expect(a.nextUInt64() == { var x = c; _ = x.nextUInt64(); return x.nextUInt64() }())
    }

    @Test func rangeHelpersStayInBounds() {
        var r = SplitMix64(seed: 7)
        for _ in 0..<10_000 {
            let v = r.next(); #expect(v >= 0 && v < 1)
            let i = r.int(5); #expect((0..<5).contains(i))
        }
    }
}

@Suite struct ClockTests {
    @Test func animFrameIsThreeTicks() { #expect(SimTime.ticksPerAnimFrame == 3) }   // 게임 모드 20fps

    @Test func accumulatorKeepsRemainder() {
        var acc = FixedStepAccumulator()
        var total = 0
        for _ in 0..<120 { total += acc.ticks(frameSeconds: 1.0 / 120, scale: 1) }   // 120Hz 화면 1초
        #expect(total == 60)
        var slow = FixedStepAccumulator()
        total = 0
        for _ in 0..<60 { total += slow.ticks(frameSeconds: 1.0 / 60, scale: 0.28) }  // 슬로 0.28
        #expect(abs(total - 17) <= 1)
    }

    @Test func accumulatorCapsLongFrames() {
        var acc = FixedStepAccumulator()
        #expect(acc.ticks(frameSeconds: 2.0, scale: 2) == SimTime.maxTicksPerFrame)
    }
}
