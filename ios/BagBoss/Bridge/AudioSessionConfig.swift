import AVFoundation

/// 게임 소리는 전부 WebAudio 실시간 합성(음원 파일 없음).
/// .ambient + mixWithOthers: 무음 스위치를 따르고, 사용자가 듣던 음악을 끊지 않는다.
/// (무음 스위치를 무시하고 항상 소리를 내려면 .playback — 1단계 측정 뒤 결정. docs/04 체크리스트)
enum AudioSessionConfig {
    static func apply() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            NSLog("[BagBoss] 오디오 세션 설정 실패: %@", error.localizedDescription)
        }
    }
}
