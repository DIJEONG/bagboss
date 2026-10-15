import Foundation

// 화면 문구 번역 — 웹 00-i18n.js tr() 1:1 이식(정확한 문장 → 자리표시 문장 → 용어 치환) + KE(ko, en).
// 원문(한국어)이 키다. 영어는 생성물 Generated/Localizable.xcstrings(웹 EN_DICT + KE + 웹 en 삼항 + 콘텐츠 en 필드 + strings-extra.json).
// 패키지 리소스가 .copy 라 String(localized:) 경로를 타지 않으므로 카탈로그 JSON 을 직접 읽는다.
//
// 웹은 그리는 순간(캔버스 fillText · DOM 글자 노드) 옮긴다. 네이티브도 같은 자리에서 옮긴다:
//  · HUD 캔버스 글자 = BBPresentation OverlayPainter.fillText · strokeText · measureText (한 곳)
//  · 가방 UIKit 글자 = BBUI BagGridView · BagTileNode 의 글자 대입 자리
//  · SwiftUI 흐름 화면 = 앱 L10n.tr(→ Loc.tr)
// 규칙(BBSim)은 한국어 원문만 낸다 — 언어를 모른다.
// 같은 알고리즘의 JS 판: tools/js/extract/l10n-core.mjs(범위 점검 l10n-audit.mjs 가 쓴다). 고치면 둘 다 고친다.

public enum Loc {
    /// 지금 언어('dotlab-lang' 값 그대로: "ko" · "en"). 앱이 설정과 함께 바꾼다
    public static var lang: String {
        get { store.lang }
        set { store.setLang(newValue) }
    }
    public static var isEN: Bool { lang == "en" }

    /// 웹 tr(s): 영어면 사전 → 자리표시 문장 → 용어 치환, 한국어면 그대로
    public static func tr(_ s: String) -> String { store.tr(s) }
    /// 웹 KE(ko, en)
    public static func ke(_ ko: String, _ en: String) -> String { isEN ? en : ko }

    /// 카탈로그 번역기(언어와 무관 — 시험 · 점검용)
    public static var translator: LocTranslator { store.translator }

    private static let store = LocStore()
}

final class LocStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _lang = "ko"
    private var _translator: LocTranslator?
    private var cache: [String: String] = [:]

    var lang: String { lock.lock(); defer { lock.unlock() }; return _lang }
    func setLang(_ l: String) { lock.lock(); if l != _lang { _lang = l; cache.removeAll() }; lock.unlock() }

    var translator: LocTranslator {
        lock.lock(); defer { lock.unlock() }
        if let t = _translator { return t }
        let t = LocTranslator(dict: (try? LocTranslator.loadCatalog(GeneratedResources.url.appending(path: "Localizable.xcstrings"))) ?? [:])
        _translator = t
        return t
    }

    func tr(_ s: String) -> String {
        lock.lock()
        if _lang != "en" || !LocTranslator.hasHangul(s) { lock.unlock(); return s }
        if let hit = cache[s] { lock.unlock(); return hit }
        lock.unlock()
        let out = translator.translate(s)
        lock.lock(); if cache.count < 6000 { cache[s] = out }; lock.unlock()
        return out
    }
}

/// 카탈로그 사전({0} 형식 키 → 영어)으로 웹 tr 을 흉내 내는 번역기. 상태 없음(스레드 안전)
public final class LocTranslator: @unchecked Sendable {
    public enum Kind: String, Sendable { case none, exact, template, gloss }

    public let dict: [String: String]
    private struct Template { let re: NSRegularExpression; let en: String; let order: [Int]; let lit: Int; let key: String }
    private let templates: [Template]
    private let gloss: [(String, String)]
    private static let plural = try! NSRegularExpression(pattern: #"\b1 (cell|hit|token|run|node|item|line|trigger|time|second|enemie)s\b"#)
    private static let hole = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)

