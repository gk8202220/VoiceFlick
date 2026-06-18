// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceFlick",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceFlick", targets: ["VoiceFlick"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceFlick",
            path: "Sources/GestureDictation"
        ),
        .testTarget(
            name: "VoiceFlickTests",
            dependencies: ["VoiceFlick"],
            path: "Tests/GestureDictationTests"
        )
    ]
)
