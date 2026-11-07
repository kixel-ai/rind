#!/usr/bin/env bash
# Cargo's runner for `aarch64-apple-ios-sim`: runs a test binary in the booted
# iOS simulator. simctl passes the child only the variables prefixed with
# SIMCTL_CHILD_, so this forwards the ones the tests read.
set -euo pipefail

for name in $(compgen -e); do
    case "$name" in
        RIND_* | SLOW_TESTS | RUST_*) export "SIMCTL_CHILD_$name=${!name}" ;;
    esac
done

exec xcrun simctl spawn booted "$@"
