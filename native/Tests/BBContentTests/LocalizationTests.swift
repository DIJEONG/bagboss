import Testing
import Foundation
@testable import BBContent

/// 다국어(영어): 카탈로그 형식 · 번역기(웹 tr 이식) 표본 · 소스 범위 점검(l10n-audit.mjs + 허용 목록) · JS/Swift 번역 결과 대조.
/// 전역 Loc.lang 은 바꾸지 않는다(다른 시험이 한국어 HUD 를 웹과 대조하며 병렬로 돈다) — 번역기 · 별도 LocStore 로 본다.
@Suite struct LocalizationTests {
    static let catalogURL = GeneratedResources.url.appending(path: "Localizable.xcstrings")
    static let T = LocTranslator(dict: (try? LocTranslator.loadCatalog(catalogURL)) ?? [:])
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // MARK: 카탈로그 형식

    @Test("카탈로그: 원문 ko · 모든 항목 en 번역 · 자리표시(%n$@) 집합이 원문과 같다") func catalogWellFormed() throws {
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: Self.catalogURL)) as? [String: Any])
        #expect(obj["sourceLanguage"] as? String == "ko")
        let strings = try #require(obj["strings"] as? [String: Any])
        #expect(strings.count > 1400)
        let rx = try NSRegularExpression(pattern: #"%(\d+)\$@"#)
        func holes(_ s: String) -> Set<Int> {
            Set(rx.matches(in: s, range: NSRange(location: 0, length: (s as NSString).length)).map { Int((s as NSString).substring(with: $0.range(at: 1)))! })
        }
        var bad: [String] = []
        for (k, v) in strings {
            let e = v as? [String: Any], en = ((e?["localizations"] as? [String: Any])?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            guard let val = en?["value"] as? String, !val.isEmpty, en?["state"] as? String == "translated" else { bad.append("빈 번역: \(k)"); continue }
            let hk = holes(k)
            if hk != holes(val) { bad.append("자리표시 불일치: \(k) → \(val)") }
            // 번호가 비는 키(웹 사전의 조각 문장 '각인 · {1}: {2}')는 허용 — 번역기는 정규식으로 맞추고 String(format:) 을 쓰지 않는다
            if LocTranslator.hasHangul(val) { bad.append("영어에 한글: \(k) → \(val)") }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test("카탈로그 → {0} 형식: %% 는 자리표시가 있는 문자열에서만 % 로") func catalogFormRoundTrip() {
        #expect(LocTranslator.fromCatalogForm("%1$@까지 %2$@초") == "{0}까지 {1}초")
        #expect(LocTranslator.fromCatalogForm("성공 %1$@%%") == "성공 {0}%")
        #expect(LocTranslator.fromCatalogForm("피해 +20%") == "피해 +20%")
    }

    // MARK: 번역기 표본(웹 tr 과 같은 순서)

    @Test("정확한 문장 · 앞뒤 공백 보존 · 한글 없는 글은 그대로") func exactLookups() {
        #expect(Self.T.translate("저스트!") == "JUST!")
        #expect(Self.T.translate("  쾅!  ") == "  BAM!  ")
        #expect(Self.T.translate("BAG BOSS 3F") == "BAG BOSS 3F")
        #expect(Self.T.translate("서류가방") == "Briefcase")
    }

    @Test("자리표시 문장: 순서 바뀜 · 잡힌 조각도 다시 번역(역 이름)") func templates() {
        var k = LocTranslator.Kind.none
        // 웹 사전: '{0}까지 {1}초 · 남은 적 {2}' → '{1}s to {0} · {2} enemies left'
        let s = Self.T.translate("110번가까지 12초 · 남은 적 3", kind: &k)
        #expect(k == .template)
        #expect(s == "12s to 110 St · 3 enemies left")
        // 웹 en 삼항에서 거둔 문장(45-hud): 정차 중 · 적 n · 역
        #expect(Self.T.translate("정차 중 · 적 4 · 125번가") == "Stopped · 4 foes · 125 St")
        // 보충(strings-extra.json)
        #expect(Self.T.translate("3구간 돌파!") == "Zone 3 cleared!")
    }

    @Test("용어 치환 · '1 cells' 단수 고치기") func glossAndPlural() {
        var k = LocTranslator.Kind.none
        let g = Self.T.translate("새 콤보: 공중 4연타", kind: &k)
        #expect(!LocTranslator.hasHangul(g), "\(g)")
        #expect(LocTranslator(dict: ["{0}칸": "{0} cells"]).translate("1칸") == "1 cell")
        #expect(LocTranslator(dict: ["{0}칸": "{0} cells"]).translate("11칸") == "11 cells")
        #expect(LocTranslator(dict: ["적 {0}명": "{0} enemies"]).translate("적 1명") == "1 enemy")
    }

    @Test("콘텐츠 표 · 대화 · 도움말 · 만화 효과음 표본") func contentSamples() {
        #expect(Self.T.translate("총주방장실") == "Head Chef's Kitchen")          // TW_FLOORS.en
        #expect(Self.T.translate("정전이 잦아요") == "More blackouts")             // TW_OT.en
        #expect(Self.T.translate("노 차장") == "Conductor Noh")                    // CAST
        #expect(Self.T.translate("비싸군.") == "Pricey.")                          // 대화 고르기
        #expect(Self.T.translate("호외요! <b>서류가방 결재</b>, 콤보 도감 첫 완성이에요!") == "Extra! <b>Briefcase Sign-off</b> — first entry in your combo codex!")
        #expect(Self.T.translate("저스트 받아치기") == "Just Counter")             // HINTS.just
        #expect(Self.T.translate("콰직!") == "CRUNCH!")
    }

    @Test("LocStore: 한국어면 그대로 · 영어면 번역 · 언어 바꾸면 캐시 비움") func storeLanguageSwitch() {
        let st = LocStore()
        #expect(st.tr("저스트!") == "저스트!")
        st.setLang("en")
        #expect(st.tr("저스트!") == "JUST!")
        #expect(st.tr("저스트!") == "JUST!")   // 캐시
        st.setLang("ko")
        #expect(st.tr("저스트!") == "저스트!")
    }

    // MARK: 소스 범위 점검(node) + JS/Swift 번역 대조

    /// node 가 있으면 tools/js/extract/l10n-audit.mjs 를 돌려 결과 JSON 을 읽는다(없으면 건너뜀)
    static func runAudit() throws -> [String: Any]? {
        let script = repo.appending(path: "tools/js/extract/l10n-audit.mjs")
        guard FileManager.default.fileExists(atPath: script.path) else { return nil }
        // node 찾기: BB_NODE → PATH(nvm 포함) → 흔한 자리
        let env = ProcessInfo.processInfo.environment
        var cands = [env["BB_NODE"]].compactMap { $0 }
        cands += (env["PATH"] ?? "").split(separator: ":").map { "\($0)/node" }
        cands += ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
        let nvm = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".nvm/versions/node")
        if let vs = try? FileManager.default.contentsOfDirectory(atPath: nvm.path) { cands += vs.sorted().reversed().map { nvm.appending(path: "\($0)/bin/node").path } }
        guard let node = cands.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
        let out = FileManager.default.temporaryDirectory.appending(path: "bb-l10n-audit-\(UUID().uuidString).json")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: node)
        p.arguments = [script.path, "--json", out.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        defer { try? FileManager.default.removeItem(at: out) }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: out)) as? [String: Any]
    }

    @Test("소스 범위 점검: 허용 목록 밖에 번역이 빠진 한글 리터럴이 없다 · Swift 번역 == JS 번역") func auditAndParity() throws {
        guard let r = try Self.runAudit() else { return }   // node 없는 환경(CI 등)은 건너뜀
        let missing = (r["missing"] as? [[String: Any]]) ?? []
        #expect(missing.isEmpty, "빠짐: \(missing.prefix(8).compactMap { $0["text"] as? String })")
        let all = (r["all"] as? [[String: Any]]) ?? []
        #expect(all.count > 300)
        var diff: [String] = []
        for it in all {
            guard let text = it["text"] as? String, let en = it["en"] as? String else { continue }
            let sample = text.replacingOccurrences(of: #"\{\d+\}"#, with: "7", options: .regularExpression)
            let sw = Self.T.translate(sample)
            if sw != en { diff.append("\(text) → JS \(en) · Swift \(sw)") }
        }
        #expect(diff.isEmpty, "\(diff.prefix(8))")
    }
}
