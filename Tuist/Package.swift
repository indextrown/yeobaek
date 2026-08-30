// swift-tools-version: 6.0

import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "MapboxMaps": .framework,
    ]
)
#endif

let package = Package(
    name: "Yeobaek",
    dependencies: [
        .package(
            url: "https://github.com/mapbox/mapbox-maps-ios.git",
            from: "11.27.0"
        ),
    ]
)
