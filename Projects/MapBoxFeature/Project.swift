import ProjectDescription

let project = Project(
    name: "MapBoxFeature",
    targets: [
        .target(
            name: "MapBoxFeature",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.mapbox-feature",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "Shared", path: "../Shared"),
                .project(target: "ThirdParty", path: "../ThirdParty"),
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
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        xcconfig: .relativeToManifest("../App/Secrets.xcconfig")
                    ),
                    .release(
                        name: "Release",
                        xcconfig: .relativeToManifest("../App/Secrets.xcconfig")
                    ),
                ]
            )
        ),
    ]
)
