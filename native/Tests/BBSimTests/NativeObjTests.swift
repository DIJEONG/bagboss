import Testing
import Foundation
@testable import BBSim
import BBContent

/// 무도장 부서지는 소품(World+NativeObj) — docs/07 §7-OB. 시험 기술은 코크스크루(일직선으로 날아간다 — 패널 '코크스크루로 시험')
@Suite struct NativeObjTests {
    struct Run { var objs: [DojoView.Obj] = [], fx: [String] = [], words: [String] = [], dummyDX = 0.0 }
    /// 허수아비 뒤(주인공 반대쪽) dx 마다 소품을 놓고 id 로 시연
    static func run(_ id: String = "nv_cork", objs: [(String, Double)]) -> Run {
        let sim = DojoNativeTests.dojo(true), w = sim.w
        sim.apply(.dojo(.hero(id, combo: nil))); _ = sim.step()
        let D = w.dojoDummy()!, f = D.x >= w.hero!.x ? 1.0 : -1.0, d0 = D.x
        sim.apply(.dojo(.objSet(objs.map { DojoObjSpec(kind: $0.0, x: d0 + f * $0.1) })))
        var R = Run()
        for _ in 0..<(60 * 3) {
            for e in sim.step() {
                switch e {
                case .comicWord(let wd, _, _): R.words.append(wd)
                case .fx(let k, _, _, _) where k.hasPrefix("objBreak"): R.fx.append(k)
                default: break
                }
            }
            R.dummyDX = max(R.dummyDX, (D.x - d0) * f)
        }
        R.objs = sim.snapshot.dojo?.objs ?? []
        return R
    }

    @Test func glassBreaks() {
        let R = Self.run(objs: [("glass", 50)]), F = Self.run(objs: [])
        print("[소품 · 유리] \(R.objs) · 효과 \(R.fx) · 날아간 거리 \(R.dummyDX)(소품 없이 \(F.dummyDX))")
        #expect(R.objs.count == 1 && R.objs[0].broken)
        #expect(R.fx == ["objBreak:glass"] && R.words.contains("와장창!"))
        #expect(R.dummyDX < F.dummyDX - 20)   // 유리에 박혀 멈춘다
    }

    @Test func crateAndShojiAndBump() {
        let C = Self.run(objs: [("crate", 40), ("shoji", 70)])
        print("[소품 · 상자+장지문] \(C.objs.map { "\($0.kind):\($0.broken)" }) · \(C.fx)")
        #expect(C.objs.first { $0.kind == "crate" }?.broken == true)   // 상자에서 속도를 절반 넘게 잃어 뒤의 장지문은 못 깰 수도 있다
        // 느린 비행(어퍼컷 띄움)은 소품을 깨지 못하고 튕긴다 — 유리를 바로 뒤에
        let U = Self.run("upper", objs: [("glass", 14)])
        #expect(U.objs.allSatisfy { !$0.broken })
    }

    @Test func commandsAndRepair() {
        let sim = DojoNativeTests.dojo(true)
        sim.apply(.dojo(.objAdd("glass", nil))); sim.apply(.dojo(.objAdd("crate", 9999))); sim.apply(.dojo(.objAdd("nope", 100)))
        _ = sim.step()
        var O = sim.snapshot.dojo!.objs
        #expect(O.map(\.kind) == ["glass", "crate"] && O[1].x == DojoObjKind.maxX)
        sim.apply(.dojo(.objMove(O[0].id, 200))); sim.apply(.dojo(.objRemove(O[1].id))); _ = sim.step()
        O = sim.snapshot.dojo!.objs
        #expect(O.count == 1 && O[0].x == 200)
        for _ in 0..<10 { sim.apply(.dojo(.objAdd("crate", 100))) }
        _ = sim.step(); #expect(sim.snapshot.dojo!.objs.count == DojoObjKind.maxCount)
        sim.apply(.dojo(.objClear)); _ = sim.step(); #expect(sim.snapshot.dojo!.objs.isEmpty)
    }

    /// 회오리 옆차기는 지웠다(2026-10-13 감독) — 아이템 · 자세가 없다
    @Test func tornadoRemoved() {
        #expect(NativeGuardTests.on.item("nv_tornado") == nil && NativeGuardTests.on.poses["tn_hit"] == nil && NativeGuardTests.on.seqJW["nv_tornado"] == nil)
    }
}
