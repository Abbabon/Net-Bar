// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetSpeedMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NetBar",
            targets: ["NetSpeedMonitor"]
        )
    ],
    targets: [
        .target(
            name: "NetTrafficStat",
            path: "Sources/NetTrafficStat"
        ),
        .executableTarget(
            name: "NetSpeedMonitor",
            dependencies: ["NetTrafficStat"],
            path: "Sources/NetSpeedMonitor",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
