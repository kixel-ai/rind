# [M] rind offers Argon2id

## Goal

A public `argon2` module derives and verifies keys from passwords with Argon2id (RFC 9106), as `pbkdf2` does today, and gives [OPAQUE](/quest/m4/protocols/opaque.md) the key stretching function RFC 9807 recommends. BLAKE2b, which Argon2 is built on, stays crate-internal.

## Plan

- Sources to weigh per backend: HACL\*'s verified BLAKE2b (portable and AVX2), the RFC 9106 reference and libsodium's Argon2 (SSSE3, AVX2, and AVX-512 fill loops), and RustCrypto's `argon2`. Measure each; the memory fill dominates.
- API: parameters (memory, passes, lanes) in one struct with RFC 9106's two recommended sets as constants; `derive` into a caller's fixed-size output and `verify` comparing in constant time. Take `pbkdf2`'s shape, a `Secret` built from the password whose `derive` and `verify` take the salt and the output, rather than a free `derive` with a const length: the 2026-11-12 API audit found that difference in kixel-ai/rind#634, and [kixel-ai/rind#781](https://github.com/kixel-ai/rind/pull/781) settled that each module names the same thing the same way (maintainer, 2026-11-15). Refuse parameters below RFC 9106's minimums rather than clamp them. Allocate the memory once per call and refuse a size the platform cannot hold.
- Test against RFC 9106's vectors and the reference's KAT, and differentially against RustCrypto's `argon2` (aws-lc-rs has no Argon2).
- Decided with the maintainer on 2026-11-07: Argon2id, with the exception to `AGENTS.md`'s constant-time rule recorded there in this quest's PR (the maintainer approved that edit). ctgrind covers BLAKE2b and the data-independent first half; the data-dependent half's leak is the accepted cost of memory hardness, as RFC 9106 and RFC 9807 accept it.
