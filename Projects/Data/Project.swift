import ProjectDescription

let project = Project(
    name: "Data",
    targets: [
        .target(
            name: "Data",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.data",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .project(target: "Domain", path: "../Domain"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
        .target(
            name: "DataTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.indextrown.yeobaek.data-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**/*.swift"],
            resources: ["Tests/Fixtures/**"],
            dependencies: [.target(name: "Data")],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
    ]
)
