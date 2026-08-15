#!/bin/bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

fail_with_matches() {
    local description=$1
    shift
    local matches
    if matches=$(rg -n "$@" 2>/dev/null); then
        echo "Dependency boundary violation: $description" >&2
        echo "$matches" >&2
        exit 1
    fi
}

fail_with_matches \
    "remote Swift package reference" \
    'XCRemoteSwiftPackageReference|repositoryURL[[:space:]]*=|\.package[[:space:]]*\(' \
    Rectangle.xcodeproj LocalPackages \
    --glob 'project.pbxproj' --glob 'Package.swift'

resolved_files=$(git ls-files '*Package.resolved')
if [[ -n "$resolved_files" ]]; then
    echo "Dependency boundary violation: Package.resolved must not be present" >&2
    echo "$resolved_files" >&2
    exit 1
fi

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [Rectangle.app]" >&2
    exit 2
fi

if [[ $# -eq 1 ]]; then
    app_path=$1
    if [[ ! -d "$app_path/Contents" ]]; then
        echo "Expected a built app bundle: $app_path" >&2
        exit 2
    fi

    while IFS= read -r -d '' candidate; do
        if ! file -b "$candidate" | rg -q '^Mach-O'; then
            continue
        fi

        case "$candidate" in
            */Contents/MacOS/*|*/Contents/Frameworks/libswift*.dylib)
                ;;
            *)
                echo "Dependency boundary violation: unexpected packaged Mach-O component" >&2
                echo "$candidate" >&2
                exit 1
                ;;
        esac

        while IFS= read -r dependency; do
            case "$dependency" in
                /System/Library/*|/usr/lib/*|@rpath/libswift*.dylib|@loader_path/libswift*.dylib|@executable_path/libswift*.dylib)
                    ;;
                *)
                    echo "Dependency boundary violation: unexpected dynamic library" >&2
                    echo "$candidate -> $dependency" >&2
                    exit 1
                    ;;
            esac
        done < <(otool -L "$candidate" | tail -n +2 | awk '{print $1}')
    done < <(find "$app_path/Contents" -type f -print0)
fi

echo "Dependency boundary verified."
