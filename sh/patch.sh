#!/usr/bin/env bash
# Lint, build, and run patch/fixture through moq-dev/rind-patch's ring and
# aws-lc-rs shims, with both adapters patched to this checkout. Check that
# only the shims and local adapters resolve, with no aws-lc-sys.
#
# Usage: sh/patch.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

args=(
    --manifest-path patch/fixture/Cargo.toml
    --config "patch.crates-io.rind-ring.path=\"$PWD/rind-ring\""
    --config "patch.crates-io.rind-aws-lc-rs.path=\"$PWD/rind-aws-lc-rs\""
)

cargo fmt --check --manifest-path patch/fixture/Cargo.toml

# A lockfile from an earlier run pins that run's rind-patch commit, so take
# the fixture's shim revisions afresh.
cargo generate-lockfile "${args[@]}"

# A second ring or aws-lc-rs would be crates.io's, kept by a requirement the
# shim's version does not meet. A registry adapter would mean the shim requires
# a version this checkout no longer has. Metadata resolves every target.
packages=$(cargo metadata "${args[@]}" --format-version 1 |
    jq -r '.packages[] | select(.name == "ring" or .name == "rind-ring" or .name == "aws-lc-rs" or .name == "rind-aws-lc-rs" or .name == "aws-lc-sys" or .name == "aws-lc-fips-sys") | "\(.name) \(.source)"' | sort)
shim='git\+https://github\.com/moq-dev/rind-patch(\?rev=[0-9a-f]{40})?#[0-9a-f]{40}'
expected="^aws-lc-rs $shim"$'\nrind-aws-lc-rs null\nrind-ring null\n'"ring $shim\$"
if [[ ! "$packages" =~ $expected ]]; then
    echo "error: expected only rind-patch's shims and this checkout's adapters, without aws-lc-sys, got:" >&2
    echo "$packages" >&2
    exit 1
fi

cargo clippy "${args[@]}" --target-dir target -- --deny warnings
cargo run "${args[@]}" --target-dir target
