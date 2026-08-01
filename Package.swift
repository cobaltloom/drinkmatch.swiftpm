// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "DrinkMatch",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "DrinkMatch",
            targets: ["AppModule"],
            bundleIdentifier: "com.translate5jp.DrinkMatch",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .cat),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)
