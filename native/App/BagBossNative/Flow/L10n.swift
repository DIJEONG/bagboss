import Foundation
import BBContent

// 화면 문구 번역(웹 00-i18n.js 의 tr · KE) — 본체는 BBContent `Loc`(정확한 문장 → 자리표시 문장 → 용어 치환, 웹 tr 1:1).
// 원문(한국어)이 키다. 영어는 BBContent 생성물 Localizable.xcstrings(tools/js/extract/strings.mjs — 웹 사전 + strings-extra.json).
// 언어는 'dotlab-lang'(날 문자열 ko · en). 웹은 언어를 바꾸면 페이지를 다시 읽지만, 네이티브는 GameSession.lang 이 바뀌면 화면이 다시 그려진다.
// HUD 캔버스 글자(OverlayPainter) · 가방(BBUI)도 같은 Loc 을 그리는 자리에서 쓴다 → Loc.lang 하나만 바꾸면 전부 따라온다.

enum L10n {
    /// 지금 언어(GameSession 이 저장값과 함께 바꾼다)
    static var lang: String {
        get { Loc.lang }
        set { Loc.lang = newValue }
    }

    /// 원문 → 영어 사전({0} 형식 — 시험 · 점검용)
    static func load() -> [String: String] { Loc.translator.dict }

    /// 웹 tr(s): 영어면 사전 · 자리표시 문장 · 용어 치환, 아니면 원문
    static func tr(_ ko: String) -> String { Loc.tr(ko) }
    /// 웹 KE(ko, en): 영어 문장을 바로 쓰는 자리
    static func ke(_ ko: String, _ en: String) -> String { Loc.ke(ko, en) }
    static var isEN: Bool { Loc.isEN }
}

/// 짧게 쓰기
func tr(_ ko: String) -> String { L10n.tr(ko) }
func KE(_ ko: String, _ en: String) -> String { L10n.ke(ko, en) }
