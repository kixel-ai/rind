#!/usr/bin/env bash
# Run, at a release PR's head on a Linux x86_64 host, every suite the scheduled
# workflows run on a Linux x86_64 runner that reaches the crates the PR versions
# or their dependents, then record the result as the `release-check` commit status
# on that head, so a later release-plz update visibly needs a re-run.
#
# Usage: sh/release-check.sh --check
#        sh/release-check.sh [PR [JOB...]]
#
# The suites come from the workflows themselves: each job of WORKFLOWS, one
# entry per row of its scheduled matrix, plus `just ci` over the selected
# crates and every `just qemu` shell the flake defines. A job built only from
# `run:` steps and the repository's setup actions runs its own steps here; the
# rest are named in `classify`, and `--check`, which `just ci` runs, fails on
# a job it cannot place, so a new Linux job joins this check or fails its PR.
# Rows this host cannot run (macOS, Windows, arm64, and those `classify`
# leaves to the runners) need the latest scheduled run of their workflow on
# `main` to have passed; the status links build's. The selection scopes
# `just ci` and skips whole jobs (see `gate` in `classify`); a job that runs
# its own steps runs them unchanged, as its workflow does.
#
# PR defaults to the open release-plz PR. Naming JOBs (globs over
# `workflow/job`, `ci`, or `qemu/SHELL`) runs only those and records nothing.
set -euo pipefail

usage="usage: sh/release-check.sh --check | [PR [JOB...]]"
cd "$(git rev-parse --show-toplevel)"
root=$PWD

workflows=(build miri x86-cpu ctgrind fuzz)
out=target/release-check

