// swift-tools-version: 6.0

import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "MapboxMaps": .framework,
        "RxCocoa": .framework,
        "RxRelay": .framework,
        "RxSwift": .framework,
    ],
    targetSettings: [
        "MapboxCommonWrapper": .externalDeploymentTarget,
        "MapboxCoreMapsWrapper": .externalDeploymentTarget,
        "MapboxMaps": .externalDeploymentTarget,
        "RxCocoa": .externalDeploymentTarget,
        "RxCocoaRuntime": .externalDeploymentTarget,
        "RxRelay": .externalDeploymentTarget,
        "RxSwift": .externalDeploymentTarget,
        "Turf": .externalDeploymentTarget,
    ]
)

extension Settings {
    /// Xcode 27 iOS SDK의 최소 배포 버전(15.0)보다 낮게 선언된 외부 패키지를 앱 최소 버전에 맞춘다.
    static var externalDeploymentTarget: Settings {
        .settings(base: ["IPHONEOS_DEPLOYMENT_TARGET": "17.0"])
    }
}
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
