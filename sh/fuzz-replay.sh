#!/usr/bin/env bash
# Replay a fuzz target's corpus once on each CPU tier the host can reach by
# denying features, as build.yml's tier tests deny them, so the inputs the
# fuzzer found on the runner's own paths also check the slower ones. The AVX2
# tier also denies MOVBE, as on Sandy Bridge, to reach rind's VEX-encoded
# AES-GCM rather than Vale's, which the AVX-512 tier's denial reaches. The
# target must take `RIND_CPU_DISABLE_*`, as a build with
# `--cfg rind_cpu_disable` does. Extra arguments go to libFuzzer.
#
# Usage: sh/fuzz-replay.sh TARGET CORPUS [ARGS...]
set -euo pipefail

target=${1:?usage: sh/fuzz-replay.sh TARGET CORPUS [ARGS...]}
corpus=${2:?usage: sh/fuzz-replay.sh TARGET CORPUS [ARGS...]}
shift 2

# The features each tier denies. fuzz.yml fuzzes on x86_64 itself, so that
# list skips the runner's own paths.
case "$(uname -m)" in
    x86_64)
        tiers=(
            "sha intel"
            "avx512bw avx512f vaes"
            "adx"
            "avx2 movbe sha intel"
            "avx"
            "aes pclmulqdq avx sse41"
            "ssse3"
        )
        ;;
    aarch64)
        tiers=(
            ""
            "sha3"
            "aes pmull sha2"
        )
        ;;
    *)
        echo "error: no CPU tiers for $(uname -m)" >&2
        exit 1
        ;;
esac

for tier in "${tiers[@]}"; do
    deny=()
    for feature in $tier; do
        deny+=("RIND_CPU_DISABLE_$feature=1")
    done
    echo "==> replaying $corpus denying: ${tier:-nothing}" >&2
    env "${deny[@]}" "$target" -runs=0 "$@" "$corpus"
done
