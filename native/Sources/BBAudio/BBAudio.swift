// BBAudio — 게임 소리 전부를 실시간 합성한다(웹판과 같다 · 네이티브 전용 녹음 타격음 조각만 예외 — Samples/ · docs/11 §10). 단계: N4
//
// 웹 원본: 35-audio(SND 그래프 · nz/tone · sfx.* · sndUpdate · musicTick · sndDuck · sndApplyVol) · 44-story(blip · VOX)
//          43-fx-smoke(차 경보 · 보너스 단독 소리) · 39-prologue(빗소리 · 문 끼이익) · 13/08/24(skTone · skNoise)
//
// 구성
//   DSP/      결정적 DSP 핵심 — ParamTimeline/Cursor(AudioParam 자동화 명세) · Biquad(명세 계수식) · WaveTableSet(Chromium 대역 제한 파형)
//             · Compressor(Chromium DynamicsCompressorKernel) · VoiceSpec(짧은 소리 처방, 고정 크기 값 타입)
//   Cues/     SfxCue(표현 층이 부르는 이름표) → SfxBank(웹 레시피 1:1) · BlipVoice(VOX)
//   Music/    JazzSequencer(D단조 ii-V-i · 92/110/124 BPM · 스윙 · 프롤로그 박동)
//   Synth/    SynthCore(버스 셋 → 컴프레서 → master, 오디오 스레드 무할당 · 무차단) · TrainAmbience(열차 루프 8종 판단 + 합성) · SoundSettings('dotlab-snd')
//   Engine/   AudioEngine(AVAudioEngine · AVAudioSourceNode · 세션 중단/경로 변경 처리) — 표현 층의 창구
//
// 웹 대조: tools/js/extract/sfx.mjs → Tests/Fixtures/audio/sfx.json, `swift test --filter BBAudioTests`
public enum BBAudio {
    /// 웹 기준 렌더 표본율(sndRender 기본값) — 대조 테스트용
    public static let referenceSampleRate = 22050.0
}
