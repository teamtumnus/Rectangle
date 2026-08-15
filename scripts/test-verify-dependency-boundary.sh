#!/bin/bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
verification_script="$repo_root/scripts/verify-dependency-boundary.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/rectangle-dependency-check.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT

fake_rg="$test_directory/rg-error"
printf '#!/bin/bash\nexit 2\n' > "$fake_rg"
chmod +x "$fake_rg"

status=0
output=$(RG_COMMAND="$fake_rg" bash "$verification_script" 2>&1) || status=$?

if [[ $status -ne 2 ]]; then
    echo "Expected dependency verification to preserve rg exit status 2; got $status" >&2
    echo "$output" >&2
    exit 1
fi

if [[ "$output" != *"Dependency boundary check failed while checking"* ]]; then
    echo "Expected dependency verification to report the scanner failure" >&2
    echo "$output" >&2
    exit 1
fi

echo "Dependency boundary error handling verified."
