# Platforms

rind has assembly for `aarch64`, `x86_64`, and 32-bit `arm` from ARMv7 on, and
a portable Rust backend for every other architecture. CI tests Linux (glibc and musl), macOS, and Windows on `x86_64` and `aarch64`, Linux on
`armv7` and ARMv6, iOS in the simulator on `aarch64`, and Android on
`aarch64`, `armv7`, ARMv5TE, and `x86_64`, the 32-bit ARM targets and Android's
`aarch64` under qemu. iOS devices' code is only built.

- `aarch64` requires the `neon` CPU feature. Where the CPU has the crypto
  extension (`aes`, `pmull`, and `sha2`), as the Raspberry Pi 5 and most
  aarch64 servers and phones do, AES, GHASH, SHA1, and SHA256 run on its
  instructions. Without it, as on the Raspberry Pi 4, CM4, and Zero 2 W, they
  run [aws-lc]'s NEON and scalar assembly instead (see
  [ALGORITHMS.md](ALGORITHMS.md)), `rind::cpu::has_aes_hardware()` is false, and
  rind-rustls and rind-dimpl prefer ChaCha20-Poly1305. On Apple's platforms,
  secret-dependent code runs with data-independent timing (DIT), set and
  cleared in each call unless `rind::cpu::Dit::hold()` holds it across a batch
  of calls. rind sets no DIT on other aarch64 platforms, where Arm says it
  changes nothing on current cores.
- `x86_64` runs on every x86_64 CPU. Without `aes` and `pclmulqdq`, as on
  Core 2 and Nehalem, AES and GHASH run [aws-lc]'s SSSE3 assembly instead
  (see [ALGORITHMS.md](ALGORITHMS.md)), `rind::cpu::has_aes_hardware()` is false,
  and rind-rustls and rind-dimpl prefer ChaCha20-Poly1305. Without `avx2`, as
  on Sandy Bridge, Ivy Bridge, and AMD's Bulldozer and Jaguar cores,
  ChaCha20-Poly1305 runs [aws-lc]'s SSE4.1 assembly, ChaCha20, SHA1, and
  SHA256 its SSSE3 assembly, or for SHA its AVX assembly on Intel's cores,
  SHA-512 its scalar assembly on other vendors' cores,
  ML-KEM's arithmetic runs a Rust port of [mlkem-native]'s portable C, and
  table lookups use SSE2 (see [ALGORITHMS.md](ALGORITHMS.md)). Without `sse4.1`,
  as on the first Core 2s and Atoms and AMD's Bobcat, ChaCha20 and Poly1305
  run in separate passes.
  Without `ssse3` either, as on Intel's CPUs before Core 2, AMD's before
  Bobcat and Bulldozer, and QEMU's default `qemu64` model, AES and GHASH run
  Rust ports of [aws-lc]'s constant-time SSE2 and integer C, SHA1 and SHA256
  its integer assembly, and ChaCha20 [HACL\*]'s verified rounds.
  Without `adx`, as on Haswell, AMD's cores before Zen, and virtual CPUs
  that hide it, [s2n-bignum]'s `_alt` routines replace those that use it,
  and [aws-lc]'s Montgomery multiplication replaces its Karatsuba routines
  for RSA; with `avx2` there, as on Haswell, RSA-2048 signing runs aws-lc's
  RSAZ exponentiation, and Ed25519 verification a port of
  [curve25519-dalek]'s AVX2 backend. With `avx512ifma`, as on Ice Lake,
  Sapphire Rapids, and AMD's Zen 4 and 5, RSA-2048, 3072, and 4096 signing
  runs aws-lc's dual AVX-512 RSAZ.
- 32-bit `arm` from ARMv7 on (tested on `armv7-unknown-linux-gnueabihf` and
  `armv7-linux-androideabi`) runs portable Rust instead, mostly from
  [libcrux] (see [ALGORITHMS.md](ALGORITHMS.md)), and needs no CPU features. RSA's
  Montgomery multiplication runs [aws-lc]'s assembly, with NEON where the CPU
  has it. Where
  the CPU has the ARMv8 crypto extension, as most 32-bit Android devices do,
  AES, GHASH, SHA1, and SHA256 run [aws-lc]'s assembly for it instead.
  Without it, `rind::cpu::has_aes_hardware()` is false, and rind-rustls and
  rind-dimpl prefer ChaCha20-Poly1305, which is faster there: ChaCha20 runs
  aws-lc's assembly, and so does Poly1305 where the CPU has NEON. SHA-384,
  SHA-512, and SHA-512/256 always run aws-lc's assembly, with NEON where the
  CPU has it, and with NEON, X25519's shared secret runs [BoringSSL]'s
  assembly. SHA-3's and ML-KEM's Keccak-f runs [OpenSSL]'s assembly, on NEON
  where the CPU has it.

- Every other architecture, big-endian `aarch64` and `arm`, whose assembly
  assumes little-endian, and `arm` before ARMv7, which rind's ARMv7 assembly
  does not run on, run the portable backend: what 32-bit `arm` runs without
  NEON and the crypto extension, with portable Rust in place of the assembly
  `arm` always runs (see [ALGORITHMS.md](ALGORITHMS.md)). It needs no CPU
  features, `rind::cpu::has_aes_hardware()` is false, and rind-rustls and
  rind-dimpl prefer ChaCha20-Poly1305. Stable Rust shows a build script an
  ARM target's version only in its triple, so `arm-unknown-linux-gnueabihf`
  runs the portable backend even when built for a newer core. CI tests it on
  `x86_64`, where `--cfg rind_portable` forces it, on
  `arm-unknown-linux-gnueabi` and `arm-unknown-linux-gnueabihf` under qemu's
  ARMv6 core (the ARM1176 of the Raspberry Pi 1 and Zero), and on
  `arm-linux-androideabi`, which Rust builds for ARMv5TE, under qemu. On 32-bit `x86` it needs a
  Rust newer than the 1.90 MSRV, since libcrux-platform 0.0.4 calls `__cpuid`
  outside `unsafe`.

Every operation panics on a CPU missing one of these. Call `rind::cpu::check()`
at startup to get an error naming the missing feature instead.

[COMPATIBILITY.md](COMPATIBILITY.md) lists the features of each Intel CPU
family since 2004, and of some AMD cores.

[s2n-bignum]: https://github.com/awslabs/s2n-bignum
[curve25519-dalek]: https://github.com/dalek-cryptography/curve25519-dalek
[HACL\*]: https://github.com/hacl-star/hacl-star
[mlkem-native]: https://github.com/pq-code-package/mlkem-native
[libcrux]: https://github.com/cryspen/libcrux
[aws-lc]: https://github.com/aws/aws-lc
[BoringSSL]: https://boringssl.googlesource.com/boringssl
[OpenSSL]: https://github.com/openssl/openssl
