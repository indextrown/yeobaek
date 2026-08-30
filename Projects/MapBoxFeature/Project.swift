import ProjectDescription

let project = Project(
    name: "MapBoxFeature",
    packages: [
        .remote(
            url: "https://github.com/mapbox/mapbox-maps-ios.git",
            requirement: .upToNextMajor(from: "11.27.0")
        ),
    ],
    targets: [
        .target(
            name: "MapBoxFeature",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.mapbox-feature",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .package(product: "MapboxMaps"),
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
                ]
            ),
            sources: ["Demo/**"],
            dependencies: [
                .target(name: "MapBoxFeature"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
