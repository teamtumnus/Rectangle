#!/bin/bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
git_command=${GIT_COMMAND:-git}

fail_with_matches() {
    local description=$1
    shift
    local matches
    local status

    if matches=$("$git_command" grep -n -E -- "$@" 2>&1); then
        echo "Dependency boundary violation: $description" >&2
        echo "$matches" >&2
        exit 1
    else
        status=$?
    fi

    if [[ $status -ne 1 ]]; then
        echo "Dependency boundary check failed while checking: $description" >&2
        echo "$matches" >&2
        exit "$status"
    fi
}

fail_with_matches \
    "remote Swift package reference" \
    'XCRemoteSwiftPackageReference|repositoryURL[[:space:]]*=|\.package[[:space:]]*\(' \
    -- 'Rectangle.xcodeproj/**/project.pbxproj' 'LocalPackages/**/Package.swift'

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
        file_description=$(file -b "$candidate")
        case "$file_description" in
            Mach-O*) ;;
            *) continue ;;
        esac

        case "$candidate" in
            */Contents/MacOS/*|*/Contents/Frameworks/libswift*.dylib)
                ;;
            *)
                echo "Dependency boundary violation: unexpected packaged Mach-O component" >&2
                echo "$candidate" >&2
                exit 1
                ;;
        esac

        if ! otool_output=$(otool -L "$candidate" 2>&1); then
            echo "Dependency boundary check failed while inspecting dynamic libraries" >&2
            echo "$candidate" >&2
            echo "$otool_output" >&2
            exit 1
        fi

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
        done < <(printf '%s\n' "$otool_output" | awk 'NR > 1 { print $1 }')
    done < <(find "$app_path/Contents" -type f -print0)
fi

echo "Dependency boundary verified."
