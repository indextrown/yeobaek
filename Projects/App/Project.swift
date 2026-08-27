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
                    "UILaunchScreen": [:],
                    "UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                    ],
                ]
            ),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                    "MARKETING_VERSION": "0.1.0",
                    "CURRENT_PROJECT_VERSION": "1",
                    "CODE_SIGN_STYLE": "Automatic",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                ]
            )
        ),
    ]
)
