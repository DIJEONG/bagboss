import Foundation
@preconcurrency import AVFoundation
import BBCore
import BBContent

/// 게임 소리 창구(표현 층이 부른다). AVAudioEngine 그래프:
///
///     AVAudioSourceNode(SynthCore: {music · sfx · amb} 버스 → 컴프레서 → master) → mainMixer → 출력
///
/// 웹 그래프(master ← DynamicsCompressor ← {music, sfx, amb})와 같은 모양을 SynthCore 안에서 표본 단위로 만든다 —
/// 컴프레서까지 우리 DSP 라서 실기기 소리 = 오프라인 렌더(테스트) 소리다.
/// - 효과음: `play(_:)` → SfxBank 가 처방으로 펼쳐(메인) 합성기로 보낸다.
/// - 열차 루프: 매 프레임 `updateTrain(_:)`. 정차 hiss · 문 소리도 여기서 스스로 낸다.
/// - 음악: `setMusic(_:)` (긴장도 · 버스커 · 프롤로그). 대사: `blip(who:char:)`. 보너스 차 경보: `setAlarm(_:)`.
/// - 설정: `settings`(웹 'dotlab-snd' 와 같은 모양) — 바꾸면 0.05초에 걸쳐 반영.
@MainActor
public final class AudioEngine {
    public let synth: SynthCore
    public private(set) var isRunning = false
    public var settings: SoundSettings { didSet { synth.setMix(settings) } }

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var bank = SfxBank()
    private var train = TrainAmbience()
    private let blipVoice: BlipVoice?
    private var rng: SplitMix64
    private var observers: [NSObjectProtocol] = []
    /// 소리 중단(전화 · 알람 · 시리)이 시작되면 부른다 — 앱이 판을 멈춘다(끝나도 저절로 이어 하지 않는다)
    public var onInterruptionBegan: (() -> Void)?
    private var lastMusic = MusicInput.off

    /// - Parameters:
    ///   - content: 대사 목소리(VOX)를 읽을 추출 데이터. nil 이면 blip 없음
    ///   - seed: 연출용 난수 씨앗(음높이 흔들림 · 잡음)
    /// 출력 장치를 열지 않는다(개발용 실행 인자 -noaudio — 맥 오디오가 멈춘 시뮬레이터에서 화면만 점검). 켜면 start 가 아무것도 하지 않는다
    nonisolated(unsafe) public static var deviceOff = false

    public init(settings: SoundSettings = SoundSettings(), content: ContentStore? = nil, seed: UInt64 = 0xB4_6B05) {
        self.settings = settings
        rng = SplitMix64(seed: seed)
        blipVoice = content.flatMap { try? BlipVoice(content: $0) }
        let sr = Self.deviceOff ? 48_000 : engine.outputNode.outputFormat(forBus: 0).sampleRate
        synth = SynthCore(sampleRate: sr > 0 ? sr : 48_000, samples: SampleBank.shared)   // 녹음 타격음은 여기서 한 번 디코딩
        synth.setMix(settings, immediate: true)
    }

    /// 무거운 표(대역 제한 파형표 — 표본율마다 한 번)를 미리 만든다. 아무 스레드에서나(앱은 시작 때 뒤 스레드에서 부른다).
    /// 표본율이 실제 출력과 다르면 init 이 그 표본율로 다시 만든다(결과는 같고 시간만 든다).
    nonisolated public static func prewarm(sampleRate: Double) {
        _ = WaveTableSet.shared(sampleRate: sampleRate > 0 ? sampleRate : 48_000)
        _ = SampleBank.shared   // 녹음 타격음 디코딩도 뒤 스레드에서 미리(메인 init 멈칫 방지)
    }

    /// 출력 장치 준비(첫 AVAudioEngine.outputNode 는 오디오 입출력을 여느라 시뮬레이터에서 150ms 안팎 — 메인에서 init 할 때 멈칫)를
    /// 뒤 스레드에서 미리 하고 실제 출력 표본율을 돌려준다. 버리는 엔진이라 앱 엔진 · 오디오 세션 상태는 건드리지 않는다
    nonisolated public static func prewarmOutput() -> Double {
        if deviceOff { return 48_000 }
        let e = AVAudioEngine()
        return e.outputNode.outputFormat(forBus: 0).sampleRate
    }

    // MARK: 시작 · 정지 · 중단 처리

