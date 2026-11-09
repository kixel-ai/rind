#!/usr/bin/env bash
# Build, lint, and test loongarch64, which runs the portable backend, as
# `just loongarch64` runs it inside the flake's `loongarch64` dev shell. The
# tests run under qemu-user.
set -euo pipefail

if [[ -z "${CARGO_TARGET_LOONGARCH64_UNKNOWN_LINUX_GNU_RUNNER:-}" ]]; then
    echo "error: run through 'just loongarch64', which enters the flake's loongarch64 dev shell" >&2
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Fail before the long cross build rather than partway through the tests.
unfetched=$(git submodule status -- thirdparty/cavp thirdparty/cctv thirdparty/wycheproof | sed -n 's/^-[0-9a-f]* //p')
if [[ -n "$unfetched" ]]; then
    echo "error: test vectors not checked out; run: git submodule update --init ${unfetched//$'\n'/ }" >&2
    exit 1
fi

# The bench and fuzz crates need C libraries built for the target.
packages=(-p rind -p rind-rustls -p rind-jsonwebtoken -p rind-object-store -p rind-rcgen -p rind-ring -p rind-aws-lc-rs -p rind-dimpl -p rind-str0m)

target=loongarch64-unknown-linux-gnu
cargo clippy "${packages[@]}" --locked --target "$target" --all-targets -- --deny warnings

# Under qemu, so optimised, but keeping the checks a debug build has.
export CARGO_PROFILE_RELEASE_DEBUG_ASSERTIONS=true
export CARGO_PROFILE_RELEASE_OVERFLOW_CHECKS=true
cargo test "${packages[@]}" --locked --release --target "$target"
cargo test -p rind --features wipe --test zeroing --locked --release --target "$target"
