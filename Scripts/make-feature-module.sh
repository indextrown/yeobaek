#!/usr/bin/env bash

set -euo pipefail

module_name="${1:-}"
with_demo="${2:-false}"

if [[ -z "$module_name" ]]; then
    echo "Usage: make module SampleFeature [demo]"
    exit 1
fi

if [[ ! "$module_name" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
    echo "Module name must be an UpperCamelCase Swift identifier."
    exit 1
fi

if [[ "$with_demo" != "true" && "$with_demo" != "false" ]]; then
    echo "Demo option must be true or false."
    exit 1
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
project_directory="$repository_root/Projects/Features/$module_name"
workspace_file="$repository_root/Workspace.swift"
app_project_file="$repository_root/Projects/App/Project.swift"

if [[ -e "$project_directory" ]]; then
    echo "Projects/Features/$module_name already exists."
    exit 1
fi

if [[ ! -f "$workspace_file" || ! -f "$app_project_file" ]]; then
    echo "Workspace.swift or Projects/App/Project.swift was not found."
    exit 1
fi

bundle_suffix="$(printf '%s' "$module_name" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')"

mkdir -p "$project_directory/Sources/$module_name"

cat > "$project_directory/Sources/$module_name/${module_name}View.swift" <<EOF
import SwiftUI

public struct ${module_name}View: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "$module_name",
            systemImage: "square.grid.2x2"
        )
    }
}

#Preview {
    ${module_name}View()
}
EOF

cat > "$project_directory/Project.swift" <<EOF
import ProjectDescription

let project = Project(
    name: "$module_name",
    targets: [
        .target(
            name: "$module_name",
            destinations: [.iPhone],
            product: .framework,
            bundleId: "com.indextrown.yeobaek.$bundle_suffix",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/**"],
            dependencies: [],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
EOF

if [[ "$with_demo" == "true" ]]; then
    mkdir -p "$project_directory/Demo"

    cat > "$project_directory/Demo/${module_name}DemoApp.swift" <<EOF
import $module_name
import SwiftUI

@main
struct ${module_name}DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ${module_name}View()
        }
    }
}
EOF

    cat >> "$project_directory/Project.swift" <<EOF
        .target(
            name: "${module_name}Demo",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.indextrown.yeobaek.$bundle_suffix-demo",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Demo/**"],
            dependencies: [
                .target(name: "$module_name"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
EOF
fi

cat >> "$project_directory/Project.swift" <<EOF
    ]
)
EOF

workspace_entry="        \"Projects/Features/$module_name\"," 
app_dependency="                .project(target: \"$module_name\", path: \"../Features/$module_name\"),"
workspace_temp="$(mktemp)"
app_project_temp="$(mktemp)"

trap 'rm -f "$workspace_temp" "$app_project_temp"' EXIT

awk -v entry="$workspace_entry" '
    !inserted && $0 == "    ]" {
        print entry
        inserted = 1
    }
    { print }
' "$workspace_file" > "$workspace_temp"

if ! grep -Fq "\"Projects/Features/$module_name\"" "$workspace_temp"; then
    echo "Could not register the module in Workspace.swift."
    exit 1
fi

awk -v dependency="$app_dependency" '
    !inserted && $0 == "            dependencies: [" {
        in_dependencies = 1
    }
    in_dependencies && $0 == "            ]," {
        print dependency
        inserted = 1
        in_dependencies = 0
    }
    { print }
' "$app_project_file" > "$app_project_temp"

if ! grep -Fq "target: \"$module_name\"" "$app_project_temp"; then
    echo "Could not connect the module to the App target."
    exit 1
fi

cat "$workspace_temp" > "$workspace_file"
cat "$app_project_temp" > "$app_project_file"

echo "Created Projects/Features/$module_name"
echo "Demo app: $with_demo"
