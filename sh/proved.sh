#!/usr/bin/env bash
# The merge queue's gate on rind's HOL Light and Lean proofs, the `proved`
# module of sh/dispatch.sh: fails unless every HOL Light target's key and the
# Lean proofs' key for this tree, as `admin/prove key` prints them, name a
# result that passed on main, on the group's pull request, PROVE_GATE_PR, or
# on a pull request main landed since its newest finished prove run. The
# prove workflow saves each passed key to the Actions cache: main's runs to
# main's, and a pull request's run, which proves every key main lacks, to its
# own. So the queue spends minutes computing keys rather than the hour the
# proofs take, and a group whose proofs never passed cannot land.
#
# It trusts every entry in a pull request's cache, which any workflow run on
# that pull request can save, from any push, not only the prove workflow at
# the reviewed head. Only an author with write access, or a fork whose every
# run a maintainer approved, can run one; main's nightly, which proves
# everything and reads no cache, catches a forged pass within a day.
#
# Usage: GH_TOKEN=... PROVE_GATE_PR=N sh/proved.sh
set -euo pipefail

: "${GH_TOKEN:?"sh/proved.sh reads the Actions cache with GH_TOKEN, which needs actions: read"}"
pr=${PROVE_GATE_PR:?"sh/proved.sh needs PROVE_GATE_PR, the number of the merge group's pull request"}
[[ $pr =~ ^[0-9]+$ ]] || {
    echo "error: PROVE_GATE_PR is '$pr', not a pull request number" >&2
    exit 2
}
repo=${GITHUB_REPOSITORY:-kixel-ai/rind}

cd "$(git rev-parse --show-toplevel)"

# Each in the shell its check runs in, as the prove workflow computes it, so
# the two agree.
keys=()
for arch in x86_64 aarch64 armv7; do
    keys+=("$(nix develop .#hol-light --command admin/prove key hol-light "$arch")")
done
keys+=("$(nix develop .#prove --command admin/prove key lean)")

# Whether the cache holds `key` itself on `ref`: the API matches a key's
# prefix, and HOL Light's keys share theirs. A failed request stops the run
# rather than reading as a missing result.
saved() {
    local key=$1 ref=$2 body status=0
    body=$(curl -fsS -G -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' \
        --data-urlencode "key=$key" --data-urlencode "ref=$ref" --data-urlencode per_page=100 \
        "https://api.github.com/repos/$repo/actions/caches") || {
        echo "error: cannot list the Actions cache for $key on $ref" >&2
        exit 1
    }
    jq -e --arg key "$key" 'any(.actions_caches[]; .key == $key)' <<<"$body" >/dev/null || status=$?
    ((status <= 1)) || {
        echo "error: cannot read the Actions cache listing for $key on $ref" >&2
        exit 1
    }
    return "$status"
}

# The pull requests main landed since the commit its newest finished prove
# run checked, by their squash commits' `(#N)`. Each passed this gate, so its
# tree's keys passed on main or on its own pull request, but main's push run
# proves the keys a landing changed only within the hour after it: without
# these, the next group would be ejected until that run finished. The nightly
# bounds them to about a day of landings.
runs=$(curl -fsS -G -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' \
    --data-urlencode branch=main --data-urlencode status=completed --data-urlencode per_page=1 \
    "https://api.github.com/repos/$repo/actions/workflows/prove.yml/runs") || {
    echo "error: cannot list main's prove runs" >&2
    exit 1
}
proved_at=$(jq -er '.workflow_runs[0].head_sha' <<<"$runs") || {
    echo "error: main has no finished prove run" >&2
    exit 1
}
subjects=$(git log --first-parent --format=%s "$proved_at..HEAD")
landed=()
while read -r n; do
    [[ -z $n || $n == "$pr" ]] || landed+=("$n")
done < <(sed -nE 's/.*\(#([0-9]+)\)$/\1/p' <<<"$subjects")

missing=()
for key in "${keys[@]}"; do
    if saved "$key" refs/heads/main; then
        echo "proved: $key passed on main"
        continue
    fi
    for n in "$pr" "${landed[@]}"; do
        if saved "$key" "refs/pull/$n/merge"; then
            echo "proved: $key passed on #$n"
            continue 2
        fi
    done
    missing+=("$key")
done
if ((${#missing[@]})); then
    echo "error: no passed result for ${missing[*]}." >&2
    echo "Let #$pr's prove run finish, rerun it if it passed but its result has since been evicted from the cache, or merge main into it if main changed the proven code since, then queue it again." >&2
    exit 1
fi
