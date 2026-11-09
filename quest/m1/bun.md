# [S] Bun runs its fastest asymmetric crypto on rind

## Goal

A PR to [Bun](https://github.com/oven-sh/bun), with numbers, moves the
operations where rind measures clearly faster than Bun's BoringSSL onto rind,
and Bun merges it: Ed25519 and X25519, and ECDSA and ECDH on P-256, P-384, and
P-521, in WebCrypto and node:crypto, with no operation slower than on BoringSSL. SHA-3 in `CryptoHasher`
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
[moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368). It depends on
rind 0.3.2 from crates.io with the `wipe` feature, since BoringSSL cleanses
keys on free. Measured on 2026-11-06 against Bun's own BoringSSL build:

- Moved: Ed25519; X25519; ECDSA and ECDH on P-384 and P-521, with any SHA-2
  hash, including node's `createSign`/`createVerify`; and key import and
  export (raw, PKCS#8, SPKI, SEC1, and JWK through the raw forms) for those
  keys. rind parses an encoding only when it writes the same bytes back,
  which is what OpenSSL, BoringSSL, and Node write; any other goes to
  BoringSSL, so Bun imports and exports byte for byte as before. A key rind
  parsed or generated is rind's alone, so the Ed25519 PEM double load is gone.
- P-256 moved too, in the same PR (decision below). Measured end to end on
  2026-11-09 with rind 0.3.2: sign 1.3x to 1.6x, verify and derive 1.0x to
  1.3x, and key import and export ahead, but key generation stays behind at
  0.71x to 0.84x (WebCrypto `generateKey`, `createECDH().generateKeys`), as
  does WebCrypto's JWK private import (0.84x). The shim derives the public
  key at generation, since both halves of a pair hold it, so
  [moq-dev/rind#407](https://github.com/moq-dev/rind/pull/407)'s lazy
  derivation does not reach Bun yet.

Decided 2026-11-09 (maintainer): P-256 moves onto rind in this same Bun PR,
alongside Ed25519, X25519, P-384, and P-521: key generation, ECDSA sign and
verify with any SHA-2 hash (including node's `createSign`/`createVerify`),
ECDH, and key import and export, parsing only encodings rind writes back byte
for byte ✅ (rejected: P-256 stays on BoringSSL, the 2026-11-06 decision).

Once Bun merges it, a native `Bun.jwt`
([oven-sh/bun#27727](https://github.com/oven-sh/bun/issues/27727)) on rind is
a natural follow-up.

## Waiting

- Maintainer: P-256 key generation measures 0.71x to 0.84x of BoringSSL end to end, against the Goal's rule. Options: keep P-256 generation on rind and post anyway; route only P-256 generation to BoringSSL; or hold the Bun PR until the shim shares one lazily derived public key between a pair's halves (recommended), so #407's gain reaches Bun. Check: the PR body's P-256 generateKey rows read 1.0x or better.
- Maintainer: open the PR on oven-sh/bun as a draft from `kixelated/bun:claude/rind-asymmetric` with the text in moq-dev/rind#368; no agent may post to oven-sh/bun. Check for an open PR on oven-sh/bun from that branch.
- oven-sh/bun: review and merge the PR; check its state.
