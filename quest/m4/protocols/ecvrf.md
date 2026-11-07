# [M] rind offers ECVRF

## Goal

A public `vrf` module implements RFC 9381's ECVRF: the holder of a secret key proves a pseudorandom output for an input, and anyone holding the public key verifies the proof and recovers the same output.

## Plan

- Builds on the constant-time edwards25519 scalar multiplication from the [ristretto255](/quest/m4/protocols/ristretto255.md) quest, since the prover multiplies the hashed input by its secret key, and on the NIST curves' arithmetic rind already has.
- API: one `&'static Algorithm` per suite; a wiped `SecretKey` whose `prove(alpha)` returns the `Proof` and its `Output`, and a `PublicKey` whose `verify(alpha, &proof)` returns the `Output` or an error, so a caller cannot use an output it did not verify. Public keys are validated as RFC 9381 section 5.4.5 requires.
- Test against RFC 9381's Appendix B vectors, differentially against an established implementation of each suite as a dev-dependency (aws-lc-rs has no VRF), and ctgrind on proving.

## Required

- [edwards25519 group and ristretto255](/quest/m4/protocols/ristretto255.md) - constant-time variable-base scalar multiplication
