#if canImport(UIKit)
import UIKit
import BBContent

// 가방 화면 글자 번역 — 그리는(대입하는) 자리에서 BBContent Loc 으로 옮긴다(웹은 DOM 글자 노드마다 tr).
// 꾸민 글(NSAttributedString)은 속성 덩어리(run)마다 옮긴다 — 웹에서 <span> 하나가 글자 노드 하나인 것과 같다.
// 한국어 모드면 그대로 돌려준다(비용 없음).

func bagTr(_ s: String) -> String { Loc.tr(s) }

func bagTrA(_ a: NSAttributedString) -> NSAttributedString {
    guard Loc.isEN, a.length > 0 else { return a }
    let m = NSMutableAttributedString(), ns = a.string as NSString
    a.enumerateAttributes(in: NSRange(location: 0, length: a.length)) { attrs, r, _ in
        m.append(NSAttributedString(string: Loc.tr(ns.substring(with: r)), attributes: attrs))
    }
    return m
}
#endif
