// swift-tools-version: 6.0
// BAG BOSS 네이티브 코어 — 모듈 경계는 타깃 의존성으로 강제한다(docs/06 §2).
// 아래로만 의존: Core ← Content ← Anim ← Sim ← Presentation ← (Render · Audio · Haptics · UI) / Persistence
// BBSim 은 UIKit · Metal · AVFoundation 을 import 하지 않는다(macOS 에서 `swift test` 로 바로 돈다).
import PackageDescription

let package = Package(
    name: "BagBossKit",
    defaultLocalization: "ko",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BagBossKit", targets: [
            "BBCore", "BBContent", "BBAnim", "BBSim", "BBPresentation",
            "BBRender", "BBAudio", "BBHaptics", "BBPersistence", "BBUI",
        ]),
    ],
    targets: [
        .target(name: "BBCore"),
        .target(name: "BBContent", dependencies: ["BBCore"], resources: [.copy("Resources/Generated")]),
        .target(name: "BBAnim", dependencies: ["BBCore", "BBContent"]),
        .target(name: "BBSim", dependencies: ["BBCore", "BBContent", "BBAnim"]),
        .target(name: "BBPresentation", dependencies: ["BBCore", "BBContent", "BBAnim", "BBSim"]),
        .target(name: "BBRender", dependencies: ["BBCore", "BBContent", "BBPresentation"], resources: [.copy("Resources/Shaders.metal")]),
        .target(name: "BBAudio", dependencies: ["BBCore", "BBContent", "BBPresentation"], resources: [.copy("Resources/Hits")]),   // 녹음 타격음 조각(docs/11)
        .target(name: "BBHaptics", dependencies: ["BBCore", "BBSim", "BBPresentation"]),
        .target(name: "BBPersistence", dependencies: ["BBCore"]),
        .target(name: "BBUI", dependencies: ["BBCore", "BBContent", "BBSim", "BBPresentation"]),

        .testTarget(name: "BBCoreTests", dependencies: ["BBCore"]),
        .testTarget(name: "BBContentTests", dependencies: ["BBContent"]),
        .testTarget(name: "BBRenderTests", dependencies: ["BBRender", "BBContent"]),
        .testTarget(name: "BBAnimTests", dependencies: ["BBAnim", "BBContent"]),
        .testTarget(name: "BBLabTests", dependencies: ["BBRender", "BBAnim", "BBContent"]),
        .testTarget(name: "BBSimTests", dependencies: ["BBSim", "BBContent", "BBCore"]),
        .testTarget(name: "BBPersistenceTests", dependencies: ["BBPersistence"]),
        .testTarget(name: "BBAudioTests", dependencies: ["BBAudio", "BBContent"]),
        .testTarget(name: "BBPresentationTests", dependencies: ["BBPresentation", "BBRender", "BBContent", "BBSim", "BBCore"]),
        .testTarget(name: "BBUITests", dependencies: ["BBUI", "BBSim", "BBContent"]),
        .testTarget(name: "BBHapticsTests", dependencies: ["BBHaptics", "BBSim"]),
    ],
    swiftLanguageModes: [.v6]
)
