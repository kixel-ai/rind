# [S] Build cost is measured

## Goal

The report states, per host and per library, the cold `cargo build --release` time and stripped size of a minimal binary, the same for a rustls client on each provider (rind-rustls, aws-lc-rs, ring), and which build tools each needs.

## Plan

See the [epic](/quest/m1/benchmarks/README.md) for the settled decisions.

- The minimal binary uses AES-GCM, SHA-256, ECDSA P-256, and X25519, from whichever of those each library offers. Fixtures live in `rind-bench` or `admin/`, outside the workspace's lockfile, so each builds alone.
- Cold means an empty target directory and a warm crate download cache, so network time is excluded. Report the median of three runs.
- Build dependencies: build each in a minimal environment and record which of a C compiler, cmake, nasm, perl, and Go it needed.
- `admin/bench-report` runs this on every host alongside the speed benchmarks.
