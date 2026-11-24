#!/usr/bin/env bash
# The release's gate on rind's proofs, which gate no merge: for each release
# PR's commit that `main` gained since BEFORE, as sh/release.sh walks them,
# waits for a run of the prove workflow on main whose inputs are the release
# commit's, and fails unless one passed. Such a run checked the bytes, every
# HOL Light and Lean proof main had not passed on the same inputs, and the
# cosimulation: what the release's proofs rest on. The nightly's model and
# spec tests (`vg`, `neon`, `spec-tests`) are left to `just release-check`.
# release.yml runs this before publishing.
#
# Usage: GH_TOKEN=... GH_REPO=owner/repo sh/release-proved.sh [BEFORE]
# Without BEFORE, only HEAD is considered, as in sh/release.sh. GH_TOKEN needs
# actions: write, to rerun a cancelled run, and pull-requests: read.
set -euo pipefail

before=${1:-}
: "${GH_TOKEN:?sh/release-proved.sh reads and reruns the runs of prove.yml with GH_TOKEN}"
: "${GH_REPO:?sh/release-proved.sh needs GH_REPO, the repository as owner/repo}"
cd "$(git rev-parse --show-toplevel)"

range=(--max-count=1 HEAD)
[[ -z "$before" ]] || range=("$before..HEAD")

# Polls a minute apart: up to 10 minutes for a run to appear, as GitHub starts
# the push's beside this one, then until one finishes. A cancelled run is
# rerun up to `attempts` in all: a newer push whose job checks the same key
# cancels a job pending behind another, which then saves that key.
appear=10
attempts=3
for commit in $(git rev-list --first-parent --reverse "${range[@]}"); do
    # release-plz's own test for a release (release_always = false): a pull
    # request the commit belongs to came from a `release-plz-` branch. For a
    # commit on main, GitHub lists only the merged one that landed it.
    branches=$(gh api "repos/$GH_REPO/commits/$commit/pulls" --jq '.[].head.ref')
    grep -q '^release-plz-' <<<"$branches" || continue

    # Each glob as a pathspec, from the workflow as of the commit.
    mapfile -t paths < <(git show "$commit:.github/workflows/prove.yml" | yq -r '.on.push.paths[] | ":(glob)" + .')
    ((${#paths[@]})) || {
        echo "error: prove.yml at $commit lists no push paths" >&2
        exit 1
    }
    # The commits whose prove inputs are the release's: the last up to it to
    # change them, and each after it on main that changes none. A push
    # starts prove only at its head, which may be any of them.
    proved=$(git log --first-parent -1 --format=%H "$commit" -- "${paths[@]}")
    [[ -n "$proved" ]] || {
        echo "error: no commit up to $commit changed prove's paths" >&2
        exit 1
    }
    same=("$proved")
    for next in $(git rev-list --first-parent --reverse "$proved..HEAD"); do
        git diff --quiet "$next^" "$next" -- "${paths[@]}" || break
        same+=("$next")
    done
    echo "release-proved: release $commit has the prove inputs of ${same[*]}" >&2

    polls=0
    while :; do
        # main's own runs: a push's, a nightly's, or one dispatched on main.
        runs=$(for sha in "${same[@]}"; do
            gh api "repos/$GH_REPO/actions/workflows/prove.yml/runs?head_sha=$sha&branch=main&per_page=100" \
                --jq '.workflow_runs[] | select(.event != "pull_request")'
        done | jq -s .)
        if jq -e 'any(.[]; .conclusion == "success")' <<<"$runs" >/dev/null; then
            echo "release-proved: $(jq -r 'map(select(.conclusion == "success"))[0].html_url' <<<"$runs") passed" >&2
            break
        fi
        if jq -e 'length == 0' <<<"$runs" >/dev/null; then
            ((polls < appear)) || {
                echo "error: prove has no run on main at ${same[*]} after $appear minutes" >&2
                exit 1
            }
        elif jq -e 'all(.[]; .status == "completed")' <<<"$runs" >/dev/null; then
            # Only a cancellation is retried: the checks are deterministic.
            rerun=$(jq -r --argjson attempts "$attempts" \
                'if any(.[]; .conclusion != "cancelled") then empty else
                 map(select(.run_attempt < $attempts)) | max_by(.run_number) // empty | .id end' <<<"$runs")
            if [[ -z "$rerun" ]]; then
                echo "error: prove did not pass on main at ${same[*]}, which release $commit's proofs come from:" >&2
                jq -r '.[] | "  \(.conclusion) \(.html_url)"' <<<"$runs" >&2
                exit 1
            fi
            echo "release-proved: rerunning the cancelled jobs of run $rerun" >&2
            gh api --silent -X POST "repos/$GH_REPO/actions/runs/$rerun/rerun-failed-jobs"
        fi
        polls=$((polls + 1))
        sleep 60
    done
done
