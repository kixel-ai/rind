# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.14.4](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.14.3...rind-rcgen-v0.14.4) - 2026-11-25

Requires rind 0.4. This release matches `rcgen::KeyPair`'s API: `KeyPair::generate()` takes no argument, so call `KeyPair::generate_for(alg)` where you passed one, and items rcgen lacks, such as `KeyPair::to_pkcs8` and the crate-level `check` and `MissingFeature`, are gone. A change that restores upstream's API is a bug fix, released as a patch (CONTRIBUTING.md's Releases section). The other entries marked breaking change rind's API or another crate's, which this crate does not expose.

### Added

- *(site)* the README and crates link rind.kixel.ai, and a pasted link shows a social card ([#844](https://github.com/kixel-ai/rind/pull/844))
- *(site)* a page per library at `/from/<library>`, with a picker on the landing page ([#826](https://github.com/kixel-ai/rind/pull/826))
- [**breaking**] always wipe keys, removing the `wipe` feature ([#609](https://github.com/kixel-ai/rind/pull/609))
- rind's adapters build for wasm32, and rind-rustls's and rind-ring's tests run on wasip2 ([#762](https://github.com/kixel-ai/rind/pull/762))
- [**breaking**] per-algorithm signature modules and one API shape ([#781](https://github.com/kixel-ai/rind/pull/781))
- rind loads a PKCS#8 v2 key without its public key, as aws-lc-rs does ([#750](https://github.com/kixel-ai/rind/pull/750))

### Fixed

- *(rcgen)* [**breaking**] KeyPair offers rcgen's KeyPair API ([#515](https://github.com/kixel-ai/rind/pull/515))
- *(rustls)* [**breaking**] rind-rustls is rustls's aws-lc-rs provider, item for item ([#521](https://github.com/kixel-ai/rind/pull/521))

### Other

- gate nightly coverage across every tier, lint feature powersets, and run wasm32-unknown-unknown tests ([#965](https://github.com/kixel-ai/rind/pull/965))
- Close existing adapter parity gaps across rind-rcgen, rind_cryptography, rind-ring, and rind-aws-lc-rs ([#961](https://github.com/kixel-ai/rind/pull/961))
- *(release)* prepare rind 0.4: hold rind-openmls, README asks for 0.4, adapters at their next patch ([#992](https://github.com/kixel-ai/rind/pull/992))
- *(adapters)* catch the mutants the adapter campaign excluded ([#792](https://github.com/kixel-ai/rind/pull/792))
- `rind::KeyPair` loads a PKCS#8 key of any signing type in one call ([#857](https://github.com/kixel-ai/rind/pull/857))
- every published function the coverage report listed runs under a test, or says why not ([#862](https://github.com/kixel-ai/rind/pull/862))
- GitHub Releases per crate, docs.rs metadata, and a generated comparison in the README ([#786](https://github.com/kixel-ai/rind/pull/786))
- diff each adapter's API against its upstream's ([#698](https://github.com/kixel-ai/rind/pull/698))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))

## [0.14.3](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.14.2...rind-rcgen-v0.14.3) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.14.2](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.14.1...rind-rcgen-v0.14.2) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.14.1](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.14.0...rind-rcgen-v0.14.1) - 2026-11-07

### Other

- updated the following local packages: rind

## [0.14.0](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.14...rind-rcgen-v0.14.0) - 2026-11-07

### Added

- *(rind-rcgen)* key_identifier() fills in key identifiers as rcgen does ([#452](https://github.com/kixel-ai/rind/pull/452))
- *(rind-rcgen)* check() and serial_number() so users need no direct rind dependency ([#451](https://github.com/kixel-ai/rind/pull/451))
- [**breaking**] each adapter's version matches the upstream it adapts ([#440](https://github.com/kixel-ai/rind/pull/440))

### Other

- *(release)* ship rind as 0.2.1, not 0.3.0 ([#457](https://github.com/kixel-ai/rind/pull/457))

## [0.1.14](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.13...rind-rcgen-v0.1.14) - 2026-11-06

### Other

- updated the following local packages: rind

## [0.1.13](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.12...rind-rcgen-v0.1.13) - 2026-11-05

### Other

- add rind logos and credit upstream projects ([#313](https://github.com/kixel-ai/rind/pull/313))

## [0.1.12](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.11...rind-rcgen-v0.1.12) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.11](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.10...rind-rcgen-v0.1.11) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.10](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.9...rind-rcgen-v0.1.10) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.9](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.8...rind-rcgen-v0.1.9) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.8](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.7...rind-rcgen-v0.1.8) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.7](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.6...rind-rcgen-v0.1.7) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.6](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.5...rind-rcgen-v0.1.6) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.5](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.4...rind-rcgen-v0.1.5) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.4](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.3...rind-rcgen-v0.1.4) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.3](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.2...rind-rcgen-v0.1.3) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.2](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.1...rind-rcgen-v0.1.2) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.1](https://github.com/kixel-ai/rind/compare/rind-rcgen-v0.1.0...rind-rcgen-v0.1.1) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.0](https://github.com/kixel-ai/rind/releases/tag/rind-rcgen-v0.1.0) - 2026-10-31

### Added

- [**breaking**] adapters mirror their upstreams and refuse unsupported CPUs at setup ([#143](https://github.com/kixel-ai/rind/pull/143))
- *(signature)* [**breaking**] one PublicKey, sign and verify constants, owned encodings, RSA key checks ([#140](https://github.com/kixel-ai/rind/pull/140))
- [**breaking**] rind::rand, deviation docs, and the aws-lc-rs API surface audit ([#94](https://github.com/kixel-ai/rind/pull/94))
- [**breaking**] signature key pairs bound to algorithm constants ([#89](https://github.com/kixel-ai/rind/pull/89))
- [**breaking**] agreement and kem modules with algorithm constants ([#79](https://github.com/kixel-ai/rind/pull/79))
- *(rcgen)* add rind-rcgen, an ECDSA P-256 SigningKey for rcgen ([#10](https://github.com/kixel-ai/rind/pull/10))

### Other

- attribute every algorithm's source and license ([#88](https://github.com/kixel-ai/rind/pull/88))
- follow the move to kixel-ai/rind ([#50](https://github.com/kixel-ai/rind/pull/50))
- *(cranelift)* build doctests with Cranelift and run the rcgen example ([#37](https://github.com/kixel-ai/rind/pull/37))
- one workspace rust-version ([#33](https://github.com/kixel-ai/rind/pull/33))
- ctgrind the adapter crates' secret paths ([#19](https://github.com/kixel-ai/rind/pull/19))
