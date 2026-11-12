# [L] The NIST curves in rind's OpenSSL provider

## Goal

rind-openssl, the OpenSSL 3 provider that already backs X25519 and Ed25519,
also backs ECDSA and ECDH on the NIST curves where rind is faster than
OpenSSL's default provider (on an i7-8700: P-384 about 4x, and P-521), so a
Node, Python, Ruby, or nginx deployment that loads it gets them with no code
change.

## Plan

Planned by the maintainer on 2026-11-04 in m4. The provider, its documented
`openssl.cnf`, and its tests landed for X25519 and Ed25519 in
[moq-dev/rind#658](https://github.com/moq-dev/rind/pull/658); this is the rest.

- OpenSSL gives every curve one `EC` key type and one `ECDSA` and `ECDH`
  algorithm each, so a provider that registers them gets every EC key on any
  curve once the configuration prefers it. rind backs P-256, P-384, and P-521
  only, and must refuse every other curve (secp256k1, Brainpool, explicit
  parameters) rather than fall back, as `AGENTS.md` requires.
- `EVP_DigestSign` and `EVP_DigestVerify`, which TLS and X.509 use, hand the
  provider the message and a digest name, which rind's message API covers
  where the digest is the one rind pairs with the curve. `EVP_PKEY_sign` hands
  it a digest the caller made, which rind's API does not take.
- Register only what measures faster, on `openssl speed` and on Node and
  Python workloads, and test it as the X25519 and Ed25519 work does:
  differentially against the default provider, OpenSSL's `evp_test` on its
  ECDSA and ECDH data through `sh/openssl.sh`, the `openssl` fuzz target, and
  ctgrind.
- Decided 2026-11-11 (maintainer, /quest-unblock): rind-openssl always
  builds rind with `wipe`, and wipes the `OSSL_PARAM` buffers it fills with
  key material (rejected: a build flag off by default as in rind; wiping
  nothing). `AGENTS.md` leaves other scratch unwiped because safe Rust cannot
  read freed memory; that reason does not cover these buffers. They are heap
  scratch derived from a private key, which `AGENTS.md` wipes under `wipe`,
  and the provider's heap is the host process's, which C code reads. OpenSSL's
  own providers cleanse keys, so anything less is a regression for whoever
  switches. Whether `wipe` is on by default for rind itself is a separate
  question, open in [the wipe-default quest](/quest/m2/wipe-default.md).

## Waiting

- Maintainer: how the provider takes OpenSSL's `EC` key type, given that
  registering it claims every curve. (a) Only when its configuration section
  opts in with `ec = 1`, which a deployment on the NIST curves alone sets;
  keys on other curves then fail with rind's error. `EVP_DigestSign` and
  `EVP_DigestVerify` run on rind's message API, and `EVP_PKEY_sign` over a
  bare digest fails as unsupported. (b) As (a), with rind gaining ECDSA over a
  caller's digest, as aws-lc-rs's `EcdsaKeyPair::sign_digest` does, so
  `EVP_PKEY_sign` works too, at the cost of a second way to sign in rind's
  API. (c) Always, refusing other curves, which breaks secp256k1 and
  Brainpool for every deployment that loads rind. (d) Never: EC stays the
  default provider's, and this quest is deleted. Recommended: (a), which needs
  no change to rind's API, keeps the common paths fast, and fails loudly
  rather than falling back. An agent cannot pick: each option trades
  breaking some deployments' curves or calls against rind's API surface.
