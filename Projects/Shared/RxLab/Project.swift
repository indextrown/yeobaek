import ProjectDescription

let project = Project(
    name: "RxLab",
    targets: [
        .target(
            name: "RxLab",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.rx-lab",
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
        .target(
            name: "RxLabDemo",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.indextrown.yeobaek.rx-lab-demo",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Demo/**"],
            dependencies: [
                .target(name: "RxLab"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
