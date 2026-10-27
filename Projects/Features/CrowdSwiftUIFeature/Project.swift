import ProjectDescription

let project = Project(
    name: "CrowdSwiftUIFeature",
    targets: [
        .target(
            name: "CrowdSwiftUIFeature",
            destinations: [.iPhone],
            product: .staticFramework,
            bundleId: "com.indextrown.yeobaek.crowd-swiftui-feature",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "Domain", path: "../../Domain"),
                .project(target: "Core", path: "../../Shared/Core"),
                .project(target: "CrowdPresentation", path: "../../Shared/CrowdPresentation"),
                .project(target: "ThirdParty", path: "../../Shared/ThirdParty"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
        .target(
            name: "CrowdSwiftUIFeatureTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.indextrown.yeobaek.crowd-swiftui-feature-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [.target(name: "CrowdSwiftUIFeature")],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
