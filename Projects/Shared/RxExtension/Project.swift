import ProjectDescription

let project = Project(
    name: "RxExtension",
    targets: [
        .target(
            name: "RxExtension",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.rx-extension",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "ThirdParty", path: "../ThirdParty"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
