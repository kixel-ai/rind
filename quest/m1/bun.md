# [L] Bun runs its fastest asymmetric crypto on rind

## Goal

A PR to [Bun](https://github.com/oven-sh/bun), with numbers, moves the
operations where rind measures clearly faster than Bun's BoringSSL onto rind,
expected to be:
Ed25519 and X25519, and ECDSA and ECDH on P-384 and P-521, in WebCrypto and
node:crypto. SHA-3 in `CryptoHasher` follows in
[its own quest](/quest/m2/adoption/bun-sha3.md).

## Plan

Decided with the maintainer on 2026-11-04: a prototype PR with measurements
✅ / an issue asking first / only new APIs such as `Bun.jwt`. Posting it is
the maintainer's call; prepare the branch and the PR text, then ask.

Prioritized into m1 by the maintainer on 2026-11-05: Bun may write its own
cryptography soon, which would close the opening. Platforms first ✅, then
this, with SHA-3 split off / start now on the targets rind builds today /
keep in m2.

- Bun is Rust since its rewrite from Zig
  ([oven-sh/bun#30412](https://github.com/oven-sh/bun/pull/30412), merged in
  May 2026), so rind is a plain crate dependency. BoringSSL stays for TLS and everything
  else.
- Move an operation only where rind measures faster than Bun's own BoringSSL
  build on Bun's targets. The report has no BoringSSL column: on its i7-8700
  (`nixos2`), rind signs Ed25519 about 3x and P-384 about 9x faster than ring,
  which runs BoringSSL's code for both, but only at parity (Ed25519) and 2.1x
  (P-384) against aws-lc-rs, whose versions diverged. Measure first; drop any
  operation from the Goal that isn't clearly ahead. P-256 is near parity and
  stays unless it measures ahead.
- P-256 key generation measures ahead only if Bun's shim reads the public key
  when it is first needed, as rind now does
  ([moq-dev/rind#407](https://github.com/moq-dev/rind/pull/407)): keep the
  `EcdsaKeyPair` and read its public key on export or verification, not when
  the key is made, as the P-384 shim's `Key::ec` does today.
- The hard part is keys: node:crypto passes `EVP_PKEY` through ncrypto, so
  these key types need a representation of their own, with import and export
  (raw, PKCS#8, SPKI, JWK) matching Bun's behavior byte for byte. Bun's and
  Node's crypto tests are the bar.
- Load an Ed25519 key parsed per call, as `crypto.sign(null, data, pem)`
  does, on rind alone. The prototype's 0.93x there is a double load:
  BoringSSL derives the public key from the seed when it parses the PEM, then
  rind derives it again. Every library derives it at load, and must: signing
  with a public key that is not the seed's leaks the private key, so rind
  takes no unchecked public key. With rind loading alone, load plus sign is
  1.65x BoringSSL's on an i7-8700, since rind's load is 1.6x faster
  ([moq-dev/rind#373](https://github.com/moq-dev/rind/pull/373)).
- A native `Bun.jwt` ([oven-sh/bun#27727](https://github.com/oven-sh/bun/issues/27727))
  on rind is a natural follow-up; suggest it if this lands.
