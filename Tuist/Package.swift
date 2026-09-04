// swift-tools-version: 6.0

import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "MapboxMaps": .framework,
        "RxSwift": .framework,
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
        .package(
            url: "https://github.com/ReactiveX/RxSwift.git",
            from: "6.10.0"
        ),
    ]
)
