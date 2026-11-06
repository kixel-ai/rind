# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.12...rind-ring-v0.2.0) - 2026-11-06

### Added

- *(rsa)* load RSA keys named id-RSAES-OAEP or id-ea-rsa, as aws-lc-rs does ([#413](https://github.com/moq-dev/rind/pull/413))
- [**breaking**] audit rind's public API, and apply its decisions, before 0.2.0 ([#383](https://github.com/moq-dev/rind/pull/383))
- *(rind-ring)* re-export rind's CPU check as cpu ([#377](https://github.com/moq-dev/rind/pull/377))

### Fixed

- *(adapters)* [**breaking**] return each adapter's own MissingFeature, not rind's ([#420](https://github.com/moq-dev/rind/pull/420))

### Other

- *(readme)* show how to use rind and link the details ([#410](https://github.com/moq-dev/rind/pull/410))
- stop wiping anything but keys, keyed state, and private-key heap scratch ([#394](https://github.com/moq-dev/rind/pull/394))
- *(sha256)* [**breaking**] finish SHA-NI hashes in registers, and digest contexts by reference ([#352](https://github.com/moq-dev/rind/pull/352))

## [0.1.12](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.11...rind-ring-v0.1.12) - 2026-11-05

### Fixed

- *(ed25519)* [**breaking**] refuse public keys of small order ([#298](https://github.com/moq-dev/rind/pull/298))

### Other

- *(release)* ship rind 0.1.13 and rind-ring 0.1.12 as patch releases ([#355](https://github.com/moq-dev/rind/pull/355))
- add rind logos and credit upstream projects ([#313](https://github.com/moq-dev/rind/pull/313))

## [0.1.11](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.10...rind-ring-v0.1.11) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.10](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.9...rind-ring-v0.1.10) - 2026-11-03

### Other

- updated the following local packages: rind

## [0.1.9](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.8...rind-ring-v0.1.9) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.8](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.7...rind-ring-v0.1.8) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.7](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.6...rind-ring-v0.1.7) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.6](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.5...rind-ring-v0.1.6) - 2026-11-02

### Fixed

- clear the nightly quality lints and verify nightly passes on main ([#212](https://github.com/moq-dev/rind/pull/212))

## [0.1.5](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.4...rind-ring-v0.1.5) - 2026-11-02

### Other

- updated the following local packages: rind

## [0.1.4](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.3...rind-ring-v0.1.4) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.3](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.2...rind-ring-v0.1.3) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.2](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.1...rind-ring-v0.1.2) - 2026-11-01

### Fixed

- fuzz the key loaders, take compressed key pair points, refuse ECDSA and RSA PKCS#8 v2 ([#166](https://github.com/moq-dev/rind/pull/166))

## [0.1.1](https://github.com/moq-dev/rind/compare/rind-ring-v0.1.0...rind-ring-v0.1.1) - 2026-11-01

### Other

- updated the following local packages: rind

## [0.1.0](https://github.com/moq-dev/rind/releases/tag/rind-ring-v0.1.0) - 2026-11-01

### Added

- accept 33-bit RSA public exponents ([#161](https://github.com/moq-dev/rind/pull/161))
- load PKCS#8 keys carrying attributes ([#160](https://github.com/moq-dev/rind/pull/160))
- *(ring)* add rind-ring, ring 0.17's API on rind ([#151](https://github.com/moq-dev/rind/pull/151))

### Fixed

- *(ring)* [**breaking**] pbkdf2::derive returns () and panics as ring's does ([#154](https://github.com/moq-dev/rind/pull/154))
