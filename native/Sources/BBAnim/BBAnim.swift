// BBAnim — 인물 애니메이션(렌더 무관): 포즈 보간 · 보행 · 전환 블렌드 → 관절 풀이(IK/FK) → 뼈 → 3D 메시 · 얼굴 (docs/06 §2.4)
// 웹 원본: 16-anim(lerpPose · curPose) · 17-light-frame(IK · 보행 · blendPose · drawChar0) · 12-webgl(charBones · boneT · pushModel · pushFace)
// 단계별 대조: Tests/BBAnimTests ↔ Tests/Fixtures/characters.json.deflate(tools/js/extract/characters.mjs)
// 강화(웹에 없는 섬세한 동작)는 Enhance/ 아래에 따로 두고 기본으로 끈다 — 켜도 판정 타이밍은 바뀌지 않는다.
public enum BBAnim {}
