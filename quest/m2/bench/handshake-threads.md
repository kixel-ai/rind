# [S] TLS handshakes are measured across threads

## Goal

BENCHMARKS.md has a row for rind-rustls handshakes run on several threads at once, against rustls's aws-lc-rs provider, and a test pins how many heap allocations one rind-rustls handshake makes, so contention or an added allocation on the handshake path shows the night it lands.

## Plan

Found by the 2026-11-12 audit. Every benchmark rind has runs on one thread, and a TLS server does not. rind keeps a little state that threads share or hold one each of: a `OnceLock` naming which SHA routine this CPU runs (`rind/src/low/x86_64/sha256_mux.rs:57` and its siblings), and a thread-local count of constant-time guards (`rind/src/low/cpu.rs:121`). Nothing measures whether either costs anything under load, and a handshake's allocation count is not recorded anywhere.

- Add the threaded rows to `rind-bench/benches/rustls.rs`, beside the single-thread handshakes it has: full and resumed handshakes on as many threads as the host has cores, reported as handshakes per second for the whole machine. The single-thread row stays, and the ratio between them is what to read.
- Count allocations with a counting global allocator in a rind-rustls test, for one full handshake per key type, and assert the count equals what it measures on the day. The number is whatever it is; the test exists so a change to it is seen and explained, and its failure message says to update the number if the change was meant.
- Count the aws-lc-rs provider's the same way once, for the report's text, not as a test.
- A gap or a surprising count found here is a follow-up quest.
- Every new benchmark ID needs its decision in `admin/bench-report`.