    /// 그래프를 잇고 엔진을 켠다(iOS: 오디오 세션 .ambient + 다른 앱 소리와 섞기 — 무음 스위치를 따른다)
    public func start() throws {
        if Self.deviceOff { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        #endif
        if source == nil {
            let synth = self.synth
            let fmt = AVAudioFormat(standardFormatWithSampleRate: synth.sampleRate, channels: 1)!
            let node = Self.makeSourceNode(synth: synth, format: fmt)
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: fmt)
            source = node
            observe()
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// 오디오 스레드 렌더 블록. @MainActor 클래스 안 클로저는 메인 액터 격리를 물려받아(Swift 6) 오디오 스레드에서
    /// 런타임 격리 검사(dispatch_assert_queue)에 걸려 죽는다 → nonisolated 정적 함수에서 만든다(N4 통합에서 발견).
    nonisolated private static func makeSourceNode(synth: SynthCore, format fmt: AVAudioFormat) -> AVAudioSourceNode {
        // 오디오 스레드: SynthCore.render 만 부른다(할당 · 차단 잠금 없음)
        AVAudioSourceNode(format: fmt) { @Sendable _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            guard let first = buffers.first, let p = first.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            synth.render(p, frames: Int(frameCount))
            for b in buffers.dropFirst() {   // 여러 채널이면 같은 모노를 복사
                if let q = b.mData?.assumingMemoryBound(to: Float.self) { q.update(from: p, count: Int(frameCount)) }
            }
            return noErr
        }
    }

    public func stop() {
        engine.pause()
        isRunning = false
    }

    /// 출력 장치가 바뀌면(이어폰 · 블루투스) AVAudioEngine 이 멈춘다 → 다시 켠다. iOS 는 전화 · 시리 중단도 처리.
    private func observe() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        })
        #if os(iOS)
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let opts = n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            MainActor.assumeIsolated {
                guard let self, let raw, let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began: self.isRunning = false; self.onInterruptionBegan?()
                case .ended:
                    if AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume) { self.restartIfNeeded() }
                @unknown default: break
                }
            }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        })
        #endif
    }

    /// 앱이 앞으로 돌아왔을 때 · 중단이 끝났을 때 부른다
    public func restartIfNeeded() {
        if Self.deviceOff { return }
        guard !engine.isRunning else { isRunning = true; return }
        do { try start() } catch { isRunning = false }
    }

    // MARK: 소리 내기

    /// 효과음 하나(웹 sfx.*). 타격음(hit3 · hitK)이면 settings.sampleHits 가 켜져 있고 조각이 있을 때 녹음 조각을 겹친다
    /// — context 는 때린 동작 · 카운터(없으면 이름표만으로 스타일을 고른다). 꺼져 있으면 웹 합성 그대로(context 무시).
    public func play(_ cue: SfxCue, context: HitContext? = nil) {
        let e = bank.expand(cue, context: context, sampleHits: settings.sampleHits && synth.samples != nil, now: synth.currentTime, rng: &rng)
        if !e.voices.isEmpty { synth.play(e.voices) }
        if let d = e.duck { duck(d) }
    }

    /// 배경음 잠깐 누르기(웹 sndDuck) — 음소거면 무시
    public func duck(_ d: Duck) {
        guard !settings.muted else { return }
        synth.duck(d)
    }

    /// 대사 글자 하나(웹 blip). 공백 · 문장 부호는 소리 없음
    public func blip(who: String, char: Character) {
        guard !settings.muted, BlipVoice.speaks(char), let v = blipVoice?.voice(who: who, char: char, rng: &rng) else { return }
        synth.play(v)
    }

    /// 열차 루프(매 프레임, 웹 sndUpdate)
    public func updateTrain(_ input: TrainSoundInput, rain: Bool = false) {
        var o = train.update(input, rng: &rng)
        if rain { o.targets.applyRain() }
        synth.setAmbience(o.targets)
        for c in o.cues { play(c) }
    }

    /// 열차 소리 끄기(지하철 밖 장면)
    public func silenceAmbience() { synth.setAmbience(.silent) }

    /// 배경음 입력(바뀔 때만 보낸다)
    public func setMusic(_ m: MusicInput) {
        guard m != lastMusic else { return }
        lastMusic = m
        synth.setMusic(m)
    }

    /// 보너스 차 경보
    public func setAlarm(_ on: Bool) { synth.setAlarm(on) }
}
