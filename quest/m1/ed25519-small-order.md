# [S] Ed25519 refuses small-order public keys

## Goal

An Ed25519 public key whose point has small order, under any of its encodings, fails to load wherever rind parses one, so a key an attacker enrolls can't verify a signature on every message. Honestly generated keys are never small-order, so no valid key is refused.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. With the identity as the public key, the signature R = identity, S = 0 verifies any message; rind and aws-lc-rs both accept it today (checked locally).

- ✅ Reject small-order keys / follow aws-lc-rs and document. The maintainer chose to diverge from aws-lc-rs here, as libsodium does, because the cost is one constant-time compare and no honest key is affected.
- Compare the key's encoding against the known small-order encodings, canonical and non-canonical (libsodium's blocklist), in constant time, at every place a public key is parsed: `signature::PublicKey`, SPKI, and the key checks behind keypair loading.
- Test each blocklisted encoding, the identity-key forgery above, and that the aws-lc-rs crosscheck still agrees on every other key. Note the divergence in MIGRATING.md.
