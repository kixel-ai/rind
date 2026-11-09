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
  2026-11-09: every P-256 operation is at 1.0x or better. The shim derives
  a key's public key on first read, shared by a pair's halves, so
  [moq-dev/rind#407](https://github.com/moq-dev/rind/pull/407)'s lazy
  derivation reaches Bun: WebCrypto `generateKey` 4.7x to 5.0x (was 0.71x to
  0.81x), `generateKeyPairSync` 7.9x, `createECDH().generateKeys` 1.13x (was
  0.84x). WebCrypto's JWK private import reads 1.12x (was 0.84x) only with
  [moq-dev/rind#544](https://github.com/moq-dev/rind/pull/544), which checks
  a loaded key's point without an inversion, so the Bun branch needs a rind
  release carrying it.

Decided 2026-11-09 (maintainer): P-256 moves onto rind in this same Bun PR,
alongside Ed25519, X25519, P-384, and P-521: key generation, ECDSA sign and
verify with any SHA-2 hash (including node's `createSign`/`createVerify`),
ECDH, and key import and export, parsing only encodings rind writes back byte
for byte ✅ (rejected: P-256 stays on BoringSSL, the 2026-11-06 decision).

Once Bun merges it, a native `Bun.jwt`
([oven-sh/bun#27727](https://github.com/oven-sh/bun/issues/27727)) on rind is
a natural follow-up.

## Waiting

- moq-dev/rind#544 merges and ships in a rind release; then bump the Bun branch's rind to it and re-measure WebCrypto's P-256 JWK private import. Check: the PR body's P-256 rows all read 1.0x or better on the released rind.
- Maintainer: open the PR on oven-sh/bun as a draft from `kixelated/bun:claude/rind-asymmetric` with the text in moq-dev/rind#368; no agent may post to oven-sh/bun. Check for an open PR on oven-sh/bun from that branch.
- oven-sh/bun: review and merge the PR; check its state.
