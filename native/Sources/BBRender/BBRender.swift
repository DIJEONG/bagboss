// BBRender — Metal 렌더러: GBuffer → Composite(느와르 프리셋 6) → Bloom → Post → Blit (docs/06 §2.5)
// 입력은 RenderFrame 하나(게임 상태를 읽지 않는다). 셰이더 원문 대응: Resources/Shaders.metal ↔ web/src/12-webgl.js · 19-lab-nodes.js
// 대조: Tests/BBRenderTests 가 웹 캡처(Tests/Fixtures/frames)와 단계별 픽셀을 비교한다.
public enum BBRender {}
