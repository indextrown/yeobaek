import ProjectDescription

let project = Project(
    name: "CrowdFeature",
    targets: [
        .target(
            name: "CrowdFeature",
            destinations: [.iPhone],
            product: .staticFramework,
            bundleId: "com.indextrown.yeobaek.crowd-feature",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "Domain", path: "../../Domain"),
                .project(target: "Core", path: "../../Shared/Core"),
                .project(target: "ThirdParty", path: "../../Shared/ThirdParty"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
        .target(
            name: "CrowdFeatureTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.indextrown.yeobaek.crowd-feature-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [.target(name: "CrowdFeature")],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
