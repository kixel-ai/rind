# [M] The adapters' API drift is fixed

## Goal

Every `drift` entry in an adapter's `[package.metadata.rind.api]` is gone: the adapter matches its upstream's API there, or the item moves to `omitted` and the README with the maintainer's agreement. `admin/adapter-api` then holds each adapter to its upstream with no exceptions beyond what rind cannot back.

## Plan

`admin/adapter-api` found these on 2026-11-12, against the versions Cargo.lock resolved then:

- rind-ring: `rsa` and the RSA items in `signature` exist without `alloc`, where ring gates them behind it; `error::KeyRejected` and `error::Unspecified` implement `std::error::Error` without `std`.
- rind-aws-lc-rs: `aead::Nonce`'s `From` impls, `aead::RandomizedNonceKey::seal_in_place_append_tag`'s lifetime, `signature::VerificationAlgorithm`'s bounds, `rand::SystemRandom`'s impls, an added `modulus_len` on `rsa::PublicKey` and `signature::RsaSubjectPublicKey`, and `rand::SecureRandom` and `rand::RandomlyConstructable` under `dev-tests-only`.
- rind-rustls: `Ticketer` exists without `std`, and the TLS 1.2 suites without `tls12`, where rustls gates them; `hpke`'s suites are `&dyn Hpke`, not `&HpkeAwsLcRs<..>` (documented in the README as deliberate, so it may belong in `omitted` instead).

Run `admin/adapter-api <adapter>` for the full signatures.
[moq-dev/rind#679](https://github.com/moq-dev/rind/pull/679) changes rind-aws-lc-rs; rebase this onto it.
