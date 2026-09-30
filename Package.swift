// swift-tools-version: 6.2

import PackageDescription


let package = Package(
    name: "SwiftLAME",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        // Dynamic, not static, and this is a licence requirement rather than a
        // technical preference: LGPL-2.1 §6 wants the user to be able to modify
        // the library and relink it against the app. An embedded dynamic
        // framework is that clause's practical form on iOS; the alternative is
        // to offer relinkable object files with every release. See
        // ../../../THIRD-PARTY.md.
        .library(
            name: "SwiftLAME",
            type: .dynamic,
            targets: [
                "SwiftLAME"
            ]
        )
    ],
    targets: [
        
        // Targets
        
        .target(
            name: "SwiftLAME",
            dependencies: ["LAME"]
        ),
        .target(
            name: "LAME",
            publicHeadersPath: "include",
            cSettings: [
                .define("HAVE_CONFIG_H"),
                .disableWarning("absolute-value"),
                .disableWarning("shift-negative-value"),
                .disableWarning("tautological-pointer-compare")
            ]
        ),
        
        // Tests
        
        .testTarget(
            name: "SwiftLAMETests",
            dependencies: ["SwiftLAME"]
        )
    ]
)
