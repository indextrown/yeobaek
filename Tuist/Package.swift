// swift-tools-version: 6.0

import PackageDescription

#if TUIST
import ProjectDescription

/// Xcode 27 iOS SDK의 최소 배포 버전(15.0)보다 낮게 선언된 외부 타깃이다.
/// 15.0으로 선언된 다른 외부 모듈이 이 타깃을 import하므로 SDK 최소 버전까지만 올린다.
let iOSTargetsBelowXcodeMinimum = [
    "ConcurrencyExtras",
    "IdentifiedCollections",
    "InternalCollectionsUtilities",
    "IssueReporting",
    "MapboxCommonWrapper",
    "MapboxCoreMapsWrapper",
    "MapboxMaps",
    "OrderedCollections",
    "RxCocoa",
    "RxCocoaRuntime",
    "RxRelay",
    "RxSwift",
    "Turf",
]

/// Xcode 27 macOS SDK의 최소 배포 버전(12.0)보다 낮게 선언된 매크로 빌드용 swift-syntax 타깃이다.
let macOSTargetsBelowXcodeMinimum = [
    "_SwiftSyntaxCShims",
    "SwiftBasicFormat",
    "SwiftCompilerPlugin",
    "SwiftCompilerPluginMessageHandling",
    "SwiftDiagnostics",
    "SwiftIfConfig",
    "SwiftOperators",
    "SwiftParser",
    "SwiftParserDiagnostics",
    "SwiftSyntax",
    "SwiftSyntax509",
    "SwiftSyntax510",
    "SwiftSyntax600",
    "SwiftSyntax601",
    "SwiftSyntax602",
    "SwiftSyntax603",
    "SwiftSyntax604",
    "SwiftSyntaxBuilder",
    "SwiftSyntaxMacroExpansion",
    "SwiftSyntaxMacros",
]

let packageSettings = PackageSettings(
    productTypes: [
        "MapboxMaps": .framework,
        "RxCocoa": .framework,
        "RxRelay": .framework,
        "RxSwift": .framework,
    ],
    targetSettings: Dictionary(
        uniqueKeysWithValues: iOSTargetsBelowXcodeMinimum.map {
            ($0, Settings.settings(base: ["IPHONEOS_DEPLOYMENT_TARGET": "15.0"]))
        } + macOSTargetsBelowXcodeMinimum.map {
            ($0, Settings.settings(base: ["MACOSX_DEPLOYMENT_TARGET": "12.0"]))
        }
    )
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
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            from: "1.26.0"
        ),
    ]
)
