# [M] armv7 P-256 as fast as the fastest source

## Goal

ECDSA and ECDH on P-256 on armv7 run at least as fast as the fastest permissively licensed source. On HACL\*'s `libcrux-p256`, nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740) has signing at 2.63x, key generation 1.43x, verification 1.31x, ECDH 1.23x, JWT ES256 2.04x to sign and 1.29x to verify, and the secp256r1 handshake 1.28x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

HACL\*'s P-256 multiplies 64-bit limbs, which a 32-bit core emulates, and its signing recomputes `k G`, which rind already computed for `r`.

[moq-dev/rind#228](https://github.com/moq-dev/rind/pull/228) moved armv7 to the shared `mid::p256` over fiat-crypto's 32-bit P-256 arithmetic (`low/generic/p256.rs` at [5c523c3](https://github.com/moq-dev/rind/commit/5c523c305a6c63451b3da4ce5dc083b630df920e)), and bench run [41399702862](https://github.com/moq-dev/rind/actions/runs/41399702862) found it slower: verification 3.50x (3.40x parsed), ECDH 3.29x, key generation 2.31x, signing 2.18x, and JWT ES256 2.36x to sign and 3.54x to verify. That PR landed without it, keeping HACL\*.

- The field multiplication loses. LLVM compiles fiat-crypto's `fiat_p256_mul` for armv7 with 171 `mrs`/`msr` instructions in 1348, saving and restoring the carry flag between its interleaved carry chains, and writing the flags stalls the core. fiat's 64-bit P-256 has 114 in 1284, P-384's 68 in 2252, and P-521's unsaturated arithmetic none: its ECDH takes 1.36 ms to P-256's 2.18 ms, despite twice the bits. Those are static counts; nothing was profiled on ARM.
- Choose the multiplication under that shared code by measuring both:
  - rind's own Montgomery multiplication and squaring, carried in 64-bit accumulators (`umaal`) rather than flags, which compiles with 4 `mrs`/`msr`. It is unverified, so check it differentially against fiat-crypto and s2n-bignum.
  - fiat-crypto's unsaturated form, as P-521 uses, generated for P-256. Whether P-256's prime suits that representation is untested.
- Keep it constant time with ctgrind coverage, and prefer a verified source unless another is more than about 10% faster, per `AGENTS.md`.
- Whatever wins may also speed armv7 P-384, whose fiat multiplication spills the flags less densely.
