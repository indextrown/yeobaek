import ProjectDescription

let project = Project(
    name: "ThirdParty",
    targets: [
        .target(
            name: "ThirdParty",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.third-party",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "MapboxMaps"),
                .external(name: "RxSwift"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
