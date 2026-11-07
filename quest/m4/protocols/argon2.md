# [M] rind offers Argon2id

## Goal

A public `argon2` module derives and verifies keys from passwords with Argon2id (RFC 9106), as `pbkdf2` does today, and gives [OPAQUE](/quest/m4/protocols/opaque.md) the key stretching function RFC 9807 recommends. BLAKE2b, which Argon2 is built on, stays crate-internal.

## Plan

- Sources to weigh per backend: HACL\*'s verified BLAKE2b (portable and AVX2), the RFC 9106 reference and libsodium's Argon2 (SSSE3, AVX2, and AVX-512 fill loops), and RustCrypto's `argon2`. Measure each; the memory fill dominates.
- API: parameters (memory, passes, lanes) in one struct with RFC 9106's two recommended sets as constants; `derive` into a caller's fixed-size output and `verify` comparing in constant time. Refuse parameters below RFC 9106's minimums rather than clamp them. Allocate the memory once per call and refuse a size the platform cannot hold.
- Test against RFC 9106's vectors and the reference's KAT, and differentially against RustCrypto's `argon2` (aws-lc-rs has no Argon2).

## Waiting

- Maintainer: Argon2id's second half indexes memory by password-derived data, by design, which `AGENTS.md`'s constant-time rule forbids. Options: (a) Argon2id with that rule's exception recorded in `AGENTS.md`, ctgrind covering only the data-independent first half and BLAKE2b; (b) Argon2i only, fully data-independent but weaker against GPU attackers and not what RFC 9106 or RFC 9807 recommends; (c) no Argon2, with OPAQUE taking the stretched password from the caller. Recommend (a): it is what RFC 9106, RFC 9807, OWASP, and every OPAQUE deployment use, and the leak is the accepted cost of memory hardness. Done once this quest's Plan records the choice.
