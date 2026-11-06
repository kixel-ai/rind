#!/bin/bash
# Probe only: builds main and this branch on one runner and times them interleaved.
set -euo pipefail
git fetch -q origin main
git worktree add -q ../main origin/main
cp rind-bench/benches/short_gcm.rs ../main/rind-bench/benches/
printf '\n[[bench]]\nname = "short_gcm"\nharness = false\n' >> ../main/rind-bench/Cargo.toml
build() {
    (cd "$1" && cargo bench -q -p rind-bench --bench short_gcm --no-run --message-format=json 2>/dev/null) |
        python3 -c 'import json,sys
for l in sys.stdin:
    m=json.loads(l)
    if m.get("reason")=="compiler-artifact" and m.get("executable") and m["target"]["name"]=="short_gcm": print(m["executable"])'
}
branch_bin=$(build .)
main_bin=$(build ../main)
echo "branch: $branch_bin main: $main_bin"
mkdir -p ../out
for round in 1 2 3; do
    for tree in main branch; do
        bin=main_bin; [ $tree = branch ] && bin=branch_bin
        echo "round $round $tree"
        "${!bin}" --bench --noplot --output-format bencher > ../out/$tree-$round.txt
    done
done
python3 .github/probe/report.py ../out | tee -a "$GITHUB_STEP_SUMMARY"
