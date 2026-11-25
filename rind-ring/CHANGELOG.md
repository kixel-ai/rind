# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.17.4](https://github.com/kixel-ai/rind/compare/rind-ring-v0.17.3...rind-ring-v0.17.4) - 2026-11-25

### Added

- adapters build rind without ML-DSA and SLH-DSA, a build for one CPU links one tier, and CI holds rind's size in a binary ([#1008](https://github.com/kixel-ai/rind/pull/1008))
- *(site)* the README and crates link rind.kixel.ai, and a pasted link shows a social card ([#844](https://github.com/kixel-ai/rind/pull/844))
- *(site)* a page per library at /from/<library>, with a picker on the landing page ([#826](https://github.com/kixel-ai/rind/pull/826))
- [**breaking**] always wipe keys, removing the `wipe` feature ([#609](https://github.com/kixel-ai/rind/pull/609))
- rind's adapters build for wasm32, and rind-rustls's and rind-ring's tests run on wasip2 ([#762](https://github.com/kixel-ai/rind/pull/762))
- [**breaking**] per-algorithm signature modules and one API shape ([#781](https://github.com/kixel-ai/rind/pull/781))
- *(hkdf)* [**breaking**] Prk::new loads a pseudorandom key, Prk::fill writes a slice ([#758](https://github.com/kixel-ai/rind/pull/758))
- rind loads a PKCS#8 v2 key without its public key, as aws-lc-rs does ([#750](https://github.com/kixel-ai/rind/pull/750))
- *(agreement)* [**breaking**] keys keep their public key and algorithm ([#529](https://github.com/kixel-ai/rind/pull/529))

### Fixed

- *(ring)* rind-ring builds without std, as ring 0.17 does ([#960](https://github.com/kixel-ai/rind/pull/960))
- *(adapters)* match each adapter's API to its upstream's, and drop the drift list ([#783](https://github.com/kixel-ai/rind/pull/783))
- *(release)* return rind to 0.3.2 and set four adapter patch versions by hand ([#548](https://github.com/kixel-ai/rind/pull/548))
- *(rind-ring)* [**breaking**] offer exactly ring 0.17's API and features ([#516](https://github.com/kixel-ai/rind/pull/516))

### Other

- gate nightly coverage across every tier, lint feature powersets, and run wasm32-unknown-unknown tests ([#965](https://github.com/kixel-ai/rind/pull/965))
- Close existing adapter parity gaps across rind-rcgen, rind_cryptography, rind-ring, and rind-aws-lc-rs ([#961](https://github.com/kixel-ai/rind/pull/961))
- *(release)* prepare rind 0.4: hold rind-openmls, README asks for 0.4, adapters at their next patch ([#992](https://github.com/kixel-ai/rind/pull/992))
- *(adapters)* catch the mutants the adapter campaign excluded ([#792](https://github.com/kixel-ai/rind/pull/792))
- every published function the coverage report listed runs under a test, or says why not ([#862](https://github.com/kixel-ai/rind/pull/862))
- [**breaking**] digest contexts build their state in place, and hmac::Context::sign takes &mut self ([#864](https://github.com/kixel-ai/rind/pull/864))
- vendor the Wycheproof, CAVP, and CCTV vectors the tests read ([#714](https://github.com/kixel-ai/rind/pull/714))
- diff each adapter's API against its upstream's ([#698](https://github.com/kixel-ai/rind/pull/698))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))

## [0.17.3](https://github.com/kixel-ai/rind/compare/rind-ring-v0.17.2...rind-ring-v0.17.3) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.17.2](https://github.com/kixel-ai/rind/compare/rind-ring-v0.17.1...rind-ring-v0.17.2) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.17.1](https://github.com/kixel-ai/rind/compare/rind-ring-v0.17.0...rind-ring-v0.17.1) - 2026-11-07

### Added

- wiping keys on drop is opt-in, under a `wipe` feature ([#461](https://github.com/kixel-ai/rind/pull/461))

### Fixed

- *(rind-ring)* package the current workspace license ([#495](https://github.com/kixel-ai/rind/pull/495))

## [0.17.0](https://github.com/kixel-ai/rind/compare/rind-ring-v0.2.0...rind-ring-v0.17.0) - 2026-11-07

### Added

- *(rind-ring)* patch ring from kixel-ai/rind-patch, without rind's test vectors ([#456](https://github.com/kixel-ai/rind/pull/456))
- a ring patch shim replaces ring across a binary's tree ([#444](https://github.com/kixel-ai/rind/pull/444))
- [**breaking**] each adapter's version matches the upstream it adapts ([#440](https://github.com/kixel-ai/rind/pull/440))

### Other

- *(release)* ship rind as 0.2.1, not 0.3.0 ([#457](https://github.com/kixel-ai/rind/pull/457))
- test iOS in the simulator and Android under cross ([#432](https://github.com/kixel-ai/rind/pull/432))

## [0.2.0](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.12...rind-ring-v0.2.0) - 2026-11-06

### Added

- *(rsa)* load RSA keys named id-RSAES-OAEP or id-ea-rsa, as aws-lc-rs does ([#413](https://github.com/kixel-ai/rind/pull/413))
- [**breaking**] audit rind's public API, and apply its decisions, before 0.2.0 ([#383](https://github.com/kixel-ai/rind/pull/383))
- *(rind-ring)* re-export rind's CPU check as cpu ([#377](https://github.com/kixel-ai/rind/pull/377))

### Fixed

- *(adapters)* [**breaking**] return each adapter's own MissingFeature, not rind's ([#420](https://github.com/kixel-ai/rind/pull/420))

### Other

- *(readme)* show how to use rind and link the details ([#410](https://github.com/kixel-ai/rind/pull/410))
- stop wiping anything but keys, keyed state, and private-key heap scratch ([#394](https://github.com/kixel-ai/rind/pull/394))
- *(sha256)* [**breaking**] finish SHA-NI hashes in registers, and digest contexts by reference ([#352](https://github.com/kixel-ai/rind/pull/352))

## [0.1.12](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.11...rind-ring-v0.1.12) - 2026-11-05

### Fixed

- *(ed25519)* [**breaking**] refuse public keys of small order ([#298](https://github.com/kixel-ai/rind/pull/298))

### Other

- *(release)* ship rind 0.1.13 and rind-ring 0.1.12 as patch releases ([#355](https://github.com/kixel-ai/rind/pull/355))
- add rind logos and credit upstream projects ([#313](https://github.com/kixel-ai/rind/pull/313))

## [0.1.11](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.10...rind-ring-v0.1.11) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.10](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.9...rind-ring-v0.1.10) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.9](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.8...rind-ring-v0.1.9) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.8](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.7...rind-ring-v0.1.8) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.7](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.6...rind-ring-v0.1.7) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.6](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.5...rind-ring-v0.1.6) - 2026-11-02

### Fixed

- clear the nightly quality lints and verify nightly passes on main ([#212](https://github.com/kixel-ai/rind/pull/212))

## [0.1.5](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.4...rind-ring-v0.1.5) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.4](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.3...rind-ring-v0.1.4) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.3](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.2...rind-ring-v0.1.3) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.2](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.1...rind-ring-v0.1.2) - 2026-11-01

### Fixed

- fuzz the key loaders, take compressed key pair points, refuse ECDSA and RSA PKCS#8 v2 ([#166](https://github.com/kixel-ai/rind/pull/166))

## [0.1.1](https://github.com/kixel-ai/rind/compare/rind-ring-v0.1.0...rind-ring-v0.1.1) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.0](https://github.com/kixel-ai/rind/releases/tag/rind-ring-v0.1.0) - 2026-11-01

### Added

- accept 33-bit RSA public exponents ([#161](https://github.com/kixel-ai/rind/pull/161))
- load PKCS#8 keys carrying attributes ([#160](https://github.com/kixel-ai/rind/pull/160))
- *(ring)* add rind-ring, ring 0.17's API on rind ([#151](https://github.com/kixel-ai/rind/pull/151))

### Fixed

- *(ring)* [**breaking**] pbkdf2::derive returns () and panics as ring's does ([#154](https://github.com/kixel-ai/rind/pull/154))
