# [M] armv7 P-256 as fast as the fastest source

## Goal

ECDSA and ECDH on P-256 on armv7 run at least as fast as the fastest permissively licensed source. On fiat-crypto's 32-bit arithmetic, bench run [41399702862](https://github.com/moq-dev/rind/actions/runs/41399702862) has verification at 3.50x (3.40x parsed), ECDH 3.29x, key generation 2.31x, signing 2.18x, and JWT ES256 2.36x to sign and 3.54x to verify. P-384 (1.03x) and P-521 (1.04x) verification are folded in.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Field multiplication loses first. LLVM compiles fiat-crypto's `fiat_p256_mul` for armv7 with 171 `mrs`/`msr` instructions in 1348, saving and restoring the carry flag between its interleaved carry chains. P-384's has 68 in 2252, and P-521's unsaturated arithmetic none: its ECDH takes 1.36 ms to P-256's 2.18 ms, despite twice the bits. A Montgomery multiplication that carries in 64-bit accumulators, not flags, compiles with none.
- Keep it constant time with ctgrind coverage, and prefer a verified source within 2% per `AGENTS.md`.

