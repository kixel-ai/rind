# [L] Bun runs its fastest asymmetric crypto on rind

## Goal

A PR to [Bun](https://github.com/oven-sh/bun), with numbers, moves the
operations where rind measures clearly faster than Bun's BoringSSL onto rind,
expected to be:
Ed25519 and X25519, and ECDSA and ECDH on P-384 and P-521, in WebCrypto and
node:crypto, plus SHA-3 in `CryptoHasher`, which Bun takes from RustCrypto
today. `sha3-224`, outside aws-lc-rs's set, stays on RustCrypto.

## Plan

Decided with the maintainer on 2026-11-04: a prototype PR with measurements
✅ / an issue asking first / only new APIs such as `Bun.jwt`. Posting it is
the maintainer's call; prepare the branch and the PR text, then ask.

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
- The hard part is keys: node:crypto passes `EVP_PKEY` through ncrypto, so
  these key types need a representation of their own, with import and export
  (raw, PKCS#8, SPKI, JWK) matching Bun's behavior byte for byte. Bun's and
  Node's crypto tests are the bar.
- A native `Bun.jwt` ([oven-sh/bun#27727](https://github.com/oven-sh/bun/issues/27727))
  on rind is a natural follow-up; suggest it if this lands.

## Required

- [rind builds on every platform its packages ship](/quest/m2/adoption/platforms.md) - Bun ships Windows on aarch64 and musl
- [SHA-3](/quest/m2/adoption/webcrypto/sha3.md) - the SHA-3 digests `CryptoHasher` needs
