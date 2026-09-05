import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        .target(
            name: "YeobaekApp",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.indextrown.yeobaek",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDevelopmentRegion": "ko",
                    "CFBundleDisplayName": "여백",
                    "CFBundleLocalizations": ["ko"],
                    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                    "MBXAccessToken": "$(MAPBOX_ACCESS_TOKEN)",
                    "NSLocationWhenInUseUsageDescription": "현재 위치로 지도를 이동하기 위해 위치 정보가 필요합니다.",
                    "SeoulAPIKey": "$(SEOUL_API_KEY)",
                    "UILaunchScreen": [:],
                    "UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                    ],
                ]
            ),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .project(target: "Data", path: "../Data"),
                .project(target: "Domain", path: "../Domain"),
                .project(target: "Core", path: "../Shared/Core"),
                .project(target: "ThirdParty", path: "../Shared/ThirdParty"),
                .project(target: "MapFeature", path: "../Features/MapFeature"),
                .project(target: "MapBoxFeature", path: "../Features/MapBoxFeature"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                    "MARKETING_VERSION": "0.1.0",
                    "CURRENT_PROJECT_VERSION": "1",
                    "CODE_SIGN_STYLE": "Automatic",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        xcconfig: .relativeToManifest("Configuration.xcconfig")
                    ),
                    .release(
                        name: "Release",
                        xcconfig: .relativeToManifest("Configuration.xcconfig")
                    ),
                ]
            )
        ),
        .target(
            name: "YeobaekAppUITests",
            destinations: [.iPhone],
            product: .uiTests,
            bundleId: "com.indextrown.yeobaek.ui-tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["UITests/**"],
            dependencies: [
                .target(name: "YeobaekApp"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
