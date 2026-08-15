#!/bin/bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
verification_script="$repo_root/scripts/verify-dependency-boundary.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/rectangle-dependency-check.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT

fake_git="$test_directory/git-error"
printf '#!/bin/bash\nexit 2\n' > "$fake_git"
chmod +x "$fake_git"

status=0
output=$(GIT_COMMAND="$fake_git" bash "$verification_script" 2>&1) || status=$?

if [[ $status -ne 2 ]]; then
    echo "Expected dependency verification to preserve scanner exit status 2; got $status" >&2
    echo "$output" >&2
    exit 1
fi

if [[ "$output" != *"Dependency boundary check failed while checking"* ]]; then
    echo "Expected dependency verification to report the scanner failure" >&2
    echo "$output" >&2
    exit 1
fi

fake_app="$test_directory/Rectangle.app"
mkdir -p "$fake_app/Contents/MacOS"
touch "$fake_app/Contents/MacOS/Rectangle"

fake_file="$test_directory/file"
printf '#!/bin/bash\necho "Mach-O universal binary with 2 architectures"\n' > "$fake_file"
chmod +x "$fake_file"

fake_otool="$test_directory/otool"
printf '%s\n' \
    '#!/bin/bash' \
    'candidate=$2' \
    'echo "$candidate (architecture x86_64):"' \
    'echo "    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0)"' \
    'echo "$candidate (architecture arm64):"' \
    'echo "    /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0)"' \
    > "$fake_otool"
chmod +x "$fake_otool"

FILE_COMMAND="$fake_file" OTOOL_COMMAND="$fake_otool" \
    bash "$verification_script" "$fake_app" >/dev/null

echo "Dependency boundary regression tests passed."
