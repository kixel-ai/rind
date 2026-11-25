# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.25.3](https://github.com/kixel-ai/rind/compare/rind-str0m-v0.25.2...rind-str0m-v0.25.3) - 2026-11-25

Requires rind 0.4 and rind-dimpl 0.9.4. This release matches str0m-aws-lc-rs's API, but for what its README lists under "What rind cannot back": `default_provider()` returns `CryptoProvider`, not a `Result`, and `MissingFeature` is gone, so drop the `?` or `.unwrap()`; `dimpl_crypto_provider()` is new. A change that restores upstream's API is a bug fix, released as a patch (CONTRIBUTING.md's Releases section). The other entries marked breaking change rind's API or another crate's, which this crate does not expose.

### Added

- *(site)* the README and crates link rind.kixel.ai, and a pasted link shows a social card ([#844](https://github.com/kixel-ai/rind/pull/844))
- *(site)* a page per library at `/from/<library>`, with a picker on the landing page ([#826](https://github.com/kixel-ai/rind/pull/826))
- rind's adapters build for wasm32, and rind-rustls's and rind-ring's tests run on wasip2 ([#762](https://github.com/kixel-ai/rind/pull/762))

### Fixed

- *(adapters)* [**breaking**] rind-dimpl, rind-str0m, rind-jsonwebtoken, and rind-object-store match their upstream providers ([#519](https://github.com/kixel-ai/rind/pull/519))
- *(rcgen)* [**breaking**] KeyPair offers rcgen's KeyPair API ([#515](https://github.com/kixel-ai/rind/pull/515))

### Other

- gate nightly coverage across every tier, lint feature powersets, and run wasm32-unknown-unknown tests ([#965](https://github.com/kixel-ai/rind/pull/965))
- *(adapters)* catch the mutants the adapter campaign excluded ([#792](https://github.com/kixel-ai/rind/pull/792))
- every published function the coverage report listed runs under a test, or says why not ([#862](https://github.com/kixel-ai/rind/pull/862))
- diff each adapter's API against its upstream's ([#698](https://github.com/kixel-ai/rind/pull/698))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))

## [0.25.2](https://github.com/kixel-ai/rind/compare/rind-str0m-v0.25.1...rind-str0m-v0.25.2) - 2026-11-08

### Other

- updated the following local packages: rind, rind-dimpl, rind-rcgen

## [0.25.1](https://github.com/kixel-ai/rind/compare/rind-str0m-v0.25.0...rind-str0m-v0.25.1) - 2026-11-08

### Other

- updated the following local packages: rind, rind-dimpl, rind-rcgen

## [0.25.0](https://github.com/kixel-ai/rind/releases/tag/rind-str0m-v0.25.0) - 2026-11-07

### Added

- *(str0m)* rind-str0m, a str0m CryptoProvider on rind ([#467](https://github.com/kixel-ai/rind/pull/467))
- [**breaking**] rind::rand, deviation docs, and the aws-lc-rs API surface audit ([#94](https://github.com/kixel-ai/rind/pull/94))
- *(hmac)* [**breaking**] reusable HMAC keys bound to an algorithm constant ([#83](https://github.com/kixel-ai/rind/pull/83))
- *(aead)* [**breaking**] AEAD and cipher keys bound to an algorithm constant ([#75](https://github.com/kixel-ai/rind/pull/75))
- [**breaking**] digest constants replace the Hash trait ([#77](https://github.com/kixel-ai/rind/pull/77))
- *(aead)* [**breaking**] AesGcm::new refuses a bad key length ([#43](https://github.com/kixel-ai/rind/pull/43))
- [**breaking**] AEADs refuse over-long messages ([#34](https://github.com/kixel-ai/rind/pull/34))
- *(str0m)* add rind-str0m, a str0m CryptoProvider ([#17](https://github.com/kixel-ai/rind/pull/17))

### Other

- [**breaking**] delete rind-str0m ([#138](https://github.com/kixel-ai/rind/pull/138))
- ctgrind on armv7, fixing what it finds in the arm backend ([#36](https://github.com/kixel-ai/rind/pull/36))
- follow the move to kixel-ai/rind ([#50](https://github.com/kixel-ai/rind/pull/50))
- one workspace rust-version ([#33](https://github.com/kixel-ai/rind/pull/33))
