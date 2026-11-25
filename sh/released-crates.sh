#!/usr/bin/env bash
# Print, as JSON, the crates.io releases whose tags point at the commits main
# gained since BEFORE (HEAD alone without it), grouped by that commit:
# [{"commit": SHA, "crates": [{"name": NAME, "version": VERSION}]}].
# release-plz tags `<crate>-v<version>` at the release PR's commit once it
# publishes the crate, so a rerun after a partial release, whose own
# release-plz run skips what it already published, still finds them. Crates
# the workspace never publishes, such as rind-python, are left out.
#
# Usage: sh/released-crates.sh [BEFORE]
set -euo pipefail

before=${1:-}
cd "$(git rev-parse --show-toplevel)"

range=(--max-count=1 HEAD)
[[ -z "$before" ]] || range=("$before..HEAD")
commits=$(git rev-list --first-parent "${range[@]}" | jq -R . | jq -sc .)

published=$(cargo metadata --format-version 1 --no-deps --locked |
    jq -c '[.packages[] | select(.publish != []) | .name]')

# Each annotated tag's commit is on its `^{}` line.
git ls-remote --tags origin |
    sed -n 's|^\([0-9a-f]*\)\trefs/tags/\(.*\)-v\([0-9][^^]*\)^{}$|\1 \2 \3|p' |
    jq -Rsc --argjson commits "$commits" --argjson published "$published" '
        [split("\n")[] | select(. != "") | split(" ") | {commit: .[0], name: .[1], version: .[2]}
            | select(.commit | IN($commits[])) | select(.name | IN($published[]))]
        | group_by(.commit)
        | map({commit: .[0].commit, crates: map({name, version})})'
