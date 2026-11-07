# [L] Deno's WebCrypto and node:crypto run on rind

## Goal

A PR to [Deno](https://github.com/denoland/deno), with numbers, moves every
operation rind covers in `ext/crypto` (WebCrypto) and `ext/node_crypto`
(node:crypto) from RustCrypto onto rind: ECDSA and ECDH, X25519, Ed25519,
RSA, the AES modes, HMAC, HKDF, PBKDF2, and the hashes. The win is visible:
WebCrypto ES256 verification took 437 µs on RustCrypto's p256 against Node's
46 ([denoland/deno#36072](https://github.com/denoland/deno/pull/36072)).

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview:

- Deno is a marketing target even though the maintainer considers it
  deprecated: it runs the slow RustCrypto crates where rind is several times
  faster. Nothing is added to rind only for Deno; what it uses beyond the
  WebCrypto set (SLH-DSA, Argon2, KMAC, KangarooTwelve, TurboSHAKE, AES-OCB,
  X448, Ed448, ML-DSA) stays on its current crates.
- Scope: WebCrypto and node:crypto ✅ / WebCrypto only.
- Timing: after the WebCrypto epic, so one PR moves the most ✅ / now with
  today's set.
- Posting is the maintainer's call; prepare the branch, the numbers, and the
  PR text, then ask.

The branch is `rind` of
[kixelated/deno](https://github.com/kixelated/deno/tree/rind), on rind 0.2.1
from crates.io, and its PR text, with the measurements, is in
[moq-dev/rind#473](https://github.com/moq-dev/rind/pull/473). Measured on
2026-11-07 on Zen 3 against upstream Deno, and against upstream with its
RustCrypto crates at opt-level 3:

- Moved: ECDSA, ECDH, and P-384 and P-521 key generation; X25519; RSA sign,
  verify, OAEP, and key generation; AES-GCM, CBC, CTR, and KW; and in
  node:crypto the hashes (so `Hmac` too), HKDF, PBKDF2, and AES-CBC and CTR
  streams. Asymmetric operations get 6x to 35x faster and RSA private-key
  operations about 3x. AES, where per-call overhead dominates, is level on
  small buffers (0.9x to 1.2x, within the run's noise) and up to 2x faster
  on 16 KiB ones.
- Deno's WPT WebCryptoAPI run passes 1,044 more cases (truncated AES-GCM tags
  and IVs of any length) and fails none it passed; node compat and the
  crypto unit tests match upstream.
- Stays, by the Goal's "from RustCrypto": what already runs on aws-lc
  (WebCrypto Ed25519, HMAC, HKDF, PBKDF2, digests, and P-256 key
  generation, where rind trails); and what rind does not take: SHA-1 and
  SHA-3 signatures, RSA keys outside 2048 to 8192 bits or with three or more
  primes, P-224 and secp256k1, node's streaming AES-GCM and RSA, ECB, and
  3DES.

## Waiting

- Maintainer: once the launch post is up, post the PR to denoland/deno from `kixelated/deno:rind` with the text in moq-dev/rind#473; no agent may post to denoland. Deno requires disclosing AI use in the PR description, which the text does. Check for an open PR on denoland/deno from that branch.
- denoland/deno: review and merge the PR; check its state.

## Required

- [rind's launch blog post is published](/quest/m1/launch-post.md) - the post the Deno PR links
