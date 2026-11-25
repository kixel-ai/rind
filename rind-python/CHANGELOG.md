# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3](https://github.com/kixel-ai/rind/compare/rind-python-v0.1.2...rind-python-v0.1.3) - 2026-11-25

### Added

- [**breaking**] always wipe keys, removing the `wipe` feature ([#609](https://github.com/kixel-ai/rind/pull/609))
- [**breaking**] per-algorithm signature modules and one API shape ([#781](https://github.com/kixel-ai/rind/pull/781))
- *(hkdf)* [**breaking**] Prk::new loads a pseudorandom key, Prk::fill writes a slice ([#758](https://github.com/kixel-ai/rind/pull/758))
- *(kem)* [**breaking**] ML-KEM-512 and ML-KEM-1024 ([#606](https://github.com/kixel-ai/rind/pull/606))
- *(signature)* SLH-DSA, all twelve FIPS 205 parameter sets ([#641](https://github.com/kixel-ai/rind/pull/641))
- *(argon2)* rind offers Argon2id ([#634](https://github.com/kixel-ai/rind/pull/634))
- [**breaking**] rind needs no runtime CPU check ([#696](https://github.com/kixel-ai/rind/pull/696))
- *(fips)* [**breaking**] the rind-fips module, and HKDF's extract and expand and CBC's padded encrypt return Result ([#704](https://github.com/kixel-ai/rind/pull/704))
- *(release)* publish pyrind-cryptography to PyPI ([#618](https://github.com/kixel-ai/rind/pull/618))
- *(python)* pyrind-cryptography, pyca's hazmat API on pyrind ([#553](https://github.com/kixel-ai/rind/pull/553))
- *(agreement)* [**breaking**] keys keep their public key and algorithm ([#529](https://github.com/kixel-ai/rind/pull/529))

### Fixed

- *(python)* wipe copied secret arguments ([#959](https://github.com/kixel-ai/rind/pull/959))
- *(sha512)* run no VSHA512 instruction on x86_64 ([#821](https://github.com/kixel-ai/rind/pull/821))
- *(release)* release pyrind as 0.1.3, which pyrind-cryptography needs ([#688](https://github.com/kixel-ai/rind/pull/688))

### Other

- armv7 inverts mod an RSA modulus as fast as RustCrypto ([#1007](https://github.com/kixel-ai/rind/pull/1007))
- Close existing adapter parity gaps across rind-rcgen, rind_cryptography, rind-ring, and rind-aws-lc-rs ([#961](https://github.com/kixel-ai/rind/pull/961))
- ChaCha20-Poly1305 on x86_64 with AVX-512 runs pyca/verified-garbage's code where it is faster ([#953](https://github.com/kixel-ai/rind/pull/953))
- RSA public-key setup runs pyca/verified-garbage's R² mod n where it is faster ([#952](https://github.com/kixel-ai/rind/pull/952))
- The portable backend's SHA-2 runs aws-lc's C block functions, ported to Rust ([#944](https://github.com/kixel-ai/rind/pull/944))
- P-384 earns the ✓ from pyca/verified-garbage's proof ([#926](https://github.com/kixel-ai/rind/pull/926))
- armv7 without the crypto extension runs aws-lc's NEON AES and GHASH ([#913](https://github.com/kixel-ai/rind/pull/913))
- aarch64 cipher::ChaCha20 runs pyca/verified-garbage's code where it is faster ([#882](https://github.com/kixel-ai/rind/pull/882))
- P-384 ECDSA runs pyca/verified-garbage's code where it is faster ([#847](https://github.com/kixel-ai/rind/pull/847))
- ChaCha20-Poly1305's aarch64 SVE2 one pass imports pyca/verified-garbage's theorems ([#885](https://github.com/kixel-ai/rind/pull/885))
- *(portable)* pure-Rust ESP32-S3 SHA-256 in IRAM, rolled SHA-512 and HChaCha ([#793](https://github.com/kixel-ai/rind/pull/793))
- PBKDF2 on aarch64 earns the ✓ from pyca/verified-garbage's proof ([#890](https://github.com/kixel-ai/rind/pull/890))
- P-256's proofs compose pyca/verified-garbage's theorems ([#888](https://github.com/kixel-ai/rind/pull/888))
- X25519 and Ed25519 on AVX-512 IFMA earn the ✓ from pyca/verified-garbage's proofs ([#887](https://github.com/kixel-ai/rind/pull/887))
- every published function the coverage report listed runs under a test, or says why not ([#862](https://github.com/kixel-ai/rind/pull/862))
- [**breaking**] digest contexts build their state in place, and hmac::Context::sign takes &mut self ([#864](https://github.com/kixel-ai/rind/pull/864))
- VG's ChaCha20 axioms are stated over its vendored spec, not rind's copy ([#886](https://github.com/kixel-ai/rind/pull/886))
- ML-KEM-768 imports pyca/verified-garbage's theorems as axioms, and its proof quest moves to m4 ([#858](https://github.com/kixel-ai/rind/pull/858))
- :ChaCha20 earns the ✓ from pyca/verified-garbage's proof ([#853](https://github.com/kixel-ai/rind/pull/853))
- P-256 runs pyca/verified-garbage's public key, ECDH, and verification where it is faster ([#846](https://github.com/kixel-ai/rind/pull/846))
- Vendored verified-garbage code matches the pinned 0aa40d6c ([#877](https://github.com/kixel-ai/rind/pull/877))
- PBKDF2 on aarch64 runs pyca/verified-garbage's code where it is faster ([#850](https://github.com/kixel-ai/rind/pull/850))
- ChaCha20-Poly1305 on aarch64 runs pyca/verified-garbage's code where it is faster ([#813](https://github.com/kixel-ai/rind/pull/813))
- ML-KEM-768 runs pyca/verified-garbage's code where it is faster ([#812](https://github.com/kixel-ai/rind/pull/812))
- :ChaCha20 runs verified-garbage's AVX2 and AVX-512 VL routines on x86_64 ([#811](https://github.com/kixel-ai/rind/pull/811))
- VG's ISA models are cosimulated for the instructions rind runs ([#815](https://github.com/kixel-ai/rind/pull/815))
- *(rsa)* RSA on AVX-512 IFMA runs pyca/verified-garbage's public operation and CRT where they measured faster ([#814](https://github.com/kixel-ai/rind/pull/814))
- *(ed25519)* x86_64 verification multiplies half-size scalars ([#768](https://github.com/kixel-ai/rind/pull/768))
- take upstream changes since the pins (2026-11-14 run) ([#787](https://github.com/kixel-ai/rind/pull/787))
- vendor the Wycheproof, CAVP, and CCTV vectors the tests read ([#714](https://github.com/kixel-ai/rind/pull/714))
- release and queue from the kixel-ai org ([#711](https://github.com/kixel-ai/rind/pull/711))
- *(dart,python)* say the bindings do not wipe ([#549](https://github.com/kixel-ai/rind/pull/549))

## [0.1.2](https://github.com/kixel-ai/rind/compare/rind-python-v0.1.1...rind-python-v0.1.2) - 2026-11-08

### Other

- *(python)* test musl and armv7 wheels ([#496](https://github.com/kixel-ai/rind/pull/496))

## [0.1.1](https://github.com/kixel-ai/rind/compare/rind-python-v0.1.0...rind-python-v0.1.1) - 2026-11-08

### Other

- updated the following local packages: rind

## [0.1.0](https://github.com/kixel-ai/rind/releases/tag/rind-python-v0.1.0) - 2026-11-07

### Added

- *(python)* pyrind, rind's API for Python ([#459](https://github.com/kixel-ai/rind/pull/459))
