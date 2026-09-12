import ProjectDescription

let project = Project(
    name: "MapBoxFeature",
    targets: [
        .target(
            name: "MapBoxFeature",
            destinations: [.iPhone],
            product: .staticFramework,
            bundleId: "com.indextrown.yeobaek.mapbox-feature",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "Core", path: "../../Shared/Core"),
                .project(target: "Featcher", path: "../../Shared/Featcher"),
                .project(target: "RxExtension", path: "../../Shared/RxExtension"),
                .project(target: "ThirdParty", path: "../../Shared/ThirdParty"),
                .external(name: "MapboxMaps"),
                .external(name: "RxCocoa"),
                .external(name: "RxRelay"),
                .external(name: "RxSwift"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
        .target(
            name: "MapBoxFeatureDemo",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.indextrown.yeobaek.mapbox-feature-demo",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "MBXAccessToken": "$(MAPBOX_ACCESS_TOKEN)",
                    "NSLocationWhenInUseUsageDescription": "현재 위치로 지도를 이동하기 위해 위치 정보가 필요합니다.",
                    "SeoulAPIKey": "$(SEOUL_API_KEY)",
                ]
            ),
            sources: ["Demo/**"],
            dependencies: [
                .target(name: "MapBoxFeature"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        xcconfig: .relativeToManifest("../../App/Configuration.xcconfig")
                    ),
                    .release(
                        name: "Release",
                        xcconfig: .relativeToManifest("../../App/Configuration.xcconfig")
                    ),
                ]
            )
        ),
        .target(
            name: "MapBoxFeatureTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.indextrown.yeobaek.mapbox-feature-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "MapBoxFeature"),
                .external(name: "RxCocoa"),
                .external(name: "RxSwift"),
            ],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
