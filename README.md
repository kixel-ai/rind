<h1 align="center">rind</h1>
<img width="40%" align="right" src="https://raw.githubusercontent.com/moq-dev/rind/main/admin/logo.png" alt="rind: a curled strip of spiky green graviola peel shaped like a lowercase r">

> **rind** distills great cryptography into a **pure-Rust** library for
> [rustls](https://github.com/rustls/rustls) and
> [MoQ](https://github.com/moq-dev/moq).

rind began as a fork of [Graviola] by Joe Birr-Pixton, and no longer tracks
it. Its goal is to close the gap between C-free builds and the algorithm
coverage, compatibility, and performance MoQ needs, by bringing together
work from Graviola, [AWS-LC][aws-lc], and other excellent projects. The plan
lives in [`quest/`][quests]. Coming from ring or [aws-lc-rs]?
[MIGRATING.md][migrating] maps their API to rind's, and [rind-ring][] offers
ring's API as is.

*High quality*: rind incorporates assembler routines
from the [s2n-bignum] project.  These have been formally proven
to correctly implement the desired mathematical operation.

*Fast*: rind beats or is competitive with other cryptography
libraries for Rust.  `cargo bench` compares it with aws-lc-rs, *ring*,
RustCrypto, Graviola, libcrux, and, with the `__bench_openssl` feature,
OpenSSL.

*Easy and fast to build*: no C compiler, assembler or other tooling
needed: just the Rust compiler.  Compiles in seconds.

## Built on great work

**[Graviola] is an outstanding project.** Joe Birr-Pixton and its
contributors built a fast, carefully designed cryptography library with
a refreshingly simple Rust-only build. rind owes Graviola its starting
point, much of its code, and the example it follows. If Graviola covers
your needs, please give it a look and support its authors.

**[aws-lc-rs] is excellent, too.** It is the library we would use if we did
not need to build without C. AWS-LC supplies many of rind's implementations;
aws-lc-rs is our reference for behavior, differential tests, and performance.
Its authors' engineering and care set a standard rind works to meet.

rind builds on cryptography written by people much smarter than us. Its
contribution is to distill and integrate their work for MoQ's needs. The
credit for the underlying algorithms, implementations, and proofs belongs
to their authors, including [s2n-bignum], [HACL\*], [libcrux], [fiat-crypto],
and the other projects listed under [Sources](#sources).

The rind logo is a tribute to [Graviola's fruit illustration][graviola-logo],
reimagined as a curled strip of its protective rind. A [wordmark][rind-wordmark]
adds `ind` after the peel-shaped `r`.

## Status

This project is very new, so exercise due caution.  The overriding
goal of this crate is for use with `rustls` via [rind-rustls][],
but there is also a public API for general-purpose use.

[![Build Status](https://img.shields.io/github/actions/workflow/status/moq-dev/rind/build.yml)](https://github.com/moq-dev/rind/actions/workflows/build.yml?query=branch%3Amain)
[![Latest release](https://img.shields.io/crates/v/rind)](https://crates.io/crates/rind)
[![Documentation](https://img.shields.io/docsrs/rind)](https://docs.rs/rind/)

## Goals

- [x] Fast and simple compilation
    - [x] `cargo build` takes seconds, and requires only rustc
- [x] Competitive performance (with *ring*, aws-lc-rs, and rustcrypto)
- [x] Uses formally-verified code from other projects (where it is as fast)
- [x] Intended to provide algorithms in wide use on web
- [x] Intended for use as a rustls `CryptoProvider`, via [rind-rustls][].

## Limitations

`aarch64`, `x86_64`, and 32-bit `arm` architectures only.

- `aarch64` requires the `neon` CPU feature. Where the CPU has the crypto
  extension (`aes`, `pmull`, and `sha2`), as the Raspberry Pi 5 and most
  aarch64 servers and phones do, AES, GHASH, SHA1, and SHA256 run on its
  instructions. Without it, as on the Raspberry Pi 4, CM4, and Zero 2 W, they
  run [aws-lc]'s NEON and scalar assembly instead (see
  [Algorithms](#algorithms)), `rind::cpu::has_aes_hardware()` is false, and
  rind-rustls and rind-dimpl prefer ChaCha20-Poly1305.
- `x86_64` runs on every x86_64 CPU. Without `aes` and `pclmulqdq`, as on
  Core 2 and Nehalem, AES and GHASH run [aws-lc]'s SSSE3 assembly instead
  (see [Algorithms](#algorithms)), `rind::cpu::has_aes_hardware()` is false,
  and rind-rustls and rind-dimpl prefer ChaCha20-Poly1305. Without `avx2`, as
  on Sandy Bridge, Ivy Bridge, and AMD's Bulldozer and Jaguar cores,
  ChaCha20-Poly1305 runs [aws-lc]'s SSE4.1 assembly, ChaCha20, SHA1, and
  SHA256 its SSSE3 assembly, or for SHA its AVX assembly on Intel's cores,
  ML-KEM's arithmetic runs a Rust port of [mlkem-native]'s portable C, and
  table lookups use SSE2 (see [Algorithms](#algorithms)). Without `sse4.1`,
  as on the first Core 2s and Atoms and AMD's Bobcat, ChaCha20 and Poly1305
  run in separate passes.
  Without `ssse3` either, as on Intel's CPUs before Core 2, AMD's before
  Bobcat and Bulldozer, and QEMU's default `qemu64` model, AES and GHASH run
  Rust ports of [aws-lc]'s constant-time SSE2 and integer C, SHA1 and SHA256
  its integer assembly, and ChaCha20 [HACL\*]'s verified rounds.
  Without `adx`, as on Haswell and AMD's cores before Zen, [s2n-bignum]'s
  `_alt` routines replace those that use it, and [aws-lc]'s Montgomery
  multiplication replaces its Karatsuba routines for RSA; with `avx2` there,
  as on Haswell, RSA-2048 signing runs aws-lc's RSAZ exponentiation. With
  `avx512ifma`, as on Ice Lake, Sapphire Rapids, and AMD's Zen 4 and 5,
  RSA-2048, 3072, and 4096 signing runs aws-lc's dual AVX-512 RSAZ.
- 32-bit `arm` (tested on `armv7-unknown-linux-gnueabihf`, and built for
  `armv7-linux-androideabi`) runs portable Rust instead, mostly from
  [libcrux] (see [Algorithms](#algorithms)), and needs no CPU features. RSA's
  Montgomery multiplication runs [aws-lc]'s assembly, with NEON where the CPU
  has it. Where
  the CPU has the ARMv8 crypto extension, as most 32-bit Android devices do,
  AES, GHASH, SHA1, and SHA256 run [aws-lc]'s assembly for it instead.
  Without it, `rind::cpu::has_aes_hardware()` is false, and rind-rustls and
  rind-dimpl prefer ChaCha20-Poly1305, which is faster there: ChaCha20 runs
  aws-lc's assembly, and so does Poly1305 where the CPU has NEON. SHA-384,
  SHA-512, and SHA-512/256 always run aws-lc's assembly, with NEON where the
  CPU has it, and with NEON, X25519's shared secret runs [BoringSSL]'s
  assembly. ML-KEM's Keccak-f runs [OpenSSL]'s assembly, on NEON where the
  CPU has it.

Every operation panics on a CPU missing one of these. Call `rind::cpu::check()`
at startup to get an error naming the missing feature instead.

## Building and Testing

Compile:
```shell
cargo build --release
```

Run tests:
```shell
git submodule update --init thirdparty/cavp
git submodule update --init thirdparty/wycheproof
cargo test
```

Run performance benchmarks:
```shell
cargo bench
```

`admin/bench-report collect` runs the report's benchmarks on each benchmark
host in turn over ssh, skipping any that is busy, and writes their results
and the hosts' details as JSON under `.tmp/bench-report/`.

With [Nix](https://nixos.org), `nix develop` (or direnv) provides CI's
toolchain, and `just check` runs CI's gate over what the branch changed.
On Linux, `just armv7` runs the nightly armv7 job: it builds and lints for
32-bit ARM, then runs the tests under qemu with the ARMv8 crypto extension,
with NEON alone, and with NEON denied.
`nix develop .#ctgrind --command admin/ctgrind` runs the nightly
constant-time checks under valgrind, `nix develop .#sde --command
admin/ct-sde` those of the AVX-512, VAES, and SHA extension code valgrind
cannot run, under Intel SDE, and `nix develop .#ct-qemu --command
admin/ct-qemu` those of the armv7 crypto extension code valgrind hides, under
qemu.

## Algorithms

Each cell gives rind's time over the fastest of aws-lc-rs and ring on that
path, in the benchmark where rind trails most, then whose code runs: the
[sources](#sources) below, rind's own code, or Graviola's. A **bold** ratio
is a gap, above the noise of about 1.02, and the list under its table gives
the reason. A ✓ marks code its source formally verifies, to the extent
[Sources](#sources) states, and a ⚡ unverified code chosen because it
measured faster than a verified alternative. A cell naming no source runs the
same sources as the one to its left, and an empty cell runs the same code, so
it isn't timed. The rind-rustls rows time full and resumed TLS 1.3 handshakes
and bulk transfer against rustls over aws-lc-rs's and ring's providers. RSA
key generation, whose time swings by up to 3x from run to run, stays out of
the ratios. The nightly `bench` workflow times every cell and keeps each
benchmark's numbers in its summary. These are from [run 41572396019], on
`main` at `d075ffdd`; a change that moves a cell refreshes it.

x86_64 runs every feature of an AMD EPYC 7763 (Zen 3: ADX, AVX2, SHA-NI, and
VAES, but no AVX-512). Each column to its right denies more, as `bench.yml`
describes, and compares with aws-lc-rs alone, since ring cannot be denied a
feature: no ADX denies ADX (Haswell); no AVX2 also AVX2, BMI2, SHA-NI,
AVX-512, VAES, and VPCLMULQDQ (Sandy Bridge); no AVX also AVX (Westmere); no
AES-NI also AES-NI, PCLMULQDQ, and SSE4.1 (Core 2); and SSE2 also SSSE3.
GitHub's pool ran no AVX and SSE2 on an EPYC 7763 too, no ADX and no AES-NI
on an EPYC 9V74 (Zen 4), and no AVX2 on an EPYC 9V45 (Zen 5). The
ChaCha20-Poly1305 cell without AVX2 is from [run 41585945720], on an EPYC 7763,
the x86_64 ChaCha20 header-protection cell from [run 41678532920], and the
no AES-NI and SSE2 ChaCha20-Poly1305 cells from [run 41697909102], both on an
EPYC 9V74.
Intel CPUs without SHA-NI run [aws-lc]'s AVX SHA-1 and SHA-256, and every
Intel CPU its verified ✓ AVX SHA-384 and SHA-512.

| Algorithm | x86_64 | no ADX | no AVX2 | no AVX | no AES-NI | SSE2 |
|---|---|---|---|---|---|---|
| AES-GCM | 0.99 BoringSSL ⚡ + Graviola |  | 1.01 aws-lc ✓ + Graviola | 0.95 Graviola | **1.03** aws-lc + rind | 0.82 |
| AES block, AES-CTR | 1.00 Graviola + aws-lc |  | 1.00 | 0.99 | 1.00 aws-lc | 0.79 |
| ChaCha20 (header protection) | 0.96 HACL* ✓ |  |  |  |  |  |
| ChaCha20-Poly1305, XChaCha20-Poly1305 | 1.01 aws-lc ⚡ |  | 1.00 |  | **1.20** HACL* ✓ + aws-lc ⚡ + Graviola ⚡ | **1.03** HACL* ✓ + Graviola ⚡ |
| SHA-1 | 1.00 rind |  | 1.00 aws-lc | 1.00 |  | 1.00 |
| SHA-256 | 1.02 Graviola ⚡ |  | **1.05** aws-lc ⚡ | 1.01 |  | 1.01 |
| SHA-384, SHA-512, SHA-512/256 | 1.01 aws-lc ⚡ |  | 1.01 | 1.00 |  | 1.00 |
| HMAC | 1.00 Graviola ⚡ |  | **1.05** |  |  |  |
| HKDF | 0.95 rind ⚡ |  | 0.88 |  |  |  |
| PBKDF2 | 1.02 rind |  | 0.93 |  |  |  |
| X25519 | 1.01 s2n-bignum ✓ | 1.01 | 1.01 |  |  |  |
| Ed25519 | 1.02 s2n-bignum ✓ + Graviola ⚡ | 1.00 | 1.01 |  |  |  |
| P-256 ECDH, ECDSA | 0.99 s2n-bignum ✓ + aws-lc ⚡ + Graviola ⚡ | **1.05** | 1.01 |  |  |  |
| P-384 ECDH, ECDSA | 0.90 s2n-bignum ✓ + rind ⚡ + Graviola ⚡ | 0.92 | 0.91 |  |  |  |
| P-521 ECDH, ECDSA | 0.94 s2n-bignum ✓ + rind ⚡ | 0.95 | 0.98 |  |  |  |
| ML-KEM-768 | 1.01 s2n-bignum ✓ + mlkem-native ✓ + Graviola ⚡ |  | 0.96 mlkem-native ⚡ + s2n-bignum ✓ |  |  |  |
| RSA signatures, key generation | **1.08** s2n-bignum ✓ + aws-lc ⚡ | **1.07** | **1.03** |  |  |  |
| rind-rustls handshakes | 0.95 |  | **1.10** |  |  |  |
| rind-rustls 1 MB transfer | 1.00 |  | 0.99 |  |  |  |

- RSA: x86_64 gathers each window entry by [s2n-bignum]'s verified
  `bignum_copy_row_from_table`, and with ADX multiplies 1024- and 2048-bit
  moduli by its verified Karatsuba routines, as [#224] decided, rather than
  by [aws-lc]'s `bn_powerx5` or, at widths that aren't a multiple of eight
  words, `bn_mul_mont_gather5`, which fuse a faster gather into the product.
  RSA-2048 signing takes 1.08 of ring's time and 1.04 of aws-lc-rs's, and
  RSA-2056 1.07 of aws-lc-rs's without ADX and 1.03 without AVX2.
- P-256 without ADX: verification runs s2n-bignum's verified routines, 1.05 of
  aws-lc's `ecp_nistz256`, within the 10% rind accepts for verified code.
- ChaCha20-Poly1305 without AES-NI and on SSE2, which lack SSE4.1: rind runs
  Graviola's scalar Poly1305 there, and aws-lc BoringSSL's SSE2
  `poly1305_vec.c`, which rind doesn't port for CPUs older than Westmere.
  16 KB messages trail most.
- SHA-256, HMAC, and handshakes without AVX2, and AES-GCM without AES-NI:
  noise. Each is one benchmark (SHA-256 of 1200 B, HMAC-SHA1 of 1350 B under a
  reused key, the full handshake with an Ed25519 key, AES-128-GCM key setup)
  that read 0.90-1.00 in [run 41550703300], on an EPYC 9V45.

aarch64 runs a Neoverse-N2, with the crypto extension and the SHA-512 and
SHA-3 instructions; no crypto denies them, as a Raspberry Pi 4 lacks them.
armv7 runs on the same core in 32-bit mode, with NEON and the crypto
extension; without them it runs the code [Symmetric
cryptography](#symmetric-cryptography) names.

| Algorithm | aarch64 | no crypto | armv7 |
|---|---|---|---|
| AES-GCM | **1.07** Graviola | 1.02 aws-lc + rind | 0.99 |
| AES block, AES-CTR | 0.99 Graviola + rind | 1.00 aws-lc | 0.99 |
| ChaCha20 (header protection) | 1.01 Graviola | 0.94 | 0.87 aws-lc ⚡ |
| ChaCha20-Poly1305, XChaCha20-Poly1305 | 1.00 aws-lc ⚡ | 1.00 | 0.99 |
| SHA-1 | 1.01 rind | 1.00 aws-lc | 1.00 |
| SHA-256 | 1.02 aws-lc ⚡ | 1.00 aws-lc | 0.99 aws-lc ⚡ |
| SHA-384, SHA-512, SHA-512/256 | 1.00 aws-lc ✓ | 1.00 | 1.01 aws-lc ⚡ |
| HMAC | 1.00 Graviola ⚡ | 1.00 | 1.00 |
| HKDF | 0.88 rind ⚡ | 0.89 | 1.01 |
| PBKDF2 | 0.93 rind | 0.93 | 1.00 |
| X25519 | 0.81 s2n-bignum ✓ | 0.80 | 0.79 BoringSSL ⚡ + curve25519-dalek ⚡ |
| Ed25519 | 0.89 s2n-bignum ✓ + Graviola ⚡ | 0.77 | 0.88 curve25519-dalek ⚡ + rind ⚡ |
| P-256 ECDH, ECDSA | 1.02 s2n-bignum ✓ + Graviola ⚡ | 0.98 | 0.65 fiat-crypto ✓ + rind ⚡ + Graviola ⚡ |
| P-384 ECDH, ECDSA | 0.78 s2n-bignum ✓ + rind ⚡ + Graviola ⚡ | 0.78 | 0.44 fiat-crypto ✓ + rind ⚡ |
| P-521 ECDH, ECDSA | 0.65 s2n-bignum ✓ + rind ⚡ | 0.64 | **1.04** fiat-crypto ✓ + rind ⚡ |
| ML-KEM-768 | 1.00 s2n-bignum ✓ + Graviola ⚡ | 0.88 | 0.69 mlkem-native ⚡ + OpenSSL ⚡ + Graviola ⚡ |
| RSA signatures, key generation | 0.99 s2n-bignum ✓ + aws-lc ⚡ + Graviola ⚡ | 0.97 | 1.01 aws-lc ⚡ + Graviola ⚡ + rind ⚡ |
| rind-rustls handshakes | 0.91 | 0.83 | 0.96 |
| rind-rustls 1 MB transfer | 1.00 | 1.00 | 1.00 |

- AES-GCM on aarch64: sealing 32 B with AES-128 takes 79 ns to ring's 74;
  opening and every larger size lead.
- P-521 on armv7: verification takes 1.04 of aws-lc-rs's time, and both run
  [fiat-crypto]'s field arithmetic, which spills no carry flag there. A
  `umaal` multiply ran more instructions in [#281], so rind keeps the verified
  code.

The table describes `main`, and changes alongside the code it describes. The
tests use [Wycheproof]'s vectors.

### Sources

| Source | How rind uses it | License | What is verified |
|---|---|---|---|
| [Graviola] | copied: rind began as a copy of it, and rind-rustls of its rustls-graviola; its aarch64 ChaCha20 and its Poly1305 began as [cifra], CC0-1.0 | Apache-2.0 OR ISC OR MIT-0 | nothing |
| rind | its own code | Apache-2.0 OR ISC OR MIT-0 | nothing |
| [s2n-bignum] | copied: its assembly, transliterated into Rust `asm!` by `admin/parse-asm`, which ends each x86_64 routine using 256-bit registers with `vzeroupper` | Apache-2.0 OR ISC OR MIT-0; its ML-KEM and aarch64 Keccak-f routines (from mlkem-native) Apache-2.0 OR ISC OR MIT; its x86_64 Keccak-f (from OpenSSL) Apache-2.0 | HOL Light proofs ([x86_64](https://github.com/awslabs/s2n-bignum/tree/main/x86/proofs), [aarch64](https://github.com/awslabs/s2n-bignum/tree/main/arm/proofs)) that each routine's object code computes its specified result for all inputs. They check s2n-bignum's own build, not rind's transliteration, and do not cover memory safety. |
| [HACL\*] | dependency, through libcrux-hacl-rs and libcrux-poly1305; copied: the ChaCha20 rounds, for HChaCha20 and for x86_64's ChaCha20 up to one block, 128 bytes without AVX2, and every length without SSSE3, from libcrux-chacha20poly1305 | Apache-2.0 | [F\* proofs](https://github.com/hacl-star/hacl-star) of memory safety, functional correctness, and secret independence of the F\* source. libcrux's Rust is compiled mechanically from HACL\*'s verified C, and that step is not itself verified. |
| [mlkem-native] | ported: its portable C polynomial arithmetic (the NTT, inverse NTT, base multiplication, reductions, packing, and rejection sampling), to Rust, for armv7 and x86_64 CPUs without AVX2; copied, by `admin/import-aws-lc` from aws-lc's copy: its x86_64 AVX2 ciphertext compression, which rind ends with `vzeroupper` | Apache-2.0 OR ISC OR MIT | [CBMC proofs](https://github.com/pq-code-package/mlkem-native/tree/main/proofs/cbmc) of memory safety and coefficient bounds for its C. They do not cover rind's port. [HOL Light proofs](https://github.com/pq-code-package/mlkem-native/tree/main/proofs/hol_light/x86_64) that its AVX2 compression's object code computes its specified result for all inputs, of mlkem-native's own build. |
| [libcrux-aes] | dependency for AES-GCM; copied: the block cipher | Apache-2.0 | nothing: libcrux marks it pre-verification |
| [aws-lc] | copied, by `admin/import-aws-lc`: its SHA-384/512 assembly for x86_64 and aarch64, its x86_64 AVX SHA-256 routine and its aarch64 one for the SHA-256 instructions, Montgomery multiplication and the x86_64 exponentiation's `bn_power5` (with one deliberate change: rind's `bn_sqr8x_mont` and `bn_powerx5` zero two scratch words their `mulx` squaring reads unwritten, which valgrind reports though results and timing do not depend on them), AVX2 and dual AVX-512 RSAZ exponentiation, AES-NI AES-CTR, AVX AES-GCM (`aesni_gcm`), P-256's generator multiplication (its row scan and mixed addition), and SSE4.1 and AVX2 ChaCha20-Poly1305 (with one deliberate change: rind's copy reads the choice of AVX2 from the block rind passes it rather than aws-lc's `OPENSSL_ia32cap_P`), its aarch64 NEON ChaCha20-Poly1305, its x86_64 assembly for CPUs without AVX2 (SSSE3 ChaCha20, SSSE3 and AVX SHA-1, and SSSE3 SHA-256) without AES-NI (SSSE3 AES and GHASH), and without SSSE3 (integer SHA-1 and SHA-256), its aarch64 Montgomery multiplication, and its aarch64 assembly for CPUs without the crypto extension (NEON AES, NEON GHASH, and scalar SHA-1 and SHA-256), as Rust naked functions; its 32-bit ARM assembly for ChaCha20, SHA-384/512, Montgomery multiplication, the ARMv8 crypto extension (AES, GHASH, SHA-1, SHA-256), and NEON Poly1305, in Rust `global_asm!`; and the C that drives that Poly1305, RSAZ, and `bn_power5`, that sets up its x86_64 SSSE3 GHASH table, and that computes its constant-time SSE2 AES and integer GHASH for x86_64 CPUs without SSSE3, ported to Rust. aws-lc takes its Poly1305, ChaCha20-Poly1305, SSSE3 GHASH, and constant-time AES and GHASH from BoringSSL and the rest from OpenSSL | Apache-2.0; Poly1305, ChaCha20-Poly1305, SSSE3 and integer GHASH, and constant-time AES ISC | [SAW and NSym proofs](https://github.com/awslabs/aws-lc-verification) that its x86_64 AVX and aarch64 (with and without the SHA-512 instructions) SHA-384/512 routines compute their specified result for all inputs, and SAW proofs that its x86_64 AVX AES-GCM does, for AES-256 and whole blocks. They check aws-lc's own build, not rind's copy, and do not cover its 32-bit ARM code. |
| [BoringSSL] | copied, by `admin/import-boringssl`: its x86_64 VAES AES-GCM assembly, `aes-gcm-avx2-x86_64` and `aes-gcm-avx512-x86_64`, as Rust naked functions; its 32-bit ARM NEON X25519 assembly, in Rust `global_asm!`, which BoringSSL takes from [SUPERCOP]'s `neon2`, public domain | Apache-2.0 | nothing |
| [OpenSSL] | copied, by `admin/import-openssl`: its 32-bit ARM Keccak-f assembly, integer and NEON, `keccak1600-armv4`, in Rust `global_asm!` | Apache-2.0 | nothing |
| [curve25519-dalek] | dependency, with its serial 32-bit backend | BSD-3-Clause | nothing: that backend's field arithmetic is hand-written. Its `fiat` backend would run [fiat-crypto]'s verified field arithmetic instead, but only a `--cfg` flag for the whole build selects it, so rind refuses it rather than let the build pick. |
| [fiat-crypto] | dependency | MIT OR Apache-2.0 OR BSD-1-Clause | [Coq proofs](https://github.com/mit-plv/fiat-crypto) that each generated field operation is correct. rind's point formulas, inversion, and table lookup over them are not covered. |

rind's own code is licensed under Apache-2.0 OR ISC OR MIT-0. Copied code
keeps its source's copyright and license, which [LICENSE] lists with the
texts they require; dependencies ship their own. Every file under
`rind/src` names its license in a `SPDX-License-Identifier` comment, and
files Graviola wrote keep their `Written for Graviola by ...` header. The
`rind` crate as a whole is therefore `(Apache-2.0 OR ISC OR MIT-0) AND
(Apache-2.0 OR ISC OR MIT) AND Apache-2.0 AND ISC`. The adapter crates copy
nothing under another license, so they stay `Apache-2.0 OR ISC OR MIT-0`.
rind-ring runs ring's own tests, which keep ring's licenses and stay out of
the published crate.

A change that copies code from a new source, or moves an algorithm to a
different one, updates this table and [LICENSE] in the same PR.

[Graviola]: https://github.com/ctz/graviola
[graviola-logo]: https://github.com/ctz/graviola/blob/main/admin/picture.png
[rind-wordmark]: https://raw.githubusercontent.com/moq-dev/rind/main/admin/wordmark.png
[aws-lc-rs]: https://github.com/aws/aws-lc-rs
[cifra]: https://github.com/ctz/cifra
[s2n-bignum]: https://github.com/awslabs/s2n-bignum
[HACL\*]: https://github.com/hacl-star/hacl-star
[libcrux-aes]: https://github.com/cryspen/libcrux/tree/main/crates/algorithms/aes
[mlkem-native]: https://github.com/pq-code-package/mlkem-native
[libcrux]: https://github.com/cryspen/libcrux
[aws-lc]: https://github.com/aws/aws-lc
[fiat-crypto]: https://github.com/mit-plv/fiat-crypto
[BoringSSL]: https://boringssl.googlesource.com/boringssl
[OpenSSL]: https://github.com/openssl/openssl
[SUPERCOP]: https://bench.cr.yp.to/supercop.html
[curve25519-dalek]: https://github.com/dalek-cryptography/curve25519-dalek
[Wycheproof]: https://github.com/C2SP/wycheproof
[run 41572396019]: https://github.com/moq-dev/rind/actions/runs/41572396019
[run 41550703300]: https://github.com/moq-dev/rind/actions/runs/41550703300
[run 41585945720]: https://github.com/moq-dev/rind/actions/runs/41585945720
[run 41657617706]: https://github.com/moq-dev/rind/actions/runs/41657617706
[run 41678532920]: https://github.com/moq-dev/rind/actions/runs/41678532920
[run 41697909102]: https://github.com/moq-dev/rind/actions/runs/41697909102
[#224]: https://github.com/moq-dev/rind/pull/224
[#281]: https://github.com/moq-dev/rind/pull/281
[LICENSE]: https://github.com/moq-dev/rind/blob/main/LICENSE
[rind-rustls]: https://crates.io/crates/rind-rustls
[rind-ring]: https://github.com/moq-dev/rind/tree/main/rind-ring
[quests]: https://github.com/moq-dev/rind/blob/main/quest/README.md
[migrating]: https://github.com/moq-dev/rind/blob/main/MIGRATING.md

## Assorted technical details

### RSA
On x86_64 and aarch64, the arithmetic is provided by s2n-bignum, under the
exponentiation described below, except that x86_64 runs aws-lc's Montgomery
multiplication as aws-lc's `bn_mul_mont` picks it (`bn_mul4x_mont` for moduli
whose width in 64-bit words is a multiple of four, `bn_sqr8x_mont` for
squaring a multiple of eight, each by `mulx` with ADX, and `bn_mul_mont_nohw`
for other widths), other than 1024- and 2048-bit moduli on CPUs with ADX,
where s2n-bignum's Karatsuba routines are as fast or faster. aarch64 runs
aws-lc's `bn_mul_mont`, which picks its own squaring or 4x routine by the
width, at every size: on a Neoverse-N2 it measured 1.15 to 2 times as fast as
s2n-bignum's generic routines, and faster than its Karatsuba routines for
1024- and 2048-bit moduli.
armv7 runs the same exponentiation over aws-lc's 32-bit ARM `bn_mul_mont`
routines as aws-lc picks them (`bn_mul8x_mont_neon` with NEON for moduli whose
width in 32-bit words is a multiple of eight, and `bn_mul_mont_nohw`
otherwise), and the rest of the arithmetic in rind's portable Rust.
On x86_64 CPUs with AVX2 but without ADX, the private operation's exponentiation modulo each 1024-bit
prime of RSA-2048 runs aws-lc's RSAZ, as aws-lc does there: Montgomery
products on AVX2 over 29-bit limbs, and a 5-bit fixed window whose table
entry is gathered by masking all 32 entries. Otherwise x86_64 runs aws-lc's
5-bit window, as `BN_mod_exp_mont_consttime` does, gathering each entry by
s2n-bignum's verified routine, which reads every entry. For moduli of a
multiple of 512 bits other than 1024 and 2048 bits with ADX, it runs aws-lc's
`bn_power5` instead: five squarings and the product by an entry gathered by
masking all 32, in one call.
On x86_64 CPUs with AVX-512 IFMA, both exponentiations of the CRT for primes
of 1024, 1536, or 2048 bits run at once by aws-lc's dual RSAZ, as aws-lc's
`BN_mod_exp_mont_consttime_x2` does there: almost Montgomery products on
256-bit vectors over 52-bit limbs, two moduli at a time, and a 5-bit fixed
window whose table entries are gathered by masking all 32. Valgrind runs no
AVX-512, so `admin/ct-sde` checks it under Intel SDE instead.

The RSA private operation always uses the CRT optimisation.

On aarch64 and armv7, modular exponentiation uses a 5-bit fixed exponent window, as aws-lc's does,
and the term is selected by the exponent bits from the table of base powers in a side-channel-free way.
The private operation is always followed by the public operation to verify the result
(and the result compared in a side-channel-free way).

Only RSA signing and verification are provided.  Signing keys have 2048- to
8192-bit moduli; verification also takes 1024-bit moduli and SHA-1, but only
under `signature::verify::legacy`.  Every key refuses a public exponent that
is even, 1, or over 33 bits, and a private key whose components disagree is
refused when it loads, as aws-lc's `RSA_check_key` does.  RSA encryption is not provided:
OAEP waits on a consumer, and PKCS#1 v1.5 encryption, which invites
padding-oracle attacks, is refused.

RSA key generation is supported for five fixed key sizes between 2048-8192-bits.
All generated keys have e = 0x10001 and, as in aws-lc, d reduced mod
lcm(p - 1, q - 1).  Generation runs in constant time in the primes, revealing
only which candidates it discards.

### ECC
On x86_64 and aarch64, all ECC field and scalar arithmetic are provided by
s2n-bignum, except P256's on x86_64 where aws-lc's is named below, and the
rest of this section describes those backends.

P256 base point multiplication on x86_64 is aws-lc's: 7-bit Booth windows over
37 rows of 64 affine points (a 152KB constant table), each row scanned whole
by its SSE2 or AVX2 routine and added by its mixed addition, with `mulq` or
with BMI2 and ADX, as aws-lc's `ecp_nistz256_point_mul_base` runs them. On
aarch64 it is s2n-bignum's `p256_scalarmulbase`, over 6-bit Booth windows and
a table of each window's 32 multiples (an 88KB constant table). Variable
point multiplication is s2n-bignum's `p256_montjscalarmul`.

armv7 runs the aarch64 algorithms for P256 in portable Rust, over
fiat-crypto's field and scalar arithmetic, except its Montgomery
multiplication and squaring, which are rind's. LLVM compiles fiat-crypto's
32-bit multiplication to save and restore the one carry flag 171 times a
call, between its interleaved carry chains; rind's carry in 64-bit
accumulators (`umaal`) instead, in 560 instructions run to fiat-crypto's
1,375. fiat-crypto cannot generate an unsaturated P256, as it does P521:
its bounds checks fail at every 32-bit limb count from 9 to 16. armv7's
P384 runs rind's Montgomery multiplication and squaring the same way, in
1,151 instructions to fiat-crypto's 2,254, over fiat-crypto's other field
and scalar arithmetic.

P384 base point multiplication uses a comb of 20 tables of 16 affine points
(a 30KB constant table) over 5-bit Booth windows, as aws-lc does. Variable
point multiplication is s2n-bignum's `p384_montjscalarmul`.

P521's prime is a Mersenne prime, so its field arithmetic is direct rather
than Montgomery's. Base point multiplication uses a comb of 27 tables of 16
affine points (a 62KB constant table) over 5-bit Booth windows, as aws-lc
does. Variable point multiplication is s2n-bignum's `p521_jscalarmul`.
s2n-bignum's P521 point addition requires points that are not at infinity,
equal, or opposite, so the comb keeps to that, selecting around the cases
it reaches.

ECDSA verification computes `u1 G + u2 Q` in one chain of doublings, as
aws-lc does, adding terms from width-5 non-adjacent forms of the public
scalars: `u2`'s over the public key's odd multiples, computed once when the
key is parsed, and `u1`'s over the first row of the base point table, at
width 6 for P256, as its aarch64 row holds 32 multiples. An addition of equal
or opposite points gives a zero z, as infinity does, so only then is it
redone by cases.

ECDSA follows RFC6979 for generation of `k`, but adds additional non-critical random input.
We do this to avoid the theoretical fragility of RFC6979 under fault conditions.
This is allowed for by RFC6979, and the HMAC-DRBG that it builds on.
The code is structured such that we pass the RFC6979 test vectors.

The code which selects a term from a table of points is non-verified,
and is written in AVX2/Neon intrinsics, or for P256 on x86_64 is aws-lc's
SSE2 and AVX2 assembly.

On x86_64 and aarch64, X25519 directly uses the s2n-bignum implementation.

### ML-KEM-768
On aarch64, and on x86_64 CPUs with AVX2, the core polynomial arithmetic -- the NTT, inverse NTT, base multiplication
and reduction -- is provided by s2n-bignum (contributed by the mlkem-native
developers).  The surrounding FIPS-203 construction (key generation,
encapsulation and decapsulation) is written in Rust. With AVX2, ciphertext
compression runs mlkem-native's AVX2 assembly.

x86_64 CPUs without AVX2 run the same construction over a Rust port of
mlkem-native's portable C arithmetic instead, in natural coefficient order as
aarch64 keeps it, and Keccak-f four states one at a time, chosen once per
process. It measured 1.3x faster than libcrux's portable ML-KEM for key
generation and encapsulation there, and 2x for decapsulation.

armv7 runs the same construction and arithmetic, with [OpenSSL]'s Keccak-f:
NEON where the CPU has it, and integer code on bit-interleaved lanes
otherwise. Keccak-f dominates ML-KEM there, and compiled code spills its
state. With NEON it measured 1.5x faster than libcrux's portable ML-KEM for
key generation and encapsulation, and 2.8x for decapsulation. Without NEON,
under qemu, it ran key generation and encapsulation in 1.3x fewer
instructions.

Compression and decompression are division-free, avoiding the variable-time
division behind the KyberSlash attacks.

For sampling, which is a significant factor in ML-KEM performance, we
have some different options depending on CPU features:

- We have a `SampleNTT()` which does 8-wide Keccak-f permutation followed by
  rejection sampling using AVX-512 (F, BW, VBMI, VBMI2) on x86-64.
- We have a 4-wide Keccak-f using AVX2 on x86-64.
- We have a 2-wide Keccak-f using Neon+SHA3 on aarch64.
- We have a basic Keccak-f using scalar instructions on aarch64.
- We have OpenSSL's Keccak-f, on NEON or bit-interleaved in integer code, on
  armv7.

### Symmetric cryptography
SHA1 and SHA256 have straightforward implementations using hashing intrinsics
(aka "SHA-NI" on x86_64, "sha" extension on aarch64), except that aarch64 runs
aws-lc's SHA256 assembly for those instructions: it keeps a register copy off
each round's dependency chain, where LLVM's code for the intrinsics puts one
on it. Without SHA-NI, x86_64
selects at runtime an AVX2 message schedule with scalar rounds for SHA1, as
aws-lc does. For SHA256 it runs aws-lc's AVX routine on Intel, as aws-lc
picks, and the same AVX2 approach elsewhere, since the AVX routine rotates with
`shrd`, which pre-Zen AMD runs slowly. Without AVX2 either, both run aws-lc's
AVX routines on Intel and its SSSE3 ones elsewhere, as aws-lc picks; they are
2.2x (SHA256) and 1.7x (SHA1) faster than the pure Rust ones on Intel.
Without SSSE3 too, both run aws-lc's integer routines, as aws-lc does: 2.2x
(SHA256) and 1.25x (SHA1) faster than the pure Rust ones, and 1.3-1.5x
faster than HACL*'s SHA256.
aarch64 without the crypto extension runs aws-lc's
scalar SHA1 and SHA256 assembly. 32-bit `arm` runs aws-lc's SHA1 and SHA256 assembly
where the CPU has the crypto extension, and the pure Rust SHA1 and SHA256
otherwise: libcrux has no SHA1, and the pure Rust SHA256 is faster than
libcrux's.

SHA384, SHA512, and SHA512/256 run aws-lc's assembly everywhere. On x86_64,
its AVX routine on Intel and its scalar routine on other CPUs, as aws-lc picks:
the AVX routine is 1.1x faster than the scalar one on Intel, and 1.5x slower on
AMD's Zen. On aarch64, its routine for the SHA-512 instructions where the CPU
has them, and its scalar routine otherwise; on 32-bit `arm`, its NEON routine
where the CPU has NEON, and its scalar routine otherwise.

x86_64 decides once per process whether the CPU has AES-NI and PCLMULQDQ,
and SSSE3. Without the first two, as on Core 2 and Nehalem, AES and AES-CTR
run aws-lc's `vpaes-x86_64` assembly and GHASH its `ghash-ssse3-x86_64`,
composed into AES-GCM as aws-lc composes them, taking turns over 3 KB; both
modes measured level with aws-lc's. Without SSSE3 either, as on QEMU's
`qemu64`, they run Rust ports of the C aws-lc runs there: `aes_nohw.c`, which
bitslices eight blocks into SSE2 registers and computes the S-box as a
circuit, and `gcm_nohw.c`, which multiplies with integer multiplies of
operands masked to every fourth bit, so no carry reaches a bit it keeps.
Neither branches or indexes memory by a secret. Composed the same way,
AES-GCM and AES-CTR measured 0.82-0.92x aws-lc's time; libcrux's portable
AES-GCM measured 3-7x slower, and its bitsliced block level with the port's
for one block. With AES-NI and PCLMULQDQ, AES-CTR runs aws-lc's
`aes_hw_ctr32_encrypt_blocks`, 1.1-2x faster than rind's by-8 intrinsics at
every length, with or without AVX.

AES-GCM has a stitched by-8 AES-CTR and a by-8 GHASH, SSE-encoded on every
CPU: VEX encoding measured no faster with AVX, and without it, as on Westmere
and the Goldmont and Tremont Atoms, this is 1.02-1.28x faster than aws-lc's
SSE `aesni-x86_64` and `ghash-x86_64` routines. With AVX and MOVBE but no
VAES, as from Haswell through Comet Lake and on Zen 1 and 2, aws-lc's
verified `aesni_gcm` routine, which interleaves AES-CTR and GHASH six blocks
at a time, takes messages from 288 bytes to encrypt and 96 to decrypt, as
aws-lc and ring run it, and the by-8 code takes their tails; on an i7-8700
(Coffee Lake) this measured 1.2-1.7x faster than the by-8 code alone from
1200 bytes to 16 KB. Every 256- and 512-bit kernel rind runs ends with
`vzeroupper`, so SSE code after one pays no AVX-SSE transition or false
dependency. There is also an optional AVX-512 by-16 AES-CTR
and GHASH.  It uses dynamic CPU feature detection, so AVX-512 is not required at runtime.
On cores with VAES, BoringSSL's kernels, which interleave AES-CTR and GHASH, take
long messages: its 512-bit kernel from 2 KB where the CPU has AVX-512 (the by-16
path is quicker below that), and its 256-bit kernel from 256 bytes otherwise.
The key picks its kernel once, when it is made.

aarch64 decides once per process whether the CPU has the crypto extension.
With it, AES-GCM runs s2n-bignum's kernels, which interleave a by-4 AES-CTR
and GHASH over whole blocks. An AES-256 key made on a core with SHA3 runs their
by-8 kernels instead, which use its three-way XOR. They run in place, outside
their proofs, which assume separate input and output buffers.
`admin/parse-asm/inplace.py` walks them at every length to 64 blocks, checking
that each block is loaded before it is stored and that their branches and
addresses depend only on the length.

Without it, AES runs aws-lc's `vpaes-armv8`, Mike Hamburg's vector permutation
AES, whose S-box is NEON `tbl` lookups into registers, and GHASH runs aws-lc's
`ghash-neon-armv8`, which builds each product from NEON's 8-bit polynomial
multiplies; neither reads memory or branches by a secret. AES-GCM runs AES-CTR
and GHASH over each eight blocks in turn, as aws-lc composes them.

32-bit `arm` decides once per process from `AT_HWCAP2`: with the crypto
extension, AES and AES-GCM keys use aws-lc's `aesv8-armx` and `ghashv8-armx`
assembly, composed as aws-lc does on that architecture; without it, libcrux's
bitsliced AES and AES-GCM.

x86_64 CPUs with AVX2 run ChaCha20 on Graviola's AVX2 kernels from two
blocks, and on HACL*'s verified rounds in general-purpose registers for one
block, as QUIC header protection takes and as aws-lc runs its integer routine
there: the kernels compute even one block as a single serial chain, which Zen
5's two-cycle vector latency doubles, so header protection on them took 1.89
of aws-lc-rs's time on an EPYC 9V45 in [run 41585945720]. On HACL*'s rounds
it takes 0.89 on an EPYC 9V74 (Zen 4) in [run 41678532920], against 0.83 on
the kernels in [run 41657617706]. No run has drawn Zen 5 since; the fix is
expected to hold there because HChaCha20, below, measured the same cause and
fix on it. For one block, the kernels measured 1.05-1.3x faster than HACL*'s
rounds on Coffee Lake, Arrow Lake, and Zen 3, where HACL*'s rounds are within
10% of aws-lc's integer routine.

x86_64 CPUs without AVX2 run ChaCha20 above 128 bytes on aws-lc's
`chacha-x86_64` SSSE3 routine, four blocks at a time, as aws-lc picks it,
which measured 2.4-2.7x faster than HACL*'s rounds from 256 bytes on Coffee
Lake, Zen 3, and Arrow Lake. Up to that, and at every length without SSSE3,
where aws-lc runs its integer routine, they run HACL*'s verified rounds, which
took 0.92-1.07 of that routine's time on the same CPUs, within the 10% rind
accepts for verified code. Header protection without AVX2 takes 0.91 of
aws-lc-rs's time on an EPYC 9V74 and 0.96 on a Xeon Platinum 8573C in
[run 41697909102].

HChaCha20, for XChaCha20, runs HACL*'s verified rounds in general-purpose
registers on every architecture, as aws-lc does: one block in vector
registers is a single serial chain, which Zen 5's two-cycle vector latency
doubles. On an EPYC 9V45, sealing 32 B with XChaCha20-Poly1305 natively takes
0.99 of aws-lc-rs's time in [run 41585945720], against 1.11 with SSSE3 rounds
in [run 41550703300].

ChaCha20-Poly1305, and XChaCha20-Poly1305 after HChaCha20, run aws-lc's
`chacha20_poly1305` assembly, which interleaves ChaCha20 with Poly1305 in one
pass: on x86_64, its AVX2 half where the CPU has AVX2 and BMI2 and its SSE4.1
half otherwise, as aws-lc picks them, and on aarch64, its NEON routine.
aws-lc's x86_64 routine reads its pick from `OPENSSL_ia32cap_P`; rind's copy
reads the same bits from the block rind passes it, so the path is decided
once per process like rind's others. Without SSE4.1, ChaCha20 and Poly1305
run in separate passes, as in aws-lc.

32-bit `arm` runs ChaCha20 on aws-lc's `chacha-armv4` assembly, switching from
its integer routine to its NEON one at 192 bytes as aws-lc does, where
`AT_HWCAP` reports NEON. Poly1305 runs aws-lc's NEON code there too, and
HACL*'s verified Poly1305 without NEON.

## Architecture

rind's API is its own, shaped so that misuse fails to compile rather than at
run time. [MIGRATING.md][migrating] maps each ring and aws-lc-rs item to it.

- Each module takes an algorithm as a `&'static` constant, such as
  `aead::AES_128_GCM` or `signature::verify::ECDSA_P256_SHA256_ASN1`, and has
  one key type per role.
- Algorithms only old protocols should use sit in `legacy` submodules, such
  as `digest::legacy::SHA1`.
- Key pairs name the DER format they load or encode (`from_pkcs8`,
  `from_sec1`, `to_spki`), and every private key returns its public half
  from `public_key()`.
- Encodings, signatures, and shared secrets are owned values of fixed
  capacity, such as `signature::Pkcs8`, rather than caller buffers or
  allocations. Keys wipe their secrets on drop.
- No call takes a random source: rind draws from the system's when it needs
  one, and `rand::fill` gives callers the same.
- Fallible calls return `rind::Error`, whose variant says which kind of call
  failed, such as `KeyRejected` or `BadSignature`.

The modules:

- `aead`: AES-GCM and ChaCha20-Poly1305 keys with caller nonces, an
  XChaCha20-Poly1305 key that picks random nonces, and QUIC header-protection
  keys.
- `cipher`: bare AES, AES-CTR, and ChaCha20, for DTLS record number
  protection and SRTP.
- `agreement`: ephemeral X25519 and ECDH on P-256, P-384, and P-521.
- `kem`: ML-KEM-768.
- `signature`: ECDSA on P-256, P-384, and P-521, RSA PKCS#1 v1.5 and PSS, and
  Ed25519 key pairs and verification, plus RSA keys given as their
  components, and SHA-1 and 1024-bit RSA for verifying old signatures.
- `digest`: SHA-1 (legacy only), SHA-256, SHA-384, SHA-512, and SHA-512/256.
- `hmac`: HMAC over those digests, keyed once and reused.
- `hkdf`: HKDF over those HMACs, whose output becomes an `aead`, QUIC header-protection, or `hmac` key.
- `pbkdf2`: PBKDF2 over those HMACs, deriving or verifying a key from a password.
- `constant_time`: comparing secrets such as MACs without a timing leak.
- `rand`: random bytes from the system.
- `cpu`: the startup check for required CPU features, and whether AES runs
  in hardware.

The public modules wrap three private layers:

- `low`: low level primitives. platform-specific. unsafe allowed. minimal std and alloc.
- `mid`: constructions, protocols and encodings. platform agnostic. no unsafe. minimal std and alloc.
- `high`: high level encodings and operations. platform agnostic. no unsafe.

`low` code should not refer to `mid`, nor `mid` to `high`.

`low` must present the same interface irrespective of platform.  To this end,
`low::generic` contains pure-rust polyfills for items we don't have assembler-
or intrinsic-based implementations for a certain platform.
