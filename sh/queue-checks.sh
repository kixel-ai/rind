#!/usr/bin/env bash
# The path-filtered checks a merge group must also pass: each runs when the
# group's diff touches the paths that trigger its workflow on a pull request,
# so the queue and pull requests select alike. queue.yml runs the selected
# checks on GitHub-hosted runners beside the build, and the build waits for
# them, since its `Queue build / Build` is the one context main requires.
#
# Usage:
#   sh/queue-checks.sh select BASE HEAD  Print `NAME=true|false` per check,
#                                        for $GITHUB_OUTPUT.
#   sh/queue-checks.sh wait BASE HEAD    Wait for this run's jobs of each
#                                        selected check; fail unless all pass.
#
# wait reads the run's jobs through GitHub's API, with GH_TOKEN (actions: read)
# and the runner's GITHUB_* variables.
set -euo pipefail

usage="usage: sh/queue-checks.sh select|wait BASE HEAD"
[[ $# -eq 3 ]] || {
    echo "$usage" >&2
    exit 2
}
action=$1 base=$2 head=$3

cd "$(git rev-parse --show-toplevel)"

# Each check: the workflow whose pull_request paths select it, and the name of
# its calling job in queue.yml, which prefixes its jobs' names in the run.
checks=(regenerate vg)
declare -A workflow=([regenerate]=regenerate.yml [vg]=prove.yml)
declare -A job=([regenerate]=Regenerate [vg]=VG)
# The queue.yml job that runs `select` for the hosted checks.
select_job="Queue checks"

# Git's glob pathspecs match like GitHub's path filters: `*` stays within a
# directory and `**` crosses them.
touched() {
    local specs
    specs=$(yq '.on.pull_request.paths[]' ".github/workflows/${workflow[$1]}")
    [[ -n "$specs" ]] || {
        echo "error: ${workflow[$1]} lists no pull_request paths" >&2
        exit 1
    }
    mapfile -t specs <<<"$specs"
    ! git diff --quiet "$base" "$head" -- "${specs[@]/#/:(glob)}"
}

selected=()
for check in "${checks[@]}"; do
    if touched "$check"; then
        selected+=("$check")
        [[ "$action" != select ]] || echo "$check=true"
    else
        [[ "$action" != select ]] || echo "$check=false"
    fi
done

case "$action" in
    select) exit ;;
    wait) ;;
    *)
        echo "$usage" >&2
        exit 2
        ;;
esac

if [[ ${#selected[@]} -eq 0 ]]; then
    echo "queue-checks: the group touches no path-filtered check"
    exit
fi
: "${GH_TOKEN:?GH_TOKEN is required}"
echo "queue-checks: waiting for ${selected[*]}"

# A job named NAME, or NAME's jobs as `NAME / job`, each at its latest attempt:
# every attempt's jobs are read, since a rerun of only the failed jobs may leave
# a passed check's result in an earlier one. A selected check's jobs
# appear only once GitHub expands its call, after the selecting job; a check
# that never runs leaves this waiting until the build's timeout fails the group.
# shellcheck disable=SC2016 # A jq program, not a shell expansion.
verdict='
    [.jobs | group_by(.name)[] | max_by(.run_attempt)] as $latest
    | def jobs($name): [$latest[] | select(.name == $name or (.name | startswith($name + " / ")))];
    def state($js): if $js == [] then "missing"
        elif any($js[]; .status == "completed" and .conclusion != "success") then "failed"
        elif all($js[]; .status == "completed") then "passed"
        else "running" end;
    [($select, $names[]) | {name: ., state: state(jobs(.))}] as $c
    | if any($c[]; .state == "failed") then "failed: \([$c[] | select(.state == "failed") | .name] | join(", "))"
    elif all($c[1:][]; .state == "passed") then "passed"
    else "running" end'
names=$(for check in "${selected[@]}"; do echo "${job[$check]}"; done | jq -R . | jq -s .)
url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/jobs?filter=all&per_page=100"
while :; do
    state=$(curl -sS --fail-with-body --connect-timeout 5 --max-time 30 \
        -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" "$url" |
        jq -r --arg select "$select_job" --argjson names "$names" "$verdict")
    case "$state" in
        passed)
            echo "queue-checks: ${selected[*]} passed"
            exit
            ;;
        running) sleep 20 ;;
        *)
            echo "::error::queue-checks: $state"
            exit 1
            ;;
    esac
done
