# [M] rind offers RSA blind signatures

## Goal

A public `blind_rsa` module implements RFC 9474's four RSABSSA-SHA384 variants (PSS and PSSZERO, each Randomized and Deterministic): the client blinds a message and finalizes the server's blind signature into an ordinary RSASSA-PSS signature, the server signs blinded messages, and anyone verifies. Privacy Pass's publicly verifiable token (RFC 9578, type `0x0002`, RSABSSA-SHA384-PSS-Deterministic with 2048-bit keys), which Apple's Private Access Tokens use, runs on it. Partially blind RSA (draft-ietf-privacypass-public-metadata-issuance) is a different construction, left out until a consumer asks.

## Plan

- No new arithmetic: blinding is one public exponentiation and a multiplication mod n, signing is rind's existing CRT private operation, and unblinding needs a constant-time inverse of the blinding factor, which s2n-bignum's verified `bignum_modinv` gives. rind's private operation already checks its result against the public key, which RFC 9474 requires of the signer.
- API: one `&'static Algorithm` per variant; a client `PublicKey` (from an RSASSA-PSS `SubjectPublicKeyInfo` or components) whose `blind(msg)` returns the `BlindedMessage` to send and a `Blinding` that `finalize(self, blind_signature)` consumes into a verified `Signature`; a server `KeyPair` (PKCS#8, wiped) with `blind_sign(&BlindedMessage)`. The Randomized variants' prepared message is its own type, so a caller cannot verify against the unprepared one.
- Test against RFC 9474's Appendix A vectors (the cfrg repository's JSON is stale; `blind-rsa-signatures` carries all four variants' as JSON), Wycheproof's `rsa_pss_2048_sha384_mgf1_48_test.json` for the finalized signatures, differentially against the `blind-rsa-signatures` crate as a dev-dependency (aws-lc-rs has no blind RSA), and ctgrind on blinding, signing, and unblinding.
