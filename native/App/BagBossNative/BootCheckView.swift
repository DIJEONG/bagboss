import SwiftUI
import BBContent

/// N0 점검 화면: 생성물이 번들에 들어왔고 타입으로 읽히는지, 아틀라스 한 장을 팔레트로 칠해 보이는지.
struct BootCheckView: View {
    @State private var report: Result<Report, Error>?

    struct Report {
        let sourceSha: String
        let lines: [(String, String)]
        let preview: CGImage?
    }

    var body: some View {
        NavigationStack {
            Group {
                switch report {
                case .none: ProgressView("데이터 읽는 중")
                case .failure(let e): Text("실패: \(String(describing: e))").foregroundStyle(.red).padding()
                case .success(let r):
                    List {
                        Section("원본 \(r.sourceSha)") {
                            ForEach(r.lines, id: \.0) { k, v in LabeledContent(k, value: v) }
                        }
                        if let img = r.preview {
                            Section("아틀라스 미리보기 (팔레트 0 · 조명 없음)") {
                                Image(decorative: img, scale: 1).interpolation(.none).resizable().scaledToFit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("BAG BOSS · N0")
        }
        .task { report = await Task.detached { Result { try Self.load() } }.value }
    }

    nonisolated static func load() throws -> Report {
        let t0 = Date()
        let store = try ContentStore.bundled()
        let game = try GameContent(store)
        let atlas = try AtlasMeta.bundled()
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        let lines: [(String, String)] = [
            ("아이템", "\(game.items.count)"), ("적", "\(game.enemies.count)"), ("노선", "\(game.stages.count)"),
            ("시작 가방", "\(game.kits.count)"), ("연계", "\(game.links.count)"), ("타워 층", "\(game.towerFloors.compactMap { $0 }.count)"),
            ("데이터 이름", "\(store.names.count)"), ("스프라이트", "\(atlas.sprites.count)"),
            ("아틀라스", "\(atlas.atlas.width)×\(atlas.atlas.height)"), ("읽기", "\(ms)ms"),
            ("노멀 디코드", AtlasPreview.normalProbe() ? "정상" : "알파가 곱해짐 — 렌더 불가"),
        ]
        return Report(sourceSha: store.sourceSha16, lines: lines, preview: try? AtlasPreview.image(sprite: "fs_bar", meta: atlas))
    }
}
