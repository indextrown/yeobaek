import ProjectDescription

let project = Project(
    name: "Featcher",
    targets: [
        .target(
            name: "Featcher",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.featcher",
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
            name: "FeatcherDemo",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.indextrown.yeobaek.featcher-demo",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Demo/**"],
            dependencies: [
                .target(name: "Featcher"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
