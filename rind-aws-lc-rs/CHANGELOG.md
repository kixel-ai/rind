# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.3](https://github.com/kixel-ai/rind/compare/rind-aws-lc-rs-v1.0.2...rind-aws-lc-rs-v1.0.3) - 2026-11-25

Requires rind 0.4. This release matches aws-lc-rs 1.x's API item for item: the `cpu` module (`cpu::check` and `cpu::MissingFeature`) and the `wipe` feature, which aws-lc-rs lacks, are gone, so drop any `cpu::check()` call and `wipe` feature; keys always wipe. A change that restores upstream's API is a bug fix, released as a patch (CONTRIBUTING.md's Releases section). The other entries marked breaking change rind's API or another crate's, which this crate does not expose.

### Added

- rind-rustls and rind-aws-lc-rs build without std ([#968](https://github.com/kixel-ai/rind/pull/968))
- *(site)* the README and crates link rind.kixel.ai, and a pasted link shows a social card ([#844](https://github.com/kixel-ai/rind/pull/844))
- *(site)* a page per library at `/from/<library>`, with a picker on the landing page ([#826](https://github.com/kixel-ai/rind/pull/826))
- [**breaking**] always wipe keys, removing the `wipe` feature ([#609](https://github.com/kixel-ai/rind/pull/609))
- rind's adapters build for wasm32, and rind-rustls's and rind-ring's tests run on wasip2 ([#762](https://github.com/kixel-ai/rind/pull/762))
- [**breaking**] per-algorithm signature modules and one API shape ([#781](https://github.com/kixel-ai/rind/pull/781))
- *(hkdf)* [**breaking**] Prk::new loads a pseudorandom key, Prk::fill writes a slice ([#758](https://github.com/kixel-ai/rind/pull/758))
- *(kem)* [**breaking**] ML-KEM-512 and ML-KEM-1024 ([#606](https://github.com/kixel-ai/rind/pull/606))
- *(argon2)* rind offers Argon2id ([#634](https://github.com/kixel-ai/rind/pull/634))
- *(rind-aws-lc-rs)* ML-DSA ([#748](https://github.com/kixel-ai/rind/pull/748))
- rind loads a PKCS#8 v2 key without its public key, as aws-lc-rs does ([#750](https://github.com/kixel-ai/rind/pull/750))
- *(fips)* [**breaking**] the rind-fips module, and HKDF's extract and expand and CBC's padded encrypt return Result ([#704](https://github.com/kixel-ai/rind/pull/704))
- *(agreement)* [**breaking**] keys keep their public key and algorithm ([#529](https://github.com/kixel-ai/rind/pull/529))
- *(cipher)* [**breaking**] AES-CBC encryption takes a typed CbcIv ([#530](https://github.com/kixel-ai/rind/pull/530))

### Fixed

- *(sha512)* run no VSHA512 instruction on x86_64 ([#821](https://github.com/kixel-ai/rind/pull/821))
- *(adapters)* match each adapter's API to its upstream's, and drop the drift list ([#783](https://github.com/kixel-ai/rind/pull/783))
- *(aws-lc-rs)* keep an RSA key outside an algorithm's range and fail at verify ([#751](https://github.com/kixel-ai/rind/pull/751))
- *(aws-lc-rs)* run aws-lc-rs's own tests, and zero a refused TLS seal's output ([#679](https://github.com/kixel-ai/rind/pull/679))
- repair nightly checks and ARM AES key wiping ([#513](https://github.com/kixel-ai/rind/pull/513))
- *(aws-lc-rs)* offer exactly aws-lc-rs 1.x's API ([#522](https://github.com/kixel-ai/rind/pull/522))

### Other

- Close existing adapter parity gaps across rind-rcgen, rind_cryptography, rind-ring, and rind-aws-lc-rs ([#961](https://github.com/kixel-ai/rind/pull/961))
- *(release)* prepare rind 0.4: hold rind-openmls, README asks for 0.4, adapters at their next patch ([#992](https://github.com/kixel-ai/rind/pull/992))
- armv7 without the crypto extension runs aws-lc's NEON AES and GHASH ([#913](https://github.com/kixel-ai/rind/pull/913))
- every published function the coverage report listed runs under a test, or says why not ([#862](https://github.com/kixel-ai/rind/pull/862))
- [**breaking**] digest contexts build their state in place, and hmac::Context::sign takes &mut self ([#864](https://github.com/kixel-ai/rind/pull/864))
- *(ed25519)* x86_64 verification multiplies half-size scalars ([#768](https://github.com/kixel-ai/rind/pull/768))
- GitHub Releases per crate, docs.rs metadata, and a generated comparison in the README ([#786](https://github.com/kixel-ai/rind/pull/786))
- take upstream changes since the pins (2026-11-14 run) ([#787](https://github.com/kixel-ai/rind/pull/787))
- *(aws-lc-rs)* run aws-lc-rs's in-crate tests of its public API ([#745](https://github.com/kixel-ai/rind/pull/745))
- *(mldsa)* a key expands once ([#767](https://github.com/kixel-ai/rind/pull/767))
- vendor the Wycheproof, CAVP, and CCTV vectors the tests read ([#714](https://github.com/kixel-ai/rind/pull/714))
- diff each adapter's API against its upstream's ([#698](https://github.com/kixel-ai/rind/pull/698))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))
- ML-DSA-44, ML-DSA-65, and ML-DSA-87 ([#610](https://github.com/kixel-ai/rind/pull/610))
- fail on key-derived heap scratch freed unwiped ([#581](https://github.com/kixel-ai/rind/pull/581))

## [1.0.2](https://github.com/kixel-ai/rind/compare/rind-aws-lc-rs-v1.0.1...rind-aws-lc-rs-v1.0.2) - 2026-11-08

### Other

- updated the following local packages: rind

## [1.0.1](https://github.com/kixel-ai/rind/compare/rind-aws-lc-rs-v1.0.0...rind-aws-lc-rs-v1.0.1) - 2026-11-08

### Other

- updated the following local packages: rind

## [1.0.0](https://github.com/kixel-ai/rind/releases/tag/rind-aws-lc-rs-v1.0.0) - 2026-11-07

### Added

- *(aws-lc-rs)* rind-aws-lc-rs offers aws-lc-rs 1.x's API backed by rind ([#465](https://github.com/kixel-ai/rind/pull/465))
