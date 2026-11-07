#!/usr/bin/env bash
# Print the tag of pyrind's current version if release-plz has released it
# and PyPI does not have it yet, or nothing.
#
# Usage: sh/pyrind-unpublished.sh
# release-plz tags rind-python when a release PR lands, since it never goes
# to crates.io; this lets release.yml publish that tag to PyPI, and retry on a
# later push if publishing failed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

version=$(cargo metadata --format-version 1 --no-deps --locked |
    jq -r '.packages[] | select(.name == "rind-python") | .version')
tag="rind-python-v$version"

# Exit status 2 means no such tag: this version is unreleased.
status=0
git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null || status=$?
case "$status" in
    0) ;;
    2) exit 0 ;;
    *) exit "$status" ;;
esac

status=$(curl --silent --output /dev/null --write-out '%{http_code}' "https://pypi.org/pypi/pyrind/$version/json")
case "$status" in
    200) ;;
    404) echo "$tag" ;;
    *)
        echo "error: PyPI answered $status for pyrind $version" >&2
        exit 1
        ;;
esac
