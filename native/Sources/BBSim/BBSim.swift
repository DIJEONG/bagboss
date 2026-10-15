// BBSim — 게임 상태 + 규칙 + 모드. 결정적(고정 60Hz 틱 · 주입 난수). UIKit/Metal/AVFoundation import 금지.
// 바깥 계약: Core/SimAPI.swift (SimIntent → Sim.step → SimEvent · SimSnapshot) · Core/Sim.swift (한 판 소유)
// 가방 · 콤보 경로: Bag/ (웹 대조 완료) · 전투 · 진행: World/ (웹 함수 1:1 이식 — 락스텝 대조 완료, docs/06 §8 N3)
// 웹 원본: 13 일부(저글) · 16(시퀀스 진행) · 22~30(규칙) · 32 일부(콤보 실행) · 33 일부(가방 규칙) · 34 일부(매점) · 37 · 47 일부(필살)
// 다음: 39~44(프롤로그 · 보너스 · 스토리) · 24(타워) · 08/42(무도장)
public enum BBSim {}
