# [M] rind hashes to P-256, P-384, and P-521 in constant time

## Goal

rind's crate-internal `mid` layer hashes bytes to a point on P-256, P-384, and P-521 (RFC 9380's `P256_XMD:SHA-256_SSWU_RO_`, `P384_XMD:SHA-384_SSWU_RO_`, `P521_XMD:SHA-512_SSWU_RO_`, and their `_NU_` encodings) and to a scalar, with `expand_message_xmd` over rind's SHA-2, for the [OPRF](/quest/m4/protocols/oprf.md) and [ECVRF](/quest/m4/protocols/ecvrf.md) quests. No public API: it ships with its first consumer's.

## Plan

- Constant time throughout: OPAQUE and the OPRF client hash the password itself. The simplified SWU map with RFC 9380's straight-line `sqrt_ratio` (Appendix F.2.1) has no data-dependent branch; build it from s2n-bignum's verified field routines that rind already copies, and state that as the correctness argument for the composition.
- Test against RFC 9380's Appendix J and K vectors (the cfrg/draft-irtf-cfrg-hash-to-curve repository's `poc/vectors` JSON); differentially against AWS-LC's `EC_hash_to_curve_p256_xmd_sha256_sswu` and `EC_hash_to_curve_p384_xmd_sha384_sswu` through the `aws-lc-sys` dev-dependency, as the XChaCha20-Poly1305 tests reach aws-lc's, and against RustCrypto's `p521` for P-521; and ctgrind on the map.
- Edwards25519's Elligator 2 map is left out: only ECVRF's ELL2 suite would use it, and the ECVRF quest records why it starts with TAI.
