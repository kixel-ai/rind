# [M] Argon2id in rind-dart and rind_cryptography

## Goal

rind-dart exposes rind's `argon2` module, and
[rind_cryptography](/rind-dart/cryptography/README.md) backs the
`cryptography` package's `Argon2id` with it, rather than throwing
`UnsupportedError('rind has no Argon2id')`.

## Plan

- `cryptography`'s `Argon2id` takes `memory`, `parallelism`, `iterations`,
  and `hashLength` at runtime, while `rind::argon2::Params` offers only
  RFC 9106's two recommendations and `derive` fixes the output length at
  compile time; both need a runtime form before the FFI can pass the
  package's choices through.
- Its `deriveKey` also takes an optional secret and associated data, which
  rind's `derive` does not; recommended: throw `UnsupportedError` when either
  is non-empty, as the adapter does for other unsupported parameters.
- Its tests run the package's Argon2id tests, which
  [compat/cryptography.txt](/rind-dart/cryptography/compat/cryptography.txt)
  does not skip today, so check they reach rind once it backs them.
- It needs a rind-dart release before rind_cryptography can depend on it.

## Waiting

- Maintainer: how rind takes caller-chosen Argon2id costs and output
  length. Options: make `Params` constructible from memory, passes, and
  lanes with bounds checked at construction, and `derive` fill a `&mut [u8]`
  (recommended: it is the one API both Rust and FFI callers need); or keep
  the Rust API and add an FFI-only entry point in rind-dart.