# One entry per job and row of its scheduled matrix. A matrix axis written as
# `fromJSON(<pull request list> || '<scheduled list>')` takes the scheduled
# list, and one computed at run time, such as fuzz's targets, stays a single
# null row. `${{ matrix.* }}`, `${{ env.* }}`, and `${{ github.workspace }}`
# are substituted; a step condition this cannot decide is "unsupported".
# shellcheck disable=SC2016
plan_jq='
def axis: if type == "string" then ((capture("\\|\\| *'"'"'(?<j>[^'"'"']*)'"'"' *\\) *\\}\\}$").j | fromjson) // [null]) else . end;
def hits($keys; $inc): . as $c | all($inc | to_entries[] | select(.key | IN($keys[])); $c[.key] == .value);
def rows:
  (.strategy.matrix // {}) as $m
  | if $m.exclude then error("matrix exclude is unsupported") else . end
  | ($m | del(.include) | map_values(axis)) as $axes
  | ($axes | keys) as $keys
  | (if $keys == [] then [] else reduce $keys[] as $k ([{}]; [.[] as $c | $axes[$k][] as $v | $c + {($k): $v}]) end)
  | reduce ($m.include // [])[] as $inc (.;
      if $keys != [] and any(.[]; hits($keys; $inc)) then map(if hits($keys; $inc) then . + $inc else . end) else . + [$inc] end)
  | if . == [] then [{}] else . end;
def subst($row; $env):
  if type == "string" then
    gsub("\\$\\{\\{ *matrix\\.(?<k>[A-Za-z0-9_-]+) *\\}\\}"; ($row[.k] // "") | tostring)
    | gsub("\\$\\{\\{ *env\\.(?<k>[A-Za-z0-9_]+) *\\}\\}"; $env[.k] // "")
    | gsub("\\$\\{\\{ *github\\.workspace *\\}\\}"; $ws)
  else . end;
def cond($row):
  if . == null then true
  elif type != "string" then "unsupported"
  elif test("^runner\\.arch == '"'"'[A-Z0-9]+'"'"'$") then capture("'"'"'(?<a>.*)'"'"'").a == "X64"
  elif test("^matrix\\.[A-Za-z0-9_-]+ == '"'"'[^'"'"']*'"'"'$") then
    capture("^matrix\\.(?<k>[^ ]+) == '"'"'(?<v>[^'"'"']*)'"'"'$") as $c | (($row[$c.k] // "") | tostring) == $c.v
  else "unsupported" end;
. as $wf
| ($wf.env // {} | map_values(tostring)) as $wfenv
| $wf.jobs | to_entries[] | .key as $job | .value as $j
| ($j | rows[]) as $row
| (($wfenv + ($j.env // {} | map_values(tostring))) | map_values(subst($row; $wfenv))) as $env
| ($j["runs-on"] | subst($row; {})) as $on
| {
    workflow: $name, job: $job, row: $row, runs_on: $on,
    host: (if ($on | test("^ubuntu-")) then (if ($on | test("-arm$")) then "linux-arm64" else "linux-x64" end) else "other" end),
    env: $env,
    wd: ($j.defaults.run["working-directory"] // null),
    steps: [($j.steps // [])[] | {
      name: (.name // .uses // .run),
      uses, shell,
      if: (.if | cond($row)),
      run: (.run | subst($row; $env)),
      env: ((.env // {}) | map_values(tostring | subst($row; $env))),
      wd: (.["working-directory"] // null)
    }]
  }
'

plan() {
    local wf
    for wf in "${workflows[@]}"; do
        yq -o json ".github/workflows/$wf.yml" | jq -c --arg name "$wf" --arg ws "$PWD" "$plan_jq"
    done
}

label() {
    jq -r '"\(.workflow)/\(.job)" + (if .row == {} then "" else " (" + (.row | to_entries | map("\(.key)=\(.value // "*")") | join(", ")) + ")" end)' <<<"$1"
}

# Set, for ENTRY: kind (steps, fuzz, scheduled, or skip), why, gate (the crate
# whose selection runs it; empty runs it for any), shell (the dev shell its
# rust-toolchain step stands for), and skip (step names left out, with why).
classify() {
    local entry=$1 key row
    key=$(jq -r '"\(.workflow)/\(.job)"' <<<"$entry")
    row=$(jq -c .row <<<"$entry")
    kind=steps why='' gate='' shell='' skip=''
    if [[ $(jq -r .host <<<"$entry") != linux-x64 ]]; then
        kind=scheduled why="runs on $(jq -r .runs_on <<<"$entry")"
        return
    fi
    case "$key" in
        build/changes) kind=skip why="picks a pull request's jobs" ;;
        build/build)
            if [[ $(jq -r .rustc <<<"$row") == nightly ]]; then
                kind=scheduled why="tests the newest nightly rustc, which the flake does not pin"
            else
                shell=default
            fi
            ;;
        # The shell sets the musl C compiler the skipped step installs.
        build/musl) shell=x86_64-musl skip="Install musl-gcc" ;;
        build/dart) kind=scheduled why="cross-builds Android with the runner's NDK; \`just ci\` runs rind-dart's Dart tests" ;;
        build/dart-android) kind=scheduled why="needs an Android emulator and Flutter" ;;
        build/android) kind=scheduled why="cross needs rustup and qemu's binfmt_misc handlers" ;;
        build/openmls) gate=rind-openmls ;;
        build/wasm | miri/miri | ctgrind/x86_64-sde | ctgrind/armv7-qemu | ctgrind/binsec) gate=rind ;;
        fuzz/build)
            if [[ $(jq -r .arch <<<"$row") == armv7 ]]; then
                kind=scheduled why="builds only what the arm64 runner replays"
            else
                kind=fuzz gate=rind-fuzz
            fi
            ;;
        fuzz/fuzz | fuzz/replay-x86_64-sde | fuzz/fuzz-portable) kind=fuzz gate=rind-fuzz ;;
    esac
}

# Print why ENTRY's own steps cannot run here, if they cannot.
unrunnable() {
    local entry=$1 step uses
    while IFS= read -r step; do
        uses=$(jq -r '.uses // empty' <<<"$step")
        case "$uses" in
            "" | actions/checkout@* | ./.github/actions/vectors | ./.github/actions/nix | ./.github/actions/just) ;;
            dtolnay/rust-toolchain@*) [[ -n "$shell" ]] || echo "uses $uses but names no dev shell" ;;
            *) echo "uses $uses" ;;
        esac
        if [[ $(jq -r .if <<<"$step") == unsupported ]]; then
            echo "has a step condition this cannot decide"
        fi
        if [[ $(jq -r '.shell // "bash"' <<<"$step") != bash ]]; then
            echo "runs a step in $(jq -r .shell <<<"$step")"
        fi
        if jq -e '[.run, (.env | to_entries[].value)] | any(strings | test("\\$\\{\\{"))' <<<"$step" >/dev/null; then
            echo "has an expression this cannot substitute"
        fi
    done < <(jq -c '.steps[]' <<<"$entry")
}

# Run ENTRY's own steps, as its runner would.
run_steps() {
    local entry=$1 step name run wd vars env_args
    while IFS= read -r step; do
        name=$(jq -r .name <<<"$step")
        run=$(jq -r '.run // empty' <<<"$step")
        if [[ -z "$run" || $(jq -r .if <<<"$step") == false ]]; then
            continue
        fi
        if [[ -n "$skip" && "$name" == "$skip" ]]; then
            echo "--> skipping step: $name" >&2
            continue
        fi
        # Lifting a sysctl takes root, so the host must already have it. A
        # host without the key, such as one without Ubuntu's AppArmor
        # patches, has nothing to lift.
        if [[ "$run" =~ ^sudo\ sysctl\ -w\ ([a-z0-9_.]+)=([^[:space:]]+)[[:space:]]*$ ]]; then
            local value
            if value=$(sysctl -n "${BASH_REMATCH[1]}" 2>/dev/null) && [[ "$value" != "${BASH_REMATCH[2]}" ]]; then
                echo "error: run: sudo sysctl -w ${BASH_REMATCH[1]}=${BASH_REMATCH[2]}" >&2
                return 1
            fi
            continue
        fi
        wd=$(jq -r '.wd // empty' <<<"$step")
        [[ -n "$wd" ]] || wd=$(jq -r '.wd // "."' <<<"$entry")
        vars=$(jq -r --argjson job "$(jq -c .env <<<"$entry")" '$job + .env | to_entries[] | "\(.key)=\(.value)"' <<<"$step")
        env_args=()
        [[ -z "$vars" ]] || mapfile -t env_args <<<"$vars"
        echo "--> step: $name" >&2
        if [[ "$shell" == default || -z "$shell" ]]; then
            (cd "$wd" && env "${env_args[@]}" bash --noprofile --norc -eo pipefail -c "$run")
        else
            (cd "$wd" && env "${env_args[@]}" nix develop "$root#$shell" --command bash --noprofile --norc -eo pipefail -c "$run")
        fi
    done < <(jq -c '.steps[]' <<<"$entry")
}

# The latest finished scheduled or dispatched run of WORKFLOW on main, as JSON.
last_run() {
    gh run list --workflow "$1.yml" --branch main --limit 50 \
        --json databaseId,event,status,conclusion,url,headSha \
        --jq '[.[] | select(.status == "completed" and .conclusion != "cancelled" and (.event == "schedule" or .event == "workflow_dispatch"))][0]'
}

# Fuzzing itself stays on the runners; this replays their saved corpora on the
# x86_64 tiers, under SDE, and on the portable backend, built here as fuzz.yml
# builds them.
run_fuzz() {
    local entry=$1 job row arch rustflags target bin
    job=$(jq -r .job <<<"$entry")
    row=$(jq -c .row <<<"$entry")
    case "$job" in
        build)
            arch=$(jq -r .arch <<<"$row")
            target=$(jq -r .target <<<"$row")
            rustflags=$(jq -r '.rustflags // "--cfg rind_cpu_disable"' <<<"$row")
            RUSTFLAGS=$rustflags nix develop "$PWD#fuzz" --command \
                cargo fuzz build --target "$target" --sanitizer "$(jq -r '.sanitizer // "address"' <<<"$row")"
            rm -rf "$out/fuzz/$arch"
            mkdir -p "$out/fuzz/$arch"
            for bin in $(nix develop "$PWD#fuzz" --command cargo fuzz list); do
                cp "target/$target/release/$bin" "$out/fuzz/$arch/"
            done
            return
            ;;
    esac

    if [[ -z "${corpora:-}" ]]; then
        local run
        run=$(last_run fuzz)
        [[ $(jq -r '.conclusion // empty' <<<"$run") == success ]] || {
            echo "error: the latest scheduled fuzz run on main did not pass: $(jq -r '.url // "none"' <<<"$run")" >&2
            return 1
        }
        echo "--> corpora from $(jq -r .url <<<"$run")" >&2
        rm -rf "$out/fuzz/corpus" "$out/fuzz/corpus.part"
        mkdir -p "$out/fuzz/corpus.part"
        gh run download "$(jq -r .databaseId <<<"$run")" -p 'fuzz-corpus-*' -p 'fuzz-portable-corpus-*' -D "$out/fuzz/corpus.part" || {
            echo "error: that run uploaded no corpora; start one: gh workflow run fuzz.yml --ref main" >&2
            return 1
        }
        mv "$out/fuzz/corpus.part" "$out/fuzz/corpus"
        corpora=1
    fi

    local corpus=$out/fuzz/corpus artifacts=$out/fuzz/artifacts
    for bin in "$out"/fuzz/x86_64/*; do
        target=$(basename "$bin")
        if [[ ! -d "$corpus/fuzz-corpus-$target" ]]; then
            echo "error: no corpus for $target in the latest fuzz run" >&2
            return 1
        fi
        mkdir -p "$artifacts/$target"
        local args=(-timeout=30 -rss_limit_mb=2048 -artifact_prefix="$artifacts/$target/")
        case "$job" in
            # The runner fuzzed on its own paths, which this host's may not be.
            fuzz)
                "$bin" -runs=0 "${args[@]}" "$corpus/fuzz-corpus-$target"
                sh/fuzz-replay.sh x86_64 "$bin" "$corpus/fuzz-corpus-$target" "${args[@]}"
                ;;
            replay-x86_64-sde)
                nix develop "$PWD#sde" --command sh/fuzz-replay.sh x86_64-sde "$bin" "$corpus/fuzz-corpus-$target" "${args[@]}"
                ;;
            fuzz-portable)
                if [[ ! -d "$corpus/fuzz-portable-corpus-$target" ]]; then
                    echo "error: no portable corpus for $target in the latest fuzz run" >&2
                    return 1
                fi
                "$out/fuzz/portable/$target" -runs=0 "${args[@]}" \
                    "$corpus/fuzz-portable-corpus-$target" "$corpus/fuzz-corpus-$target"
                ;;
            *)
                echo "error: no fuzz handler for $job" >&2
                return 1
                ;;
        esac
    done
}

check=
if [[ "${1:-}" == --check ]]; then
    [[ $# -eq 1 ]] || {
        echo "$usage" >&2
        exit 2
    }
    check=1
fi

if [[ -n "$check" ]]; then
    entries=$(plan)
    errors=0
    while IFS= read -r entry; do
        classify "$entry"
        name=$(label "$entry")
        if [[ "$kind" == steps ]]; then
            problems=$(unrunnable "$entry")
            if [[ -n "$problems" ]]; then
                while IFS= read -r problem; do
                    echo "error: $name $problem; place it in sh/release-check.sh's classify" >&2
                done <<<"$problems"
                errors=1
                continue
            fi
        fi
        printf '%-10s %s%s\n' "$kind" "$name" "${why:+: $why}"
    done <<<"$entries"
    exit "$errors"
fi

if [[ "$(uname -sm)" != "Linux x86_64" ]]; then
    echo "error: the release check runs on a Linux x86_64 host" >&2
    exit 1
fi
if [[ -z "${IN_RIND_DEV_SHELL:-}" ]]; then
    echo "error: run through 'just release-check', which enters the dev shell" >&2
    exit 1
fi

pr=${1:-}
filters=("${@:2}")
if [[ -z "$pr" ]]; then
    pr=$(gh pr list --state open --json number,headRefName \
        --jq '[.[] | select(.headRefName | startswith("release-plz-")) | .number] | if length == 1 then .[0] else error("expected one open release-plz PR, found \(length)") end')
fi
info=$(gh pr view "$pr" --json number,state,url,headRefOid,baseRefOid)
head=$(jq -r .headRefOid <<<"$info")
if [[ $(jq -r .state <<<"$info") != OPEN ]]; then
    echo "error: $(jq -r .url <<<"$info") is not open" >&2
    exit 1
fi
if [[ $(git rev-parse HEAD) != "$head" ]]; then
    echo "error: check out the PR's head first: gh pr checkout $pr --detach" >&2
    exit 1
fi
if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
    echo "error: the checkout has uncommitted changes" >&2
    exit 1
fi
unfetched=$(git submodule status -- thirdparty/cavp thirdparty/cctv thirdparty/wycheproof | grep -v '^ ' || true)
if [[ -n "$unfetched" ]]; then
    echo "error: test vectors not at the PR's commits; run: git submodule update --init thirdparty/cavp thirdparty/cctv thirdparty/wycheproof" >&2
    exit 1
fi
base=$(git merge-base "$(jq -r .baseRefOid <<<"$info")" HEAD) || {
    echo "error: cannot find the PR's base commit; fetch it" >&2
    exit 1
}

# The crates whose version the PR changes, then, through sh/select.sh, their
# dependents. `just ci` takes every file of each selected crate as changed.
mkdir -p "$out"
paths=$out/paths
members=$(cargo metadata --format-version 1 --no-deps --locked |
    jq -r --arg root "$PWD/" '.packages[] | [(.manifest_path | ltrimstr($root) | rtrimstr("/Cargo.toml")), .name, .version] | @tsv')
declare -A dirs=()
versioned=()
: >"$paths"
while IFS=$'\t' read -r dir name version; do
    dirs[$name]=$dir
    before=$( (git show "$base:$dir/Cargo.toml" 2>/dev/null || true) | yq -p toml -oy '.package.version // ""')
    if [[ "$before" != "$version" ]]; then
        versioned+=("$name")
        echo "$dir/Cargo.toml" >>"$paths"
    fi
done <<<"$members"
if ((${#versioned[@]} == 0)); then
    echo "error: $(jq -r .url <<<"$info") changes no crate's version" >&2
    exit 1
fi
selection=$(sh/select.sh "$paths")
declare -A selected=()
for name in "${!dirs[@]}"; do
    if grep -qxF -e --workspace -e "$name" <<<"$selection"; then
        selected[$name]=1
    fi
done
for name in "${!selected[@]}"; do
    git ls-files -- "${dirs[$name]}"
done >"$paths"
echo "release-check: $(jq -r .url <<<"$info") at $head versions ${versioned[*]}; checking ${!selected[*]}" >&2

plan=$(plan)
mapfile -t entries <<<"$plan"
problems=
for entry in "${entries[@]}"; do
    classify "$entry"
    if [[ "$kind" == steps ]]; then
        problems+=$(unrunnable "$entry" | sed "s|^|$(label "$entry") |")
    fi
done
if [[ -n "$problems" ]]; then
    echo "error: these jobs cannot run here; place them in classify:" >&2
    echo "$problems" >&2
    exit 1
fi

record() {
    gh api --silent "repos/{owner}/{repo}/statuses/$head" -f context=release-check \
        -f state="$1" -f description="$2" ${3:+-f target_url="$3"}
}

# Rows run elsewhere count only when their workflow's latest scheduled run
# passed.
declare -A elsewhere=()
for entry in "${entries[@]}"; do
    classify "$entry"
    [[ "$kind" != scheduled ]] || elsewhere[$(jq -r .workflow <<<"$entry")]=1
done
nightly=
for wf in "${!elsewhere[@]}"; do
    run=$(last_run "$wf")
    if [[ $(jq -r '.conclusion // empty' <<<"$run") != success ]]; then
        echo "error: the latest scheduled $wf run on main did not pass: $(jq -r '.url // "none"' <<<"$run"); once main is fixed, start one: gh workflow run $wf.yml --ref main" >&2
        exit 1
    fi
    echo "release-check: $wf's other rows passed in $(jq -r .url <<<"$run") at $(jq -r .headSha <<<"$run")" >&2
    [[ "$wf" != build ]] || nightly=$(jq -r .url <<<"$run")
done

full=
if ((${#filters[@]} == 0)); then
    full=1
    trap 'status=$?; ((status == 0)) || record failure "Failed on $(hostname)"' EXIT
    record pending "Running on $(hostname)"
fi

# want NAME: whether the filters name NAME.
want() {
    local filter
    ((${#filters[@]} > 0)) || return 0
    for filter in "${filters[@]}"; do
        # shellcheck disable=SC2053
        [[ "$1" == $filter ]] && return 0
    done
    return 1
}

if want ci; then
    echo "==> just ci over the selected crates" >&2
    CI_STRICT=1 sh/dispatch.sh ci --paths="$paths"
fi

for entry in "${entries[@]}"; do
    classify "$entry"
    key=$(jq -r '"\(.workflow)/\(.job)"' <<<"$entry")
    name=$(label "$entry")
    case "$kind" in
        skip | scheduled) continue ;;
    esac
    want "$key" || continue
    if [[ -n "$gate" && -z "${selected[$gate]:-}" ]]; then
        echo "==> $name: skipped, $gate not selected" >&2
        continue
    fi
    echo "==> $name" >&2
    case "$kind" in
        steps) run_steps "$entry" ;;
        fuzz) run_fuzz "$entry" ;;
    esac
done

# Every target the flake can test under qemu, beyond the qemu job's matrix.
# shellcheck disable=SC2016
qemu=$(nix eval --json "$PWD#devShells.x86_64-linux" \
    --apply 's: builtins.filter (n: s.${n} ? RIND_QEMU_TARGET) (builtins.attrNames s)' | jq -r '.[]')
[[ -n "$qemu" ]] || {
    echo "error: the flake defines no qemu shells" >&2
    exit 1
}
for shell in $qemu; do
    yq -e ".jobs.qemu.strategy.matrix.shell[] | select(. == \"$shell\")" .github/workflows/build.yml >/dev/null 2>&1 && continue
    want "qemu/$shell" || continue
    echo "==> qemu/$shell" >&2
    nix develop "$PWD#$shell" --command sh/qemu.sh
done

if [[ -n "$full" ]]; then
    record success "Passed on $(hostname) for ${#versioned[@]} versioned crates" "$nightly"
    echo "release-check: passed; recorded on $head" >&2
fi
