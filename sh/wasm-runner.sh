#!/usr/bin/env bash
# Cargo's runner for wasm32-wasip2: preopen the checkout at its own absolute
# path, which the tests use to open fixtures, and run the test under wasmtime.
# `wasm_runner` in `sh/wasm.sh` points Cargo here. Cargo splits a string runner
# on whitespace, so the checkout path cannot ride in the runner itself: this
# script finds it, and passes `--dir` and its mapping as one argument each.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exec wasmtime run --dir "${root}::${root}" --env SLOW_TESTS "$@"
