import Foundation
import Testing
import BBCore
import BBContent
@testable import BBAudio

/// 합성기 · 설정 · 열차 루프 판단 · 재즈 시퀀서 · blip · 이름표 펼치기
@Suite struct AudioLogicTests {
    static func synth(_ sr: Double = 22050, compressor: Bool = false) -> SynthCore {
        var o = SynthCore.Options(); o.compressor = compressor
        let s = SynthCore(sampleRate: sr, options: o)
        s.setMix(SoundSettings(vol: .init(master: 1)), immediate: true)
        return s
    }
    static func rms(_ x: ArraySlice<Float>) -> Double { (x.reduce(0) { $0 + Double($1 * $1) } / Double(max(1, x.count))).squareRoot() }

    // MARK: 설정

    @Test func soundSettingsMatchWebStorageShape() throws {
        let web = #"{"vol":{"master":0.5,"music":0.2},"muted":true,"extra":1}"#
        let s = try JSONDecoder().decode(SoundSettings.self, from: Data(web.utf8))
        #expect(s.vol.master == 0.5 && s.vol.music == 0.2 && s.vol.sfx == 0.8 && s.muted)     // 빠진 키는 웹 기본값
        let back = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SoundSettings())) as! [String: Any]
        #expect(Set(back.keys) == ["vol", "muted"])
        #expect(Set((back["vol"] as! [String: Any]).keys) == ["master", "music", "sfx"])
        let g = SoundSettings().busGains
        #expect(abs(g.music - 0.275) < 1e-12 && g.sfx == 0.8 && abs(g.amb - 0.56) < 1e-12 && g.master == 0.8)
        #expect(SoundSettings(muted: true).busGains.master == 0)
    }

    @Test func mutedSilencesOutputAndIgnoresDuck() {
        let s = Self.synth()
        s.setMix(SoundSettings(muted: true), immediate: true)
        s.play(SfxBank.tone(0.2, f: 440, g: 0.5))
        let x = s.renderOffline(frames: 4410)
        #expect(x.allSatisfy { $0 == 0 })
    }

    // MARK: 합성기

    @Test func renderIsDeterministicForSameSeed() {
        func once() -> [Float] {
            let s = Self.synth(); var r = SplitMix64(seed: 7); var b = SfxBank()
            s.play(b.expand(.glass, rng: &r).voices); s.play(b.expand(.hit3(tier: 2, crit: true), rng: &r).voices)
            return s.renderOffline(frames: 22050)
        }
        #expect(once() == once())
    }

    @Test func voicePoolStealsOldestWhenFull() {
        var o = SynthCore.Options(); o.voiceCapacity = 4; o.compressor = false
        let s = SynthCore(sampleRate: 22050, options: o)
        for _ in 0..<10 { s.play(SfxBank.tone(1, f: 440, g: 0.01)) }
        _ = s.renderOffline(frames: 64)
        #expect(s.activeVoices == 4)
    }

    @Test func voicesEndAndFreeTheirSlots() {
        let s = Self.synth()
        s.play(SfxBank.tone(0.05, f: 440))
        _ = s.renderOffline(frames: 512)
        #expect(s.activeVoices == 1)
        _ = s.renderOffline(frames: 4096)
        #expect(s.activeVoices == 0)
    }

    @Test func commandRingDropsWhenFull() {
        var o = SynthCore.Options(); o.commandCapacity = 8
        let s = SynthCore(sampleRate: 22050, options: o)
        s.play(Array(repeating: SfxBank.tone(0.1), count: 20))
        #expect(s.dropped == 13)
    }

    @Test func stopAllSilences() {
        let s = Self.synth()
        s.play(SfxBank.tone(2, f: 440, g: 0.5))
        _ = s.renderOffline(frames: 2205)
        s.stopAll()
        let x = s.renderOffline(frames: 2205)
        #expect(x.allSatisfy { $0 == 0 })
    }

    @Test func realtimeFactor() {
        // 무거운 장면: 열차 루프 전부 + 두목 재즈 + 버스커 + 경보 + 효과음 40개를 48kHz 로 2초
        let s = Self.synth(48000, compressor: true)
        var a = AmbienceTargets(); a.rumGain = .init(0.3, 0.01); a.motGain = .init(0.05, 0.01); a.windGain = .init(0.1, 0.01)
        a.fricGain = .init(0.1, 0.01); a.grindGain = .init(0.1, 0.01); a.squealGain = .init(0.03, 0.01); a.crowdGain = .init(0.07, 0.01); a.humGain = .init(0.02, 0.01)
        s.setAmbience(a); s.setMusic(MusicInput(intensity: 3, buskOn: true)); s.setAlarm(true)
        var r = SplitMix64(seed: 1); var b = SfxBank()
        for k in 0..<40 { s.play(b.expand(.hit3(tier: k % 3, crit: k % 2 == 0), rng: &r).voices) }
        let t0 = Date()
        let x = s.renderOffline(frames: 96000)
        let dt = Date().timeIntervalSince(t0)
        print(String(format: "[성능] 무거운 장면 2초 렌더 %.0f ms (실시간 대비 %.1f배, 디버그 빌드)", dt * 1000, 2 / dt))
        #expect(x.allSatisfy { $0.isFinite })
        #expect(Self.rms(x[48000...]) > 0.01)
    }

    // MARK: 열차 루프

    @Test func trainAmbienceEmitsHissChimeAndDoorCues() {
        var amb = TrainAmbience(); var r = SplitMix64(seed: 3)
        var s = TrainSoundInput(); s.speed = 120; s.phase = .brake; s.brakeGlow = 0.8; s.doorWant = false; s.time = 0
        var o = amb.update(s, rng: &r)
        #expect(o.cues.isEmpty)
        #expect(o.targets.fricGain.value > 0 && o.targets.grindGain.value > 0)
        #expect(o.targets.squealGain.value > 0)                                     // 260 미만 제동 → 쇳소리
        s.phase = .stop; s.speed = 0; s.time = 1
        o = amb.update(s, rng: &r)
        #expect(o.cues == [.hiss])                                                  // 제동 → 정차: 에어 브레이크
        #expect(o.targets.squealGain.value == 0)
        s.doorWant = true; s.time = 2
        _ = amb.update(s, rng: &r)
        s.door = 0.3; s.time = 2.1
        o = amb.update(s, rng: &r)
        #expect(o.cues == [.door(open: true)])                                      // 열리기 시작
        s.door = 1; s.time = 2.2; _ = amb.update(s, rng: &r)
        s.time = 3; s.door = 1; _ = amb.update(s, rng: &r)
        #expect(amb.update(s, rng: &r).targets.crowdGain.value == 0)                // atStop 아님
        s.atStop = true
        #expect(amb.update(s, rng: &r).targets.crowdGain.value == 0.07)             // 역 · 문 열림 → 웅성임
        s.doorWant = false; s.time = 9
        o = amb.update(s, rng: &r)
        #expect(o.cues == [.chime])                                                 // 닫힘 요청: 딩-동
        s.door = 0.8; s.time = 9.5
        o = amb.update(s, rng: &r)
        #expect(o.cues == [.door(open: false)])                                     // 요청 1.5초 안 닫힘 시작
    }

    @Test func ambienceLoopsRenderOnBuses() {
        let s = Self.synth()
        var a = AmbienceTargets(); a.rumGain = .init(0.5, 0.01); a.rumFreq = .init(200, 0.01)
        s.setAmbience(a)
        let x = s.renderOffline(frames: 22050)
        #expect(Self.rms(x[11025...]) > 0.005)
        s.setAmbience(.silent)
        let y = s.renderOffline(frames: 66150)
        #expect(Self.rms(y[44100...]) < 1e-4)
    }

    @Test func carAlarmAlternatesPitch() {
        let s = Self.synth()
        s.setAlarm(true)
        let x = s.renderOffline(frames: 22050)
        // 0.25초마다 880 ↔ 1180: 앞 0.25초(1180)와 다음 0.25초(880)의 영교차 수가 다르다
        func zc(_ a: Int, _ b: Int) -> Int { (a..<b).filter { (x[$0] >= 0) != (x[$0 + 1] >= 0) }.count }
        let hi = zc(2205, 5000), lo = zc(5513 + 1000, 5513 + 3795)
        #expect(hi > lo)
        #expect(Self.rms(x[2205...]) > 0.005)
    }

    // MARK: 재즈

    @Test func jazzBpmFollowsIntensity() {
        var j = JazzSequencer(); var seed = NoiseSeed(1)
        j.input = MusicInput(intensity: 1)
        var steps = 0, t = 0.0
        while t < 60 { j.advance(now: t, until: t + 0.02, seed: &seed) { _, _ in }; t += 0.02 }
        steps = j.step
        #expect(j.bpm == 92)
        #expect(abs(Double(steps) - 60 * 92 / 60 * 2) < 3)                       // 8분음표 = 분당 184
        j.input.intensity = 3
        t = 60
        while t < 120 { j.advance(now: t, until: t + 0.02, seed: &seed) { _, _ in }; t += 0.02 }
        #expect(j.bpm == 124)
        #expect(JazzSequencer.level(foes: 0, boss: false, danger: false) == 1)
        #expect(JazzSequencer.level(foes: 2, boss: false, danger: true) == 2.5)
        #expect(JazzSequencer.level(foes: 1, boss: true, danger: false) == 3)
    }

    @Test func jazzLayersAndBusker() {
        func voices(_ m: MusicInput, warm: Double = 30) -> Int {
            var j = JazzSequencer(); var seed = NoiseSeed(1); j.input = m
            var t = 0.0
            while t < warm { j.advance(now: t, until: t + 0.02, seed: &seed) { _, _ in }; t += 0.02 }
            var n = 0
            j.advance(now: t, until: t + 4, seed: &seed) { v, _ in n += 1; #expect(v.bus == .music) }
            return n
        }
        let calm = voices(MusicInput(intensity: 1)), boss = voices(MusicInput(intensity: 3)), busk = voices(MusicInput(intensity: 1, buskOn: true))
        #expect(boss > calm * 2)
        #expect(busk > calm)
        #expect(voices(MusicInput(enabled: false)) == 0)
        #expect(voices(MusicInput(prologue: true)) > 0)
    }

    @Test func musicRendersThroughSynth() {
        let s = Self.synth()
        s.setMusic(MusicInput(intensity: 2))
        let x = s.renderOffline(frames: 22050 * 2)
        #expect(Self.rms(x[...]) > 0.003)
    }

    // MARK: blip · 이름표

    @Test func blipVoiceFromContent() throws {
        let b = try BlipVoice(content: ContentStore.bundled())
        #expect(Set(b.presets.keys) == ["cond", "saboo", "minnie", "me"])
        #expect(b.vowel.count == 21)
        var r = SplitMix64(seed: 1)
        let v = try #require(b.voice(who: "saboo", char: "하", rng: &r))
        #expect(v.source == .osc(.square))
        #expect(abs(v.stop - (0.036 * 0.85 + 0.02)) < 1e-12)
        #expect(BlipVoice.speaks("가") && !BlipVoice.speaks(" ") && !BlipVoice.speaks("…") && !BlipVoice.speaks("!"))
        // 모르는 인물 → cond
        #expect(b.voice(who: "nobody", char: "a", rng: &r)?.source == .osc(.triangle))
    }

    @Test func floorIsRateLimited() {
        var b = SfxBank(); var r = SplitMix64(seed: 1)
        #expect(!b.expand(.floor(1), now: 1.0, rng: &r).voices.isEmpty)
        #expect(b.expand(.floor(1), now: 1.05, rng: &r).voices.isEmpty)
        #expect(!b.expand(.floor(1), now: 1.08, rng: &r).voices.isEmpty)
    }

    @Test func duckingCuesAndBigHits() {
        var b = SfxBank(); var r = SplitMix64(seed: 1)
        #expect(b.expand(.hit3(tier: 2, big: true), rng: &r).duck == Duck(k: 0.32, hold: 0.14, rel: 0.36))
        #expect(b.expand(.hurt(heavy: true), rng: &r).duck == Duck(k: 0.45, hold: 0.1, rel: 0.3))
        #expect(b.expand(.hit3(tier: 2), rng: &r).duck == nil)
    }

    /// 모든 이름표가 소리를 낸다(빈 처방 · NaN 없음)
    @Test func everyCueProducesSound() {
        let cues: [SfxCue] = [.clack(speed: 300), .hit(heavy: false, crit: true), .hitK(.hammer, crit: true, combo: 3), .hit3(tier: 1, crit: true, combo: 2, air: true),
            .just, .floor(1.2), .thud, .swing, .hurt(heavy: false), .glass, .boom, .whoosh, .dodge, .press, .chime, .door(open: true), .click, .coin,
            .merge(ok: false), .clear, .slowIn, .carHit(heavy: true), .gong, .ready, .brass, .rage, .hiss, .pass, .zap, .unlock,
            .doorCreak, .footSplash, .tallyTick, .tireBurst, .fireCrackle, .debrisClank, .countdownBeep(final: false),
            .skTone(f0: 760, f1: 760, dur: 0.16, wave: .square, vol: 0.022, delay: 0.1), .skNoise(dur: 0.3, f: 1600, g: 0.08),
            .tone(dur: 0.1, f: 300), .noise(dur: 0.1)]
        for c in cues {
            let s = Self.synth(); var r = SplitMix64(seed: 1); var b = SfxBank()
            let e = b.expand(c, rng: &r)
            #expect(!e.voices.isEmpty, "\(c)")
            s.play(e.voices)
            let x = s.renderOffline(frames: 22050)
            #expect(x.allSatisfy { $0.isFinite } && Self.rms(x[...]) > 1e-4, "\(c)")
        }
    }

    @MainActor @Test func engineFacadeQueuesWithoutStarting() throws {
        let e = AudioEngine(content: try ContentStore.bundled())
        e.play(.coin)
        e.blip(who: "cond", char: "가")
        e.updateTrain(TrainSoundInput())
        e.setMusic(MusicInput(intensity: 2))
        e.settings.vol.music = 0.3
        #expect(!e.isRunning)
        #expect(e.synth.dropped == 0)
    }
}
