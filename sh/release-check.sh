#!/usr/bin/env bash
# Dispatch every scheduled workflow on a release PR's branch, wait for the
# runs, and record whether all passed as the `release-check` commit status on
# the head they ran, so a release-plz update to the PR needs a new run.
#
# Usage: sh/release-check.sh --check
#        sh/release-check.sh [PR]
#
# PR defaults to the open release-plz PR. Each run tests the PR's head on
# every row its schedule runs, so the result covers every crate and target.
# `--check`, which `just ci` runs, fails a scheduled workflow that a dispatch
# would not run whole.
set -euo pipefail

usage="usage: sh/release-check.sh --check | [PR]"
cd "$(git rev-parse --show-toplevel)"

# Scheduled workflows the check leaves out, and why.
declare -A skipped=(
    # Its gate compares one scheduled night on main with the one before, and
    # skips a dispatched run, which only measures.
    [bench]="measures speed; its gate runs only on main's schedule"
    # It packages rind-dart against rind from crates.io at the version the
    # release has yet to publish; dart-release.yml runs it after. build.yml's
    # dart jobs test rind-dart from source.
    [dart-libraries]="builds against the crates the release publishes"
)

# The workflow files at REV, or in the working tree when REV is empty.
rev=
workflow_files() {
    if [[ -n "$rev" ]]; then
        git ls-tree --name-only "$rev" .github/workflows/ | grep '\.yml$'
    else
        ls .github/workflows/*.yml
    fi
}
workflow() {
    if [[ -n "$rev" ]]; then
        git show "$rev:.github/workflows/$1.yml"
    else
        cat ".github/workflows/$1.yml"
    fi
}

# The scheduled workflows the check dispatches, one name per line.
scheduled() {
    local file name
    for file in $(workflow_files); do
        name=$(basename "$file" .yml)
        [[ $(workflow "$name" | yq '.on | has("schedule")') == true ]] || continue
        [[ -z "${skipped[$name]:-}" ]] || continue
        echo "$name"
    done
}

# Print why a dispatch would not run WORKFLOW whole, if it would not: no
# workflow_dispatch, a required input, or a job or step that runs only on a
# schedule or skips a dispatch.
partial() {
    local text
    text=$(workflow "$1")
    if [[ $(yq '.on | has("workflow_dispatch")' <<<"$text") != true ]]; then
        echo "takes no workflow_dispatch"
        return
    fi
    yq -r '.on.workflow_dispatch.inputs // {} | to_entries[] | select(.value.required == true) | .key' <<<"$text" |
        sed 's/^/requires the input /'
    yq -r '[.jobs[] | (.if, .steps[]?.if)] | .[] | select(. != null)' <<<"$text" |
        grep -E "event_name *(== *'schedule'|!= *'workflow_dispatch')" | sed 's/^/runs only on a schedule: /' || true
}

if [[ "${1:-}" == --check ]]; then
    [[ $# -eq 1 ]] || {
        echo "$usage" >&2
        exit 2
    }
    errors=0
    while IFS= read -r workflow; do
        problems=$(partial "$workflow")
        if [[ -n "$problems" ]]; then
            while IFS= read -r problem; do
                echo "error: $workflow.yml $problem" >&2
            done <<<"$problems"
            errors=1
        fi
    done <<<"$(scheduled)"
    exit "$errors"
fi
[[ $# -le 1 ]] || {
    echo "$usage" >&2
    exit 2
}

pr=${1:-}
if [[ -z "$pr" ]]; then
    pr=$(gh pr list --state open --json number,headRefName \
        --jq '[.[] | select(.headRefName | startswith("release-plz-")) | .number] | if length == 1 then .[0] else error("expected one open release-plz PR, found \(length)") end')
fi
info=$(gh pr view "$pr" --json state,url,headRefName,headRefOid,isCrossRepository)
url=$(jq -r .url <<<"$info")
branch=$(jq -r .headRefName <<<"$info")
head=$(jq -r .headRefOid <<<"$info")
if [[ $(jq -r .state <<<"$info") != OPEN || $(jq -r .isCrossRepository <<<"$info") != false ]]; then
    echo "error: $url must be open, from a branch of this repository" >&2
    exit 1
fi

# The workflows come from the head the runs test, not this checkout.
git fetch --quiet origin "refs/heads/$branch"
if [[ $(git rev-parse FETCH_HEAD) != "$head" ]]; then
    echo "error: $branch moved while starting; run again" >&2
    exit 1
fi
rev=$head
workflows=$(scheduled)
problems=
for workflow in $workflows; do
    problems+=$(partial "$workflow" | sed "s|^|$workflow.yml |")
done
if [[ -n "$problems" ]]; then
    echo "error: a dispatch would not run these whole:" >&2
    echo "$problems" >&2
    exit 1
fi

# Nightly, mutants mutates the last day's changes; here, every change since
# the release before: the newest tagged commit the head contains. The tags
# come from the API, since fetching them can clash with local ones.
tagged=$(gh api --paginate "repos/{owner}/{repo}/tags" --jq '.[].commit.sha' | sort -u)
previous=$(for sha in $tagged; do
    if git merge-base --is-ancestor "$sha" "$head" 2>/dev/null; then
        echo "$(git show -s --format=%ct "$sha") $sha"
    fi
done | sort -n | tail -1 | cut -d' ' -f2)
if [[ -z "$previous" ]]; then
    echo "error: $head contains no tagged release" >&2
    exit 1
fi
declare -A inputs=([mutants]="-f base=$previous")

record() {
    gh api --silent "repos/{owner}/{repo}/statuses/$head" -f context=release-check \
        -f state="$1" -f description="$2" ${3:+-f target_url="$3"}
}
trap 'status=$?; ((status == 0)) || record failure "Failed; see the run that started it"' EXIT
record pending "Dispatched the scheduled workflows"

declare -A runs=()
for workflow in $workflows; do
    # shellcheck disable=SC2086
    created=$(gh workflow run "$workflow.yml" --ref "$branch" ${inputs[$workflow]:-} 2>&1)
    run=$(grep -oE 'actions/runs/[0-9]+' <<<"$created" | head -1 | cut -d/ -f3) || true
    if [[ -z "$run" ]]; then
        echo "error: dispatching $workflow.yml named no run: $created" >&2
        exit 1
    fi
    runs[$workflow]=$run
    echo "release-check: $workflow: $(gh run view "$run" --json url --jq .url)" >&2
done

# Waits as long as the slowest run; a run on another commit, from a push
# that raced the dispatch, fails the check.
failed=()
pending=$workflows
while [[ -n "$pending" ]]; do
    sleep 300
    left=
    for workflow in $pending; do
        view=$(gh run view "${runs[$workflow]}" --json status,conclusion,headSha,url) || {
            left+=" $workflow"
            continue
        }
        if [[ $(jq -r .status <<<"$view") != completed ]]; then
            left+=" $workflow"
        elif [[ $(jq -r .headSha <<<"$view") != "$head" ]]; then
            failed+=("$workflow ran $(jq -r .headSha <<<"$view"), not $head")
        elif [[ $(jq -r .conclusion <<<"$view") != success ]]; then
            failed+=("$workflow: $(jq -r .conclusion <<<"$view") $(jq -r .url <<<"$view")")
        else
            echo "release-check: $workflow passed" >&2
        fi
    done
    pending=$left
done

if ((${#failed[@]} > 0)); then
    printf 'error: %s\n' "${failed[@]}" >&2
    exit 1
fi
build=$(gh run view "${runs[build]}" --json url --jq .url)
record success "Every scheduled workflow passed on this head" "$build"
echo "release-check: $url passed at $head" >&2
