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
            name: "Crew Board",
            targets: ["AppModule"],
            bundleIdentifier: "com.translate5jp.DrinkMatch",
            displayVersion: "1.0",
            bundleVersion: "2",
            appIcon: .asset("AppIcon"),
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
    targets: [
        .executableTarget(
            name: "AppModule"
        )
    ]
)
