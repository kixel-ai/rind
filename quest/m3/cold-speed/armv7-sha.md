# [S] ARMv7 without the crypto extension runs the fastest SHA-256 and SHA-1

## Goal

On armv7 without the ARMv8 crypto extension, as every ARMv7 core is, SHA-256 and SHA-1 run the fastest permissively licensed source, with NEON and without, picked from a native 32-bit A/B. `ALGORITHMS.md`, `PLATFORMS.md`, and `benchmarks/armv7-sha256.md` record the pick and its numbers.

## Plan

Planned from the 2026-11-09 speed audit. Decided with the maintainer that day:

- Scope: cold-tier speed work is planned ✅, in m3 (rejected: m2 beside the targets, m4).
- AGENTS.md's speed rule: run the fastest permissively licensed source; take a formally verified one only where it measures as fast at every size; otherwise run the fastest and plan its proof ✅ (rejected: verified code within about 10% on cold tiers only, or everywhere, as AGENTS.md said).

Evidence:

- Without the crypto extension, SHA-256 runs Graviola's portable Rust (`rind/src/low/arm/sha_armv4.rs:83`) and SHA-1 rind's (`rind/src/low/arm/sha_armv4.rs:57`).
- `admin/import-aws-lc:105` and `:113` import only `sha1_block_data_order_hw` and `sha256_block_data_order_hw` from files whose perlasm also emits NEON and integer routines, which aws-lc runs there (`sha256_block_data_order_neon` and `_nohw`, `crypto/fipsmodule/sha/sha256.c:354` at aws-lc `bab562f6ad16`).
- [moq-dev/rind#504](https://github.com/moq-dev/rind/pull/504) compared only Graviola's routine (689 ns at 64 B, 7.01 µs at 1350 B) with HACL*'s (964 ns, 10.05 µs). aws-lc-rs ran its SHA-256 instructions beside them (160 ns, 756 ns), as `benchmarks/armv7-sha256.md` says, so aws-lc's NEON and integer routines have never been timed against rind's.
- Expected gain: unmeasured. The audit's guess is 1.2 to 1.5×, from the perlasm's own header, which gives its NEON code 23% over its integer code on a Cortex-A8 and 50% on a Snapdragon S4; the measurement replaces it.

Source: aws-lc's [`sha256-armv4.pl`](https://github.com/aws/aws-lc/blob/main/crypto/fipsmodule/sha/asm/sha256-armv4.pl) and `sha1-armv4-large.pl`, Apache-2.0, Andy Polyakov's code from OpenSSL. Unproven, as Graviola's and rind's Rust are; HACL*'s verified SHA-256 already lost by 28 to 30%.

Measure first, as #504 did:

- `armv7-unknown-linux-gnueabihf` binaries run natively under `setarch linux32` on the `ubuntu-24.04-arm` runner, the crypto extension denied to rind, interleaved A, B, B, A on one runner, at 64 B and 1350 B.
- Three candidates each for SHA-256 and SHA-1: today's Rust, aws-lc's integer routine, and aws-lc's NEON one. The pick may differ with and without NEON (`HaveNeon`, `rind/src/low/arm/cpu.rs:29`), and the Rust stays wherever it is fastest.
- The runner's Neoverse-N2 in 32-bit mode is no ARMv7 core, and the header above shows NEON's lead over integer code varies by core. Record that caveat with the numbers, as `benchmarks/armv7-sha256.md` does.

Guidance:

- Import the winning routines by adding them to `admin/import-aws-lc`'s entries, never by hand.
- HMAC keys pass through both hashes, so each new routine gets its ctgrind test, with NEON and with it denied.
- The portable backend is unaffected: it runs HACL*'s SHA-256 and rind's SHA-1 in Rust.

Conflict to settle in the same PR: [armv7 runs the Rust proofs](/quest/m5/verified/armv7/prove.md) plans to prove exactly the Rust this may replace, SHA-256 and SHA-1 without the crypto extension, with Aeneas against FIPS 180-4. Under the rule above the faster source runs and its proof is planned. So for each routine that becomes assembly, move its bullet from that quest to [armv7's assembly is proven](/quest/m5/verified/armv7/assembly.md), which already holds `sha_armv4`'s other routines; a routine that stays Rust keeps its bullet.

## Related

- [armv7 runs the Rust proofs](/quest/m5/verified/armv7/prove.md) - plans to prove the Rust SHA-256 and SHA-1 this may replace
- [armv7's assembly is proven](/quest/m5/verified/armv7/assembly.md) - takes the proof of any assembly routine this imports
