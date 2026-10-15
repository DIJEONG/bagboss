import Foundation
import os

/// 실시간 합성기 — 웹 SND 그래프 전체(버스 셋 → 컴프레서 → master)를 표본 단위로 그린다.
/// 같은 코드가 AVAudioSourceNode(실시간)와 오프라인 렌더(테스트)에 쓰인다.
///
/// 스레드 규칙
/// - 메인(게임) 스레드: `play` · `setMix` · `duck` · `setAmbience` · `setMusic` · `setAlarm` → 명령 고리에 넣는다(짧게 잠근다).
/// - 오디오 스레드: `render` 만. 할당 · 차단 잠금이 없다 — 명령 고리는 `os_unfair_lock_trylock` 으로만 열고,
///   못 열면 그 블록은 건너뛰고 다음 블록에 받는다. 소리 풀 · 버스 버퍼 · 명령 고리는 init 에서 한 번 할당한다.
public final class SynthCore: @unchecked Sendable {
    public struct Options: Sendable {
        /// 컴프레서(웹 DynamicsCompressor −14 dB · 4:1)를 거치는가 — 끄면 버스 합 그대로(dry 대조용)
        public var compressor = true
        /// 컴프레서 검출기를 '쉬는 상태'에서 시작(웹 Chromium 의 시동 감쇠 없음)
        public var warmCompressor = true
        /// Chromium 버릇 흉내(표본 대조 테스트 전용): 렌더 양자(128표본) 중간에 시작한 발진기는 그 양자 동안
        /// 주파수 자동화 값을 (시작 − 양자 시작)표본만큼 늦게 읽는다 → 시작 직후 몇 ms 가 기본값 440Hz 로 울린다.
        /// 귀로는 들리지 않는 차이라 실제 엔진에서는 끈다.
        public var chromeQuantumQuirk = false
        public var voiceCapacity = 192
        public var commandCapacity = 1024
        public init() {}
    }

    enum Command {
        case voice(VoiceSpec)
        case mix(SoundSettings, immediate: Bool)
        case duck(Duck)
        case ambience(AmbienceTargets)
        case music(MusicInput)
        case alarm(Bool)
        case stopAll
    }

    public let sampleRate: Double
    private let opt: Options

    // 명령 고리(SPSC)
    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private let ring: UnsafeMutablePointer<Command?>
    private let ringCap: Int
    private var head = 0, tail = 0          // head: 쓰기(메인) · tail: 읽기(오디오) — 둘 다 lock 안에서만
    private var publishedFrame: Int64 = 0   // 오디오 시계(lock 안에서 갱신)
    private var droppedCommands = 0

    // 오디오 스레드 상태
    private let voices: UnsafeMutablePointer<VoiceState?>
    private let voiceCap: Int
    private let maxBlock = 1024
    private let busMusic: UnsafeMutablePointer<Float>, busSfx: UnsafeMutablePointer<Float>, busAmb: UnsafeMutablePointer<Float>
    private var frame: Int64 = 0
    private var gMusic = TargetParam(0.275), gSfx = TargetParam(0.8), gAmb = TargetParam(0.56), gMaster = TargetParam(0.8)
    private var muted = false
    private var duckMusic: ParamCursor?, duckAmb: ParamCursor?
    private var duckMusicV = 1.0, duckAmbV = 1.0
    private let comp: Compressor
    private let tables: WaveTableSet
    private var ambience: AmbienceLoops
    private var alarm: AlarmLoop
    private var jazz = JazzSequencer()
    private var seeds = NoiseSeed(0x5EED_A0D1)
    /// 녹음 타격음 조각(없으면 .sample 소리는 바로 끝난다) — 버퍼는 이 묶음이 살아 있는 동안 유효
    public let samples: SampleBank?
    /// 지금 울리는 소리 수(진단용 · 오디오 스레드 값)
    public private(set) var activeVoices = 0

