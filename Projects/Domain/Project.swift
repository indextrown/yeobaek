import ProjectDescription

let project = Project(
    name: "Domain",
    targets: [
        .target(
            name: "Domain",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.domain",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: []
        ),
    ]
)
