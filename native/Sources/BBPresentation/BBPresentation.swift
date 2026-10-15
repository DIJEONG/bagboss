// BBPresentation — 시뮬레이션 이벤트 → '보이는 상태'(카메라 · 흔들림 · 슬로 보간 · 피해 숫자 · HITFX · 코믹 · 컷인 · 파티클 · 장면 광원/FX 구성)
// 연출용 난수(rngFx)는 여기서만 쓴다. 렌더러 · 오디오 · 진동은 이 계층의 출력만 본다.
// 웹 원본: 45-hud · 46-cutin · 47-special-ui(그리기) · 43-fx-smoke · 각 장면의 *Lights/*FX 함수
// 단계: N4
// 지금 있는 것: Scene/ — 장면 구성(지하철 · 고가선 · 다리 · 타워의 배경 쿼드 · 광원 · 후처리 fx · 렌더 광원 합성). 웹 대조는 Tests/BBPresentationTests/SceneParityTests
public enum BBPresentation {}
