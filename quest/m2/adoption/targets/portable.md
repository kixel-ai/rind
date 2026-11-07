# [L] One portable backend for architectures without rind assembly

## Goal

rind compiles a pure-Rust backend on any architecture that has no assembly backend, passes its Wycheproof, differential and ctgrind tests on x86_64 hosts (forced with a cfg), and is the base each architecture child enables.

## Plan

Start by listing the union of ring 0.17's and aws-lc-rs's supported architectures from their CI and build scripts, wasm excepted. Update the epic's children if the list differs from this one.

armv7 already runs portable Rust, mostly from libcrux, but it still calls aws-lc's 32-bit ARM assembly for RSA's Montgomery multiplication, SHA-384/512, ChaCha20, Poly1305, X25519 and Keccak-f. For each such primitive, choose a portable, verified source where one exists (libcrux/HACL*, fiat-crypto, s2n-bignum's specs), per AGENTS.md. Note where each one's correctness argument comes from. Make the backend selectable on x86_64 for testing only (for example `--cfg rind_portable`), so CI exercises it without qemu. armv7 keeps its assembly.

Constant time: every secret path gets ctgrind coverage on the portable backend. Benchmark it against aws-lc-rs's generic C to record the cost, but don't block on speed.
