#!/usr/bin/env bash
# Lint, build, and run patch/fixture with ring patched from this checkout's
# committed HEAD through git, the way a binary patches it from rind's
# repository, then check that ring resolves to the shim alone.
#
# Usage: sh/patch.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

rev=$(git rev-parse HEAD)
args=(
    --manifest-path patch/fixture/Cargo.toml
    --config "patch.crates-io.ring.git=\"file://$PWD\""
    --config "patch.crates-io.ring.rev=\"$rev\""
)

cargo fmt --check --manifest-path patch/ring/Cargo.toml
cargo fmt --check --manifest-path patch/fixture/Cargo.toml

# A second ring would be crates.io's, kept by a requirement the shim's version
# does not meet. Metadata resolves every target, as a build of any would.
sources=$(cargo metadata "${args[@]}" --format-version 1 | jq -r '.packages[] | select(.name == "ring") | .source')
if [[ "$sources" != "git+file://$PWD?rev=$rev#$rev" ]]; then
    echo "error: ring resolves to $sources, not the shim at $rev" >&2
    exit 1
fi

cargo clippy "${args[@]}" --target-dir target -- --deny warnings
cargo run "${args[@]}" --target-dir target
