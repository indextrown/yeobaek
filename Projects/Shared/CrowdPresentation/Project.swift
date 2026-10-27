import ProjectDescription

let project = Project(
    name: "CrowdPresentation",
    targets: [
        .target(
            name: "CrowdPresentation",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.crowd-presentation",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "Domain", path: "../../Domain"),
                .project(target: "Core", path: "../Core"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
        .target(
            name: "CrowdPresentationTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.indextrown.yeobaek.crowd-presentation-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [.target(name: "CrowdPresentation")],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
