# [S] Argon2id fills memory with the fastest kernel on aarch64 and AVX-512

## Goal

Argon2id's compression function runs the fastest kernel measured on aarch64, on x86_64 CPUs with AVX-512, and on x86_64 CPUs without AVX2, so a defender affords more memory per second than an attacker's GPU gains. Today aarch64 and x86_64 without AVX2 run rind's portable Rust, and x86_64 with AVX2 a port of the reference implementation's AVX2 rounds, which measured 18% faster than RustCrypto's `argon2` and 1.7x faster than OpenSSL's on an Intel Core Ultra 7 270K Plus (`rind-bench`'s `argon2`, RFC 9106's 64 MiB recommendation).

## Plan

- aarch64: write a NEON kernel on the reference's 128-bit (`blamka-round-opt.h` SSE) layout and keep it only if it beats the portable Rust, which LLVM may already vectorize, on an Apple core and a Neoverse core.
- AVX-512: measure libsodium's `argon2-fill-block-avx512f.c` (ISC) layout against the AVX2 port on Zen 4 or 5 and on Sapphire Rapids, keeping it only where it wins on both. `admin/ctgrind` cannot decode AVX-512, so its constant-time test runs under `admin/ct-sde`.
- x86_64 without AVX2: measure the reference's SSSE3 rounds against the portable Rust.
- No host the implementing agent could reach had AVX-512 or aarch64 when [moq-dev/rind#634](https://github.com/moq-dev/rind/pull/634) landed Argon2id; the Mac mini and the bench workflow's arm64 and AVX-512 runners can measure them.

## Status

The measured aarch64 fill from `perf/argon2-neon-scalar-rider` (`3025440d`) is ported onto the current `argon2_compress`. `#634` replaced that stack's mid and high layers, so the old commits do not apply. It is `perf/argon2-interleave` (`d7b1f399`) plus the scalar rider, on the SHA3 `xar` / `umlal` fill from `perf/argon2-sha3-umlal` (`a05b78e4`). Dispatch runs it only with `--cfg rind_argon2_neon`. A CPU with SHA3 takes the `xar`/`umlal` fill; any other aarch64 CPU takes plain NEON with the scalar rider. Tests compare both to the portable permutation (`low::aarch64::argon2_neon::neon_matches_scalar`).

x86_64 still runs the landed AVX2 fill. The reference's SSSE3 and AVX-512F fills from `d6114f56` sit beside it, tested against the portable permutation, and run only with `--cfg rind_argon2_ssse3` and `--cfg rind_argon2_avx512`. The AVX-512 kernel is that reference layout. Comparing it with libsodium's `argon2-fill-block-avx512f.c`, which the plan names, is still open.

Published numbers are in `steelhead99x/rind-results`, branches `results/argon2-a76-interleave` (`results/argon2-interleave/`) and the scalar-rider notes in that same branch (`results/argon2-scalar-rider/`). They compare fills to each other and to RustCrypto, at 1 MiB t=3, 16 MiB t=1, and 64 MiB t=1, which is not this bench.

### Still open against the keep rules

- NEON stays only if it beats this tree's portable permutation on an Apple core and a Neoverse core. The M1 Pro is the Apple core: SHA3 and interleaved NEON beat RustCrypto there, and the scalar rider stays off the SHA3 fill (about 6% slower at 64 MiB). Still to measure: this portable permutation, with the commands below. A GitHub `ubuntu-24.04-arm` runner is the Neoverse core, and that number is still to take.
- Pi 5 (Cortex-A76), Pixel 9 Pro, and Jetson are separate from that Neoverse core. On the Pi the scalar-rider NEON fill was about 0.83× the previous NEON fill and about 0.61–0.71× RustCrypto. Still to measure: this portable permutation.
- AVX-512 stays only where it wins on Zen 4 or 5 and on Sapphire Rapids. Neither is measured. A 5th-gen Xeon is Emerald Rapids, so its number does not close the rule.
- AVX-512 constant time is `admin/ct-sde argon2` (Sapphire Rapids model, test `ct_sde_argon2_avx512`), from `nix develop .#sde`. Not run on this branch.

### Bench

Record `lscpu` first. Each distinct `RUSTFLAGS` rebuilds. Compare the `rind` lines of `argon2id-16MiB-t1-p1` and `argon2id-64MiB-t3-p4`.

What dispatch runs today, portable on aarch64 and AVX2 on an AVX2 CPU:

```shell
cargo bench -p rind-bench --bench argon2 -- --noplot
```

NEON gate. SHA3 fill when `lscpu` lists `sha3` or `sha512`, otherwise plain NEON with the scalar rider:

```shell
RUSTFLAGS='--cfg rind_argon2_neon' cargo bench -p rind-bench --bench argon2 -- --noplot
```

Plain NEON on a SHA3 CPU:

```shell
RUSTFLAGS='--cfg rind_argon2_neon --cfg rind_cpu_disable' RIND_CPU_DISABLE_sha3=1 \
  cargo bench -p rind-bench --bench argon2 -- --noplot
```

AVX-512 against the AVX2 fill, on a CPU that has both:

```shell
RUSTFLAGS='--cfg rind_argon2_avx512' cargo bench -p rind-bench --bench argon2 -- --noplot
```

SSSE3 against the portable permutation. The first command is the portable fill; the second is SSSE3:

```shell
RUSTFLAGS='--cfg rind_cpu_disable' RIND_CPU_DISABLE_avx2=1 \
  cargo bench -p rind-bench --bench argon2 -- --noplot
RUSTFLAGS='--cfg rind_argon2_ssse3 --cfg rind_cpu_disable' RIND_CPU_DISABLE_avx2=1 \
  cargo bench -p rind-bench --bench argon2 -- --noplot
```

Pi 5, Pixel 9 Pro, and Jetson run the first two commands, and the plain-NEON command when the CPU has SHA3. The M1 Pro runs all three aarch64 commands. The 5th-gen Xeon runs the default command and the AVX-512 command. GitHub's `ubuntu-24.04-arm` runner is the Neoverse keep-rule host. `ubuntu-24.04` runs the x86 commands; record `flags`, because the runner may not have AVX-512.
