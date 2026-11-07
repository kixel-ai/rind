# [L] rind has a constant-time edwards25519 group and ristretto255

## Goal

rind's crate-internal `mid` layer offers ristretto255 (RFC 9496): element encoding and decoding, the one-way map from 64 bytes, and RFC 9380's `ristretto255_XMD:SHA-512_R255MAP_RO_` hash. Under it sits a constant-time variable-base scalar multiplication on edwards25519, which rind lacks today: its Ed25519 multiplies only the base point in constant time, and verification's double-scalar multiplication is variable time. The [OPRF](/quest/m4/protocols/oprf.md), [FROST](/quest/m4/protocols/frost.md), [ECVRF](/quest/m4/protocols/ecvrf.md), and [OPAQUE](/quest/m4/protocols/opaque.md) quests build on it. No public API: it ships with its first consumer's.

## Plan

- Build from s2n-bignum's verified edwards25519 routines (`edwards25519_epadd`, `edwards25519_epdouble`, `edwards25519_pepadd`, `edwards25519_encode`) and field routines (`bignum_invsqrt_p25519`, `bignum_sqrt_p25519`), copied by `admin/parse-asm` like the rest, with a fixed-window ladder over a constant-time table select. The proofs cover each routine; state that the ladder's composition and RFC 9496's formulas are covered only by tests, and compare its speed with curve25519-dalek's.
- Scalars mod the group order reuse Ed25519's (`bignum_mod_n25519`, `bignum_madd_n25519`), plus a constant-time inversion for the OPRF client's unblinding.
- Test against RFC 9496's Appendix A vectors and the OPRF suite's vectors in RFC 9497, differentially against curve25519-dalek as a dev-dependency (aws-lc-rs has no ristretto255), and ctgrind on the scalar multiplication and decoding.
