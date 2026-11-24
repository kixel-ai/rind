#!/usr/bin/env bash
# The release's gate on rind's proofs, which gate no merge: for each release
# PR's commit that `main` gained since BEFORE, as sh/release.sh walks them,
# waits for the prove workflow's run on main at the newest commit up to it
# that changed prove's paths, and fails unless one passed. That commit's
# HOL Light and Lean proofs, and the cosimulation, are the release commit's,
# since nothing they read changed after it, and its run checked each one main
# had not passed on the same inputs. release.yml runs this before publishing.
#
# Usage: GH_TOKEN=... GH_REPO=owner/repo sh/release-proved.sh [BEFORE]
# Without BEFORE, only HEAD is considered, as in sh/release.sh.
set -euo pipefail

before=${1:-}
: "${GH_TOKEN:?sh/release-proved.sh reads the runs of prove.yml with GH_TOKEN, which needs actions: read}"
: "${GH_REPO:?sh/release-proved.sh needs GH_REPO, the repository as owner/repo}"
cd "$(git rev-parse --show-toplevel)"

range=(--max-count=1 HEAD)
[[ -z "$before" ]] || range=("$before..HEAD")

# Polls of a commit's runs, a minute apart: up to 10 minutes for its push run
# to appear, as GitHub starts it beside this one, then until it finishes.
appear=10
for commit in $(git rev-list --first-parent --reverse "${range[@]}"); do
    # release-plz's own test for a release (release_always = false): a pull
    # request the commit belongs to came from a `release-plz-` branch. For a
    # commit on main, GitHub lists only the merged one that landed it.
    branches=$(gh api "repos/$GH_REPO/commits/$commit/pulls" --jq '.[].head.ref')
    grep -q '^release-plz-' <<<"$branches" || continue

    # Each glob as a pathspec, from the workflow as of the commit, so the
    # commit found is the one prove's push filter last started a run for.
    mapfile -t paths < <(git show "$commit:.github/workflows/prove.yml" | yq -r '.on.push.paths[] | ":(glob)" + .')
    ((${#paths[@]})) || {
        echo "error: prove.yml at $commit lists no push paths" >&2
        exit 1
    }
    proved=$(git log --first-parent -1 --format=%H "$commit" -- "${paths[@]}")
    [[ -n "$proved" ]] || {
        echo "error: no commit up to $commit changed prove's paths" >&2
        exit 1
    }
    echo "release-proved: release $commit takes its proofs from $proved" >&2

    polls=0
    while :; do
        # main's own runs: a push's, or a nightly that found main there.
        runs=$(gh api "repos/$GH_REPO/actions/workflows/prove.yml/runs?head_sha=$proved&branch=main&per_page=100" \
            --jq '[.workflow_runs[] | select(.event == "push" or .event == "schedule")]')
        if jq -e 'any(.[]; .conclusion == "success")' <<<"$runs" >/dev/null; then
            echo "release-proved: $(jq -r 'map(select(.conclusion == "success"))[0].html_url' <<<"$runs") passed" >&2
            break
        fi
        if jq -e 'length > 0 and all(.[]; .status == "completed")' <<<"$runs" >/dev/null; then
            echo "error: prove failed on $proved, which release $commit's proofs come from:" >&2
            jq -r '.[] | "  \(.conclusion) \(.html_url)"' <<<"$runs" >&2
            exit 1
        fi
        if jq -e 'length == 0' <<<"$runs" >/dev/null && ((polls >= appear)); then
            echo "error: prove has no push run on $proved after $appear minutes, so prove's push trigger missed it" >&2
            exit 1
        fi
        polls=$((polls + 1))
        sleep 60
    done
done
