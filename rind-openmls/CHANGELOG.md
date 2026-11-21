# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0](https://github.com/kixel-ai/rind/releases/tag/rind-openmls-v0.6.0) - 2026-11-21

### Added

- *(site)* the README and crates link rind.kixel.ai, and a pasted link shows a social card ([#844](https://github.com/kixel-ai/rind/pull/844))
- *(site)* a page per library at /from/<library>, with a picker on the landing page ([#826](https://github.com/kixel-ai/rind/pull/826))
- rind's adapters build for wasm32, and rind-rustls's and rind-ring's tests run on wasip2 ([#762](https://github.com/kixel-ai/rind/pull/762))
- [**breaking**] per-algorithm signature modules and one API shape ([#781](https://github.com/kixel-ai/rind/pull/781))
- *(hkdf)* [**breaking**] Prk::new loads a pseudorandom key, Prk::fill writes a slice ([#758](https://github.com/kixel-ai/rind/pull/758))
- *(openmls)* rind-openmls, an OpenMLS provider on rind ([#645](https://github.com/kixel-ai/rind/pull/645))

### Other

- diff each adapter's API against its upstream's ([#698](https://github.com/kixel-ai/rind/pull/698))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))
