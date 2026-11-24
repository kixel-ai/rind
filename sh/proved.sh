#!/usr/bin/env bash
# The merge queue's gate on rind's HOL Light and Lean proofs, the `proved`
# module of sh/dispatch.sh: fails unless every HOL Light target's key and the
# Lean proofs' key for this tree, as `admin/prove key` prints them, name a
# result that passed on main or on the group's pull request, PROVE_GATE_PR.
# The prove workflow saves each passed key to the Actions cache: main's runs
# to main's, and a pull request's run, which proves every key main lacks, to
# its own. So the queue spends minutes computing keys rather than the hour the
# proofs take, and a group whose proofs never passed cannot land.
#
# A forged entry needs a pull request's edit to the prove workflow, which is
# reviewed; the queue's build already runs the pull request's own code.
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

missing=()
for key in "${keys[@]}"; do
    if saved "$key" refs/heads/main; then
        echo "proved: $key passed on main"
    elif saved "$key" "refs/pull/$pr/merge"; then
        echo "proved: $key passed on #$pr"
    else
        missing+=("$key")
    fi
done
if ((${#missing[@]})); then
    echo "error: no passed result for ${missing[*]}." >&2
    echo "Let #$pr's prove run finish, rerun it if it passed but its result has since been evicted from the cache, or merge main into it if main changed the proven code since, then queue it again." >&2
    exit 1
fi
