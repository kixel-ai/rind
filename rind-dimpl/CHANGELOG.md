# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.4](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.9.3...rind-dimpl-v0.9.4) - 2026-11-25

Requires rind 0.4. This release matches dimpl's `crypto::aws_lc_rs` API: `default_provider()` returns `CryptoProvider`, not a `Result`, and `MissingFeature` is gone, so drop the `?` or `.unwrap()`. A change that restores upstream's API is a bug fix, released as a patch (CONTRIBUTING.md's Releases section). The other entries marked breaking change rind's API or another crate's, which this crate does not expose.

### Added

- *(site)* the README and crates link rind.kixel.ai, and a pasted link shows a social card ([#844](https://github.com/kixel-ai/rind/pull/844))
- *(site)* a page per library at `/from/<library>`, with a picker on the landing page ([#826](https://github.com/kixel-ai/rind/pull/826))
- rind's adapters build for wasm32, and rind-rustls's and rind-ring's tests run on wasip2 ([#762](https://github.com/kixel-ai/rind/pull/762))
- [**breaking**] per-algorithm signature modules and one API shape ([#781](https://github.com/kixel-ai/rind/pull/781))

### Fixed

- *(adapters)* [**breaking**] rind-dimpl, rind-str0m, rind-jsonwebtoken, and rind-object-store match their upstream providers ([#519](https://github.com/kixel-ai/rind/pull/519))

### Other

- *(adapters)* catch the mutants the adapter campaign excluded ([#792](https://github.com/kixel-ai/rind/pull/792))
- `rind::KeyPair` loads a PKCS#8 key of any signing type in one call ([#857](https://github.com/kixel-ai/rind/pull/857))
- every published function the coverage report listed runs under a test, or says why not ([#862](https://github.com/kixel-ai/rind/pull/862))
- diff each adapter's API against its upstream's ([#698](https://github.com/kixel-ai/rind/pull/698))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))
- Adapters offer exactly their upstream's API ([#652](https://github.com/kixel-ai/rind/pull/652))

## [0.9.3](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.9.2...rind-dimpl-v0.9.3) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.9.2](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.9.1...rind-dimpl-v0.9.2) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.9.1](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.9.0...rind-dimpl-v0.9.1) - 2026-11-07

### Other

- updated the following local packages: rind

## [0.9.0](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.2.0...rind-dimpl-v0.9.0) - 2026-11-07

### Added

- [**breaking**] each adapter's version matches the upstream it adapts ([#440](https://github.com/kixel-ai/rind/pull/440))

### Other

- *(release)* ship rind as 0.2.1, not 0.3.0 ([#457](https://github.com/kixel-ai/rind/pull/457))

## [0.2.0](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.13...rind-dimpl-v0.2.0) - 2026-11-06

### Fixed

- *(adapters)* [**breaking**] return each adapter's own MissingFeature, not rind's ([#420](https://github.com/kixel-ai/rind/pull/420))

## [0.1.13](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.12...rind-dimpl-v0.1.13) - 2026-11-05

### Other

- add rind logos and credit upstream projects ([#313](https://github.com/kixel-ai/rind/pull/313))

## [0.1.12](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.11...rind-dimpl-v0.1.12) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.11](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.10...rind-dimpl-v0.1.11) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.10](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.9...rind-dimpl-v0.1.10) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.9](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.8...rind-dimpl-v0.1.9) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.8](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.7...rind-dimpl-v0.1.8) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.7](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.6...rind-dimpl-v0.1.7) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.6](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.5...rind-dimpl-v0.1.6) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.5](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.4...rind-dimpl-v0.1.5) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.4](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.3...rind-dimpl-v0.1.4) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.3](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.2...rind-dimpl-v0.1.3) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.2](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.1...rind-dimpl-v0.1.2) - 2026-11-01

### Added

- *(x86_64)* AES and GHASH without AVX or AES-NI ([#172](https://github.com/kixel-ai/rind/pull/172))

## [0.1.1](https://github.com/kixel-ai/rind/compare/rind-dimpl-v0.1.0...rind-dimpl-v0.1.1) - 2026-11-01

### Added

- *(aarch64)* run on CPUs without the crypto extension ([#157](https://github.com/kixel-ai/rind/pull/157))

## [0.1.0](https://github.com/kixel-ai/rind/releases/tag/rind-dimpl-v0.1.0) - 2026-10-31

### Added

- [**breaking**] adapters mirror their upstreams and refuse unsupported CPUs at setup ([#143](https://github.com/kixel-ai/rind/pull/143))
- *(signature)* [**breaking**] one PublicKey, sign and verify constants, owned encodings, RSA key checks ([#140](https://github.com/kixel-ai/rind/pull/140))
- [**breaking**] aead::Key, typed tags, legacy submodules, infallible HKDF expand ([#139](https://github.com/kixel-ai/rind/pull/139))
- *(agreement,kem)* [**breaking**] PrivateKey::agree, public_key(), slice ciphertexts ([#137](https://github.com/kixel-ai/rind/pull/137))
- [**breaking**] rind::rand, deviation docs, and the aws-lc-rs API surface audit ([#94](https://github.com/kixel-ai/rind/pull/94))
- *(rustls)* prefer ChaCha20-Poly1305 without AES hardware ([#92](https://github.com/kixel-ai/rind/pull/92))
- [**breaking**] signature key pairs bound to algorithm constants ([#89](https://github.com/kixel-ai/rind/pull/89))
- *(hmac)* [**breaking**] reusable HMAC keys bound to an algorithm constant ([#83](https://github.com/kixel-ai/rind/pull/83))
- [**breaking**] agreement and kem modules with algorithm constants ([#79](https://github.com/kixel-ai/rind/pull/79))
- *(aead)* [**breaking**] AEAD and cipher keys bound to an algorithm constant ([#75](https://github.com/kixel-ai/rind/pull/75))
- [**breaking**] digest constants replace the Hash trait ([#77](https://github.com/kixel-ai/rind/pull/77))
- *(aead)* [**breaking**] AesGcm::new refuses a bad key length ([#43](https://github.com/kixel-ai/rind/pull/43))
- [**breaking**] AEADs refuse over-long messages ([#34](https://github.com/kixel-ai/rind/pull/34))
- *(dimpl)* add rind-dimpl, a dimpl CryptoProvider ([#16](https://github.com/kixel-ai/rind/pull/16))

### Other

- attribute every algorithm's source and license ([#88](https://github.com/kixel-ai/rind/pull/88))
- follow the move to kixel-ai/rind ([#50](https://github.com/kixel-ai/rind/pull/50))
- one workspace rust-version ([#33](https://github.com/kixel-ai/rind/pull/33))