    public init(sampleRate: Double, options: Options = Options(), samples: SampleBank? = nil) {
        self.sampleRate = sampleRate; opt = options; self.samples = samples
        lock = .allocate(capacity: 1); lock.initialize(to: os_unfair_lock())
        ringCap = options.commandCapacity
        ring = .allocate(capacity: ringCap); ring.initialize(repeating: nil, count: ringCap)
        voiceCap = options.voiceCapacity
        voices = .allocate(capacity: voiceCap); voices.initialize(repeating: nil, count: voiceCap)
        busMusic = .allocate(capacity: maxBlock); busSfx = .allocate(capacity: maxBlock); busAmb = .allocate(capacity: maxBlock)
        comp = Compressor(sampleRate: sampleRate, warm: options.warmCompressor)
        tables = WaveTableSet.shared(sampleRate: sampleRate)
        ambience = AmbienceLoops(sampleRate: sampleRate, tables: tables)
        alarm = AlarmLoop(sampleRate: sampleRate, tables: tables)
        // 정적 표를 메인에서 미리 깨운다(오디오 스레드에서 처음 열면 swift_once 잠금)
        _ = JazzSequencer.chords.count + JazzSequencer.bassWalk.count
    }

    deinit {
        lock.deinitialize(count: 1); lock.deallocate()
        ring.deinitialize(count: ringCap); ring.deallocate()
        voices.deinitialize(count: voiceCap); voices.deallocate()
        busMusic.deallocate(); busSfx.deallocate(); busAmb.deallocate()
    }

    // MARK: 메인 스레드

    private func push(_ cmds: some Sequence<Command>) {
        os_unfair_lock_lock(lock); defer { os_unfair_lock_unlock(lock) }
        for c in cmds {
            let next = (head + 1) % ringCap
            if next == tail { droppedCommands += 1; continue }    // 가득 참: 버린다
            ring[head] = c; head = next
        }
    }

    /// 소리 처방 여럿을 '지금' 울린다(각자 delay 뒤)
    public func play(_ specs: [VoiceSpec]) { push(specs.lazy.map { .voice($0) }) }
    public func play(_ spec: VoiceSpec) { push(CollectionOfOne(.voice(spec))) }
    /// 볼륨 · 음소거(웹 sndApplyVol — 0.05초 시간 상수). immediate 면 바로(오프라인 렌더 시작값)
    public func setMix(_ s: SoundSettings, immediate: Bool = false) { push(CollectionOfOne(.mix(s, immediate: immediate))) }
    public func duck(_ d: Duck) { push(CollectionOfOne(.duck(d))) }
    public func setAmbience(_ a: AmbienceTargets) { push(CollectionOfOne(.ambience(a))) }
    public func setMusic(_ m: MusicInput) { push(CollectionOfOne(.music(m))) }
    public func setAlarm(_ on: Bool) { push(CollectionOfOne(.alarm(on))) }
    public func stopAll() { push(CollectionOfOne(.stopAll)) }

    /// 합성기 시계(초) — 마지막으로 오디오 스레드가 명령을 받은 블록 기준
    public var currentTime: Double {
        os_unfair_lock_lock(lock); defer { os_unfair_lock_unlock(lock) }
        return Double(publishedFrame) / sampleRate
    }
    /// 고리가 가득 차 버린 명령 수(진단용)
    public var dropped: Int {
        os_unfair_lock_lock(lock); defer { os_unfair_lock_unlock(lock) }
        return droppedCommands
    }

    // MARK: 오디오 스레드

    private func drain() {
        guard os_unfair_lock_trylock(lock) else { return }
        defer { os_unfair_lock_unlock(lock) }
        publishedFrame = frame
        while tail != head {
            if let c = ring[tail] { apply(c) }
            ring[tail] = nil
            tail = (tail + 1) % ringCap
        }
    }

    private func apply(_ c: Command) {
        switch c {
        case .voice(let v):
            // 웹과 같은 반올림: 시작 표본 = ceil(시각·sr). 넘친 조각(frac)은 소리 안에서 흉내 낸다
            let x = v.delay * sampleRate, s0 = x.rounded(.up)
            spawn(v, startFrame: frame + Int64(s0), frac: s0 - x)
        case .mix(let s, let immediate):
            let g = s.busGains
            muted = s.muted
            func put(_ p: inout TargetParam, _ x: Double) {
                if immediate { p = TargetParam(x) } else { p.setTarget(x, tc: 0.05, sampleRate: sampleRate) }
            }
            put(&gMusic, g.music); put(&gSfx, g.sfx); put(&gAmb, g.amb); put(&gMaster, g.master)
        case .duck(let d):
            if muted { return }
            duckMusic = Self.duckCursor(from: duckMusicV, d, sampleRate)
            duckAmb = Self.duckCursor(from: duckAmbV, d, sampleRate)
        case .ambience(let a):
            ambience.apply(a)
        case .music(let m):
            jazz.input = m
        case .alarm(let on):
            alarm.on = on
        case .stopAll:
            for i in 0..<voiceCap { voices[i] = nil }
            ambience.apply(.silent); alarm.on = false; jazz.input = .off
        }
    }

