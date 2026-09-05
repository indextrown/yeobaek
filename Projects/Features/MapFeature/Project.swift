import ProjectDescription

let project = Project(
    name: "MapFeature",
    targets: [
        .target(
            name: "MapFeature",
            destinations: [.iPhone],
            product: .staticFramework,
            bundleId: "com.indextrown.yeobaek.map-feature",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
        .target(
            name: "MapFeatureDemo",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.indextrown.yeobaek.map-feature-demo",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "NSLocationWhenInUseUsageDescription": "현재 위치로 지도를 이동하기 위해 위치 정보가 필요합니다.",
                    "SeoulAPIKey": "$(SEOUL_API_KEY)",
                ]
            ),
            sources: ["Demo/**"],
            dependencies: [
                .target(name: "MapFeature"),
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
            name: "MapFeatureTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.indextrown.yeobaek.map-feature-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [.target(name: "MapFeature")],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
