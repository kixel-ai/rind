# [M] rind offers SPAKE2+

## Goal

A public `spake2plus` module implements SPAKE2+ on P-256 with SHA-256, HKDF-SHA256, and HMAC-SHA256: a prover holding a password-derived secret and a verifier holding only a record derived from it agree on a shared key and confirm each other. It offers RFC 9383's suite, and Matter's commissioning (PASE), which follows the earlier draft-bar-cfrg-spake2plus-01: the same group operations, M and N points, and transcript, but a different key schedule.

## Plan

- No new primitive: P-256 point arithmetic, scalars mod n, HKDF, and HMAC are rind's already. Every operation on w0, w1, and the ephemeral scalars runs in constant time.
- The two key schedules differ only after hashing the transcript: Matter splits `Hash(TT)` into its confirmation and session keys, and RFC 9383 derives both from it with HKDF. Each is its own `&'static Suite`, so a Matter peer cannot be paired with an RFC 9383 one by accident.
- API: a wiped `ProverSecrets` (w0, w1) and a `VerifierRecord` (w0, L), each built from the output of the caller's password stretch (PBKDF2 for Matter), as both specifications leave that step to the protocol; each side's state is a type its next step consumes, so a step cannot run twice or out of order, and neither side gets the shared key before the peer's confirmation checks.
- Test against RFC 9383's Appendix C vectors and Matter's PASE vectors from connectedhomeip; differentially against `rs-matter`'s draft-01 implementation and `pakery-spake2plus`'s RFC 9383 one (aws-lc-rs has no SPAKE2+; BoringSSL's is internal to its TLS); and ctgrind on both sides.
- `rs-matter`'s `Crypto` trait asks its backend for raw P-256 point operations and AES-128-CCM, not for SPAKE2+, so running it on rind needs an upstream change or a `rind-rs-matter` adapter, planned once this lands.
- Decided with the maintainer on 2026-11-07: build both RFC 9383's and Matter's draft-01 key schedules, as separate suites.
