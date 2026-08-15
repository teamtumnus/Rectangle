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

echo "Dependency boundary error handling verified."
