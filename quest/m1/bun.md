# [S] Bun runs its fastest asymmetric crypto on rind

## Goal

A PR to [Bun](https://github.com/oven-sh/bun), with numbers, moves the
operations where rind measures clearly faster than Bun's BoringSSL onto rind,
and Bun merges it: Ed25519 and X25519, and ECDSA and ECDH on P-256, P-384,
and P-521, in WebCrypto and node:crypto, with no operation slower than on
BoringSSL. SHA-3 in `CryptoHasher`
follows in [its own quest](/quest/m2/adoption/bun-sha3.md).

## Plan

Decided with the maintainer on 2026-11-04: a prototype PR with measurements
✅ / an issue asking first / only new APIs such as `Bun.jwt`. Posting it is
the maintainer's call.

Decided by the maintainer on 2026-11-05: hold the Bun PR until the quests
under Required land, so X25519 and ECDH move in the same PR, the PEM
regression is gone, and the blog post introducing rind is out ✅ / post the
prototype now / open an issue on oven-sh/bun first.

Decided by the maintainer on 2026-11-05, later: the first Bun PR also waits
for rind 0.2.0, released after an API audit, for ECDSA over a precomputed
digest, and for Bun's key parsing on rind, so it lands the whole move at once
on a stable API ✅ / post once the first four prerequisites land.

The prototype is branch `claude/rind-asymmetric` of
[kixelated/bun](https://github.com/kixelated/bun/tree/claude/rind-asymmetric),
and its PR text, with the measurements, is in
[moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368). Measured on
2026-11-05 against Bun's own BoringSSL build:

- Moved: Ed25519 (1.3x to 1.7x end to end) and P-384 and P-521 ECDSA with
  the curve's hash (2.4x to 16x). Keys stay BoringSSL's for import and
  export; Bun caches a rind key pair built from the raw key.
- Not yet, each closed by a quest under Required: P-256 (rind signs 1.4x
  faster but generates keys at 0.6x); X25519 and ECDH, which rind's
  ephemeral-only agreement API cannot hold as WebCrypto and node:crypto keys,
  though rind leads at both; ECDSA with another hash and node's
  `createSign`/`createVerify`; and key import and export, BoringSSL's P-384
  PKCS#8 import alone taking 670 µs.
- Load an Ed25519 key parsed per call, as `crypto.sign(null, data, pem)`
  does, on rind alone. The prototype's 0.93x there is a double load:
  BoringSSL derives the public key from the seed when it parses the PEM, then
  rind derives it again. Every library derives it at load, and must: signing
  with a public key that is not the seed's leaks the private key, so rind
  takes no unchecked public key. With rind loading alone, load plus sign is
  1.65x BoringSSL's on an i7-8700, since rind's load is 1.6x faster
  ([moq-dev/rind#373](https://github.com/moq-dev/rind/pull/373)).

Once Bun merges it, a native `Bun.jwt`
([oven-sh/bun#27727](https://github.com/oven-sh/bun/issues/27727)) on rind is
a natural follow-up.

## Waiting

- Maintainer: once the prototype is extended to the Required quests' work, post it to oven-sh/bun from `kixelated/bun:claude/rind-asymmetric` with the text in moq-dev/rind#368; no agent may post to oven-sh/bun. Check for an open PR on oven-sh/bun from that branch.
- oven-sh/bun: review and merge the PR; check its state.

## Required

- [Agreement keys that can be stored and reused](/quest/m1/agreement-stored-keys.md) - X25519 and ECDH join the Bun PR
- [P-256 key generation as fast as BoringSSL](/quest/m1/p256-keygen.md) - P-256 joins the PR's other curves
- [ECDSA over a precomputed digest](/quest/m1/ecdsa-prehash.md) - other hash pairings and node's `createSign`/`createVerify` join the PR
- [Bun parses its moved keys with rind](/quest/m1/bun-key-parsing.md) - the PR's key import and export run on rind
- [rind 0.2.0 is released](/quest/m1/release-0.2.md) - the PR depends on the audited API
- [rind's launch blog post is published](/quest/m1/launch-post.md) - the post the Bun PR links
