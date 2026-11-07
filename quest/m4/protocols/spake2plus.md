# [M] rind offers SPAKE2+

## Goal

A public `spake2plus` module implements RFC 9383's SPAKE2+ for its `P256-SHA256-HKDF-SHA256-HMAC-SHA256` suite: a prover holding a password-derived secret and a verifier holding only a record derived from it agree on a shared key and confirm each other.

## Plan

- No new primitive: P-256 point arithmetic, scalars mod n, HKDF, and HMAC are rind's already, and the M and N points are RFC 9383's constants. Every operation on w0, w1, and the ephemeral scalars runs in constant time.
- API: one `&'static Suite`; a wiped `ProverSecrets` (w0, w1) and a `VerifierRecord` (w0, L), each built from the output of the caller's password stretch, as RFC 9383 leaves that step to the protocol; each side's state is a type its next step consumes, so a step cannot run twice or out of order, and neither side's key is released before the peer's confirmation checks.
- Test against RFC 9383's Appendix C vectors, differentially against an established implementation (aws-lc-rs has no SPAKE2+), and ctgrind on both sides.
