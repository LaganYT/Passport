// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Passport",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Passport", path: "Sources/Passport")]
)
