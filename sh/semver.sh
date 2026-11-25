#!/usr/bin/env bash
# Fail a branch that breaks the public API of a published crate it changed,
# unless it is marked breaking. cargo-semver-checks compares each crate's
# rustdoc at HEAD with the same crate at the branch's merge-base: crates.io's
# release is the wrong baseline, since main holds every breaking change a
# minor release batches.
#
# Usage: sh/semver.sh [BASE]
# rind below 1.0 may break only in a minor release, which a `!` marks: a
# commit subject between BASE and HEAD, or PR_TITLE, as in `feat(kem)!: ...`.
# A marked branch skips rind's check. An adapter's API is its upstream's, so no
# mark excuses it: it breaks only in the change that sets its version to its
# upstream's next breaking release, which cargo-semver-checks reads from the
# manifest.
set -euo pipefail

usage="usage: sh/semver.sh [BASE]"
if [[ $# -gt 1 ]]; then
    echo "$usage" >&2
    exit 2
fi

cd "$(git rev-parse --show-toplevel)"
base=$(sh/changed.sh --merge-base "${1:-}")
changed=$(sh/changed.sh "$base")

# The crates that reach crates.io, which each sit in a directory of their name:
# `publish = false` gives the others an empty `publish` list.
published=$(cargo metadata --format-version 1 --no-deps --locked |
    jq -r '.packages[] | select(.publish == null) | .name')

subjects=$(git log --format=%s "$base..HEAD"; printf '%s\n' "${PR_TITLE:-}")
breaking=
if grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$subjects"; then
    breaking=1
fi

status=0
for package in $published; do
    grep -q "^$package/" <<<"$changed" || continue
    if [[ "$package" == rind && -n "$breaking" ]]; then
        echo "semver: rind is marked breaking; skipping its check"
        continue
    fi
    args=(--package "$package" --baseline-rev "$base")
    # Below 1.0, a patch release adds API, so only a break is a finding. An
    # adapter's release type comes from its version: unbumped, cargo-semver-checks
    # assumes minor, and the one that sets the version to upstream's next
    # breaking release may break. admin/adapter-api holds the rest of an
    # adapter's API to its upstream's.
    [[ "$package" != rind ]] || args+=(--release-type minor)
    cargo semver-checks "${args[@]}" || status=1
done
exit "$status"
