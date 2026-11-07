# [L] rind offers FROST threshold signatures

## Goal

A public `frost` module implements RFC 9591's two-round FROST for its Ed25519, ristretto255, and P-256 ciphersuites: a trusted dealer splits a signing key into shares, any threshold of participants commit and sign, and a coordinator aggregates their shares into one signature, identifying a participant whose share is invalid. A FROST(Ed25519, SHA-512) signature verifies with rind's existing `signature::verify::ED25519`.

## Plan

- Builds on [ristretto255](/quest/m4/protocols/ristretto255.md) for its ciphersuite; Ed25519 and P-256 reuse rind's s2n-bignum arithmetic. Nonce commitments are fixed-base multiplications; aggregation and share verification handle public data and may run variable time.
- API: one `&'static Suite` per ciphersuite; a wiped `SigningShare` and public `VerifyingShare`s with the group's `VerifyingKey`; `SigningNonces::commit(&share)` returns nonces and the `Commitments` to send, and `SigningNonces::sign(self, ..)` consumes them, so a nonce cannot sign twice; a `SigningPackage` binds the message to the commitments. Nonces are hedged with the share as RFC 9591 recommends, drawing the rest from the system's random source.
- Out of scope until a consumer asks: distributed key generation, which RFC 9591 leaves out; FROST(secp256k1) and its Taproot variant, which need secp256k1, an [aws-lc-rs extra on demand](/quest/m3/parity/aws-lc-extras.md); and FROST(Ed448).
- Test against RFC 9591's Appendix E vectors (from the cfrg/draft-irtf-cfrg-frost repository's JSON), differentially against the Zcash Foundation's `frost-ed25519`, `frost-ristretto255`, and `frost-p256` as dev-dependencies (aws-lc-rs has no FROST), and ctgrind on signing and dealing.

## Required

- [edwards25519 group and ristretto255](/quest/m4/protocols/ristretto255.md) - the ristretto255 group