    /// 웹 sndDuck: 지금 값 → 12ms 선형으로 k → hold 유지 → rel 선형으로 1
    private static func duckCursor(from v: Double, _ d: Duck, _ sr: Double) -> ParamCursor {
        var tl = ParamTimeline(v)
        tl.set(v, at: 0); tl.linear(to: d.k, at: 0.012); tl.set(d.k, at: 0.012 + d.hold); tl.linear(to: 1, at: 0.012 + d.hold + d.rel)
        return ParamCursor(tl, sampleRate: sr)
    }

    private func spawn(_ v: VoiceSpec, startFrame: Int64, frac: Double = 0) {
        var slot = -1, oldest = Int64.max
        for i in 0..<voiceCap {
            guard let s = voices[i] else { slot = i; break }
            if s.startFrame < oldest { oldest = s.startFrame; slot = i }    // 꽉 차면 가장 오래된 소리를 밀어낸다
        }
        voices[slot] = VoiceState(v, startFrame: startFrame, sampleRate: sampleRate, tables: tables, quantumQuirk: opt.chromeQuantumQuirk, frac: frac, samples: samples)
    }

    /// 모노 출력 n 표본을 쓴다(덮어쓴다).
    public func render(_ out: UnsafeMutablePointer<Float>, frames n: Int) {
        var done = 0
        while done < n {
            let m = min(maxBlock, n - done)
            renderBlock(out + done, m)
            done += m
        }
    }

    private func renderBlock(_ out: UnsafeMutablePointer<Float>, _ n: Int) {
        drain()
        busMusic.update(repeating: 0, count: n); busSfx.update(repeating: 0, count: n); busAmb.update(repeating: 0, count: n)
        let sr = sampleRate, t0 = Double(frame) / sr
        // 재즈 시퀀서: 이 블록 안에서 시작하는 스텝의 소리를 정확한 표본에 놓는다
        jazz.advance(now: t0, until: t0 + Double(n) / sr, seed: &seeds) { spec, time in
            let x = time * sr, s0 = x.rounded(.up)
            spawn(spec, startFrame: Int64(s0), frac: s0 - x)
        }
        // 짧은 소리들
        var live = 0
        for i in 0..<voiceCap {
            guard var v = voices[i] else { continue }
            let bus: UnsafeMutablePointer<Float> = v.spec.bus == .music ? busMusic : v.spec.bus == .sfx ? busSfx : busAmb
            if v.render(into: bus, frames: n, blockStart: frame) { voices[i] = v; live += 1 } else { voices[i] = nil }
        }
        activeVoices = live
        // 계속 도는 소리
        ambience.render(amb: busAmb, sfx: busSfx, frames: n)
        alarm.render(sfx: busSfx, frames: n, startTime: t0)
        // 버스 이득 · 덕킹 → 컴프레서 → master
        for i in 0..<n {
            gMusic.step(); gSfx.step(); gAmb.step(); gMaster.step()
            if duckMusic != nil { duckMusicV = duckMusic!.next(); if duckMusic!.isSettled { duckMusic = nil; duckMusicV = 1 } }
            if duckAmb != nil { duckAmbV = duckAmb!.next(); if duckAmb!.isSettled { duckAmb = nil; duckAmbV = 1 } }
            var x = busMusic[i] * Float(gMusic.value * duckMusicV) + busSfx[i] * Float(gSfx.value) + busAmb[i] * Float(gAmb.value * duckAmbV)
            if opt.compressor { x = comp.process(x) }
            out[i] = x * Float(gMaster.value)
        }
        frame += Int64(n)
    }

    // MARK: 오프라인(테스트 · 굽기)

    /// n 표본을 새 배열로 그린다(할당 — 오디오 스레드에서 쓰지 않는다)
    public func renderOffline(frames n: Int) -> [Float] {
        var out = [Float](repeating: 0, count: n)
        out.withUnsafeMutableBufferPointer { render($0.baseAddress!, frames: n) }
        return out
    }
}
