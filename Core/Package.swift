// swift-tools-version:5.9
// Core 是「不依赖 UIKit / SwiftUI」的纯逻辑层。
// 这样在 Windows 上装个 Swift 工具链就能 `swift test`，秒级拿到反馈，
// 不用等 CI 那 5~15 分钟。界面层留在 App/ 里，只能靠 CI。
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(name: "Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"])
    ]
)
