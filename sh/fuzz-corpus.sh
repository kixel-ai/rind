#!/usr/bin/env bash
# Restore the newest corpus artifact NAME that a fuzz.yml run on main saved
# into DIR, for the next run to start from. An artifact, not the Actions
# cache: the weekly runs are further apart than the 7 days the cache keeps an
# entry, and other workflows' caches evict it sooner. Without one, as on the
# first run, DIR starts empty and the seeds fill it.
#
# Usage: sh/fuzz-corpus.sh NAME DIR
# Needs GH_TOKEN with `actions: read` and GITHUB_REPOSITORY.
set -euo pipefail

usage="usage: sh/fuzz-corpus.sh NAME DIR"
name=${1:?$usage}
dir=${2:?$usage}
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

mkdir -p "$dir"
run=$(gh api "repos/$GITHUB_REPOSITORY/actions/artifacts?name=$name&per_page=100" --jq '
    [.artifacts[] | select((.expired | not) and .workflow_run.head_branch == "main")]
    | sort_by(.created_at) | last | .workflow_run.id // empty')
if [[ -z "$run" ]]; then
    echo "no saved corpus $name; starting empty" >&2
    exit 0
fi
gh run download "$run" --repo "$GITHUB_REPOSITORY" --name "$name" --dir "$dir"
echo "restored $name from run $run: $(find "$dir" -type f | wc -l) inputs" >&2
