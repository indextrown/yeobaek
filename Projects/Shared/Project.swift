import ProjectDescription

let project = Project(
    name: "Shared",
    targets: [
        .target(
            name: "Shared",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.shared",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
