# [S] The protocol primitives have benchmark rows

## Goal

HPKE, the VRF, and blind RSA each have rows in BENCHMARKS.md against the fastest maintained Rust implementation of the same thing, so a gap in any of them, or in the ristretto255 and hash-to-curve code under them, shows up the way one in AES-GCM would.

## Plan

Found by the 2026-11-12 audit: `rind::hpke`, `rind::vrf`, and `rind::blind_rsa` are public API on `main`, and `rind-bench/benches/` has no file for any of them. AGENTS.md asks for a benchmark against aws-lc-rs on performance-sensitive changes, and aws-lc-rs has none of these in its public API, so each landed unmeasured.

- Pick each comparison by what a user would otherwise reach for, and confirm it is maintained before timing it. The audit's starting points: hpke-rs, or rustls's aws-lc-rs HPKE suites, for HPKE, and the `blind-rsa-signatures` crate for blind RSA. For the VRF, find one that implements RFC 9381's ECVRF-EDWARDS25519-SHA512-TAI and ECVRF-P256-SHA256-TAI, and if none is maintained, give rind's rows alone and say so.
- One row per operation a protocol runs per message: HPKE setup, seal, and open at the report's packet size; VRF prove and verify per suite; blind RSA blind, sign, finalize, and verify.
- ristretto255 (`rind/src/mid/ristretto255.rs`) and hash-to-curve (`rind/src/mid/hash_to_curve.rs`) are not public, so they are timed through what calls them. When OPRF ([kixel-ai/rind#705](https://github.com/kixel-ai/rind/pull/705)) or SPAKE2+ ([kixel-ai/rind#689](https://github.com/kixel-ai/rind/pull/689)) is on `main`, it gets rows the same way, against curve25519-dalek's ristretto255 for the group work.
- The comparison libraries are dev-dependencies of rind-bench only, and `deny.toml` has to accept them.
- A gap found here is a follow-up quest, not this one's work. One lead for whoever triages them: edwards25519's variable-base multiplication (`rind/src/mid/edwards25519.rs:287`) was written for ristretto255 and has never been timed against anything.
- Every new benchmark ID needs its decision in `admin/bench-report`, which refuses one that has none.