    public init(dict: [String: String]) {
        self.dict = dict
        var T: [Template] = [], G: [(String, String)] = []
        for (k, v) in dict {
            if k.range(of: #"\{\d+\}"#, options: .regularExpression) != nil {
                var re = "^", order: [Int] = [], lit = 0
                var rest = Substring(k)
                while let r = rest.range(of: #"\{\d+\}"#, options: .regularExpression) {
                    let litPart = String(rest[rest.startIndex..<r.lowerBound])
                    re += NSRegularExpression.escapedPattern(for: litPart); lit += litPart.utf16.count
                    re += #"([\s\S]*?)"#; order.append(Int(rest[r].dropFirst().dropLast())!)
                    rest = rest[r.upperBound...]
                }
                re += NSRegularExpression.escapedPattern(for: String(rest)); lit += String(rest).utf16.count
                if let rx = try? NSRegularExpression(pattern: re + #"\z"#) { T.append(Template(re: rx, en: v, order: order, lit: lit, key: k)) }
            } else if k.count >= 2 {
                G.append((k, v))
            }
        }
        // 웹: 리터럴 글자 수 내림차순(같으면 키 순 — 결정적, l10n-core.mjs 와 같게). JS length = UTF-16 길이
        templates = T.sorted { $0.lit != $1.lit ? $0.lit > $1.lit : $0.key.utf16.lexicographicallyPrecedes($1.key.utf16) }
        gloss = G.sorted { $0.0.utf16.count != $1.0.utf16.count ? $0.0.utf16.count > $1.0.utf16.count : $0.0.utf16.lexicographicallyPrecedes($1.0.utf16) }
    }

    public static func hasHangul(_ s: String) -> Bool { s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) } }

    /// 카탈로그 키 · 값(%1$@ 형식) → 웹 사전 형식({0}). 자리표시가 없는 문자열은 그대로(그 안의 % 는 원문)
    public static func fromCatalogForm(_ s: String) -> String {
        guard s.range(of: #"%\d+\$@"#, options: .regularExpression) != nil else { return s }
        let ns = s as NSString
        let rx = try! NSRegularExpression(pattern: #"%(\d+)\$@|%%"#)
        var out = "", last = 0
        for m in rx.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            if m.range(at: 1).location != NSNotFound { out += "{\(Int(ns.substring(with: m.range(at: 1)))! - 1)}" } else { out += "%" }
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }

    /// Localizable.xcstrings → {0} 형식 사전
    public static func loadCatalog(_ url: URL) throws -> [String: String] {
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        var out: [String: String] = [:]
        for (k, v) in (obj?["strings"] as? [String: Any]) ?? [:] {
            guard let e = v as? [String: Any], let loc = e["localizations"] as? [String: Any],
                  let en = loc["en"] as? [String: Any], let su = en["stringUnit"] as? [String: Any],
                  let val = su["value"] as? String, !val.isEmpty else { continue }
            out[fromCatalogForm(k)] = fromCatalogForm(val)
        }
        return out
    }

    public func translate(_ s: String) -> String { translate(s, kind: nil) }

    /// 웹 tr 본체. kind 에 어느 단계에서 옮겼는지 적는다
    public func translate(_ s: String, kind: UnsafeMutablePointer<Kind>?) -> String {
        guard Self.hasHangul(s) else { kind?.pointee = .none; return s }
        let ws = CharacterSet.whitespacesAndNewlines
        let scal = s.unicodeScalars
        let a = scal.firstIndex { !ws.contains($0) } ?? scal.endIndex
        let b = scal.lastIndex { !ws.contains($0) }.map { scal.index(after: $0) } ?? a
        let lead = String(scal[scal.startIndex..<a]), trail = String(scal[b..<scal.endIndex]), core = String(scal[a..<b])
        var out = dict[core], k: Kind = .exact
        if out == nil, core.utf16.count <= 800 {
            let ns = core as NSString, full = NSRange(location: 0, length: ns.length)
            for t in templates {
                guard let m = t.re.firstMatch(in: core, range: full) else { continue }
                let caps = (1..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
                out = Self.fill(t.en) { n in t.order.firstIndex(of: n).map { translate(caps[$0]) } ?? "" }
                k = .template
                break
            }
        }
        if out == nil {
            var t = core
            for (g, v) in gloss where t.contains(g) { t = t.replacingOccurrences(of: g, with: v) }
            out = t; k = .gloss
        }
        // 웹: '1 cells' → '1 cell', '1 enemies' → '1 enemy'
        let o = out!, on = o as NSString
        var fixed = "", last = 0
        for m in Self.plural.matches(in: o, range: NSRange(location: 0, length: on.length)) {
            let w = on.substring(with: m.range(at: 1))
            fixed += on.substring(with: NSRange(location: last, length: m.range.location - last)) + "1 " + (w == "enemie" ? "enemy" : w)
            last = m.range.location + m.range.length
        }
        fixed += on.substring(from: last)
        kind?.pointee = k
        return lead + fixed + trail
    }

    /// "{0} …" 자리를 채운다
    private static func fill(_ tpl: String, _ f: (Int) -> String) -> String {
        let ns = tpl as NSString
        var out = "", last = 0
        for m in hole.matches(in: tpl, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            out += f(Int(ns.substring(with: m.range(at: 1)))!)
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }
}
