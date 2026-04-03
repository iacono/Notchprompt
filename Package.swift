// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchPrompter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotchPrompter",
            path: "NotchPrompter",
            exclude: [
                "Resources/NotchPrompter.entitlements",
                "Resources/Info.plist",
                "Resources/AppIcon.icns",
                "Resources/AppIcon.iconset",
                "Resources/icon_16x16.png",
                "Resources/icon_16x16@2x.png",
                "Resources/icon_32x32.png",
                "Resources/icon_32x32@2x.png",
                "Resources/icon_128x128.png",
                "Resources/icon_128x128@2x.png",
                "Resources/icon_256x256.png",
                "Resources/icon_256x256@2x.png",
                "Resources/icon_512x512.png",
                "Resources/icon_512x512@2x.png",
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
