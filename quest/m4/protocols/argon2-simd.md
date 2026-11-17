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

- NEON stays only if it beats this tree's portable permutation on an Apple core and a Neoverse core. The M1 Pro is the Apple core: SHA3 and interleaved NEON beat RustCrypto there, and the scalar rider stays off the SHA3 fill (about 6% slower at 64 MiB). Against this portable permutation (below), on the M1 Pro the SHA3 fill is 1.76x and 1.65x and plain NEON 1.55x and 1.31x. On the Neoverse core the gate as written loses: it picks the SHA3 fill, 0.90x and 0.96x, while plain NEON with the scalar rider is 1.07x and 1.06x. So the gate stays off. Only plain NEON wins on both cores. Turning NEON on needs a selection that runs plain NEON on Neoverse-N2 and the SHA3 fill on Apple, and that choice is still open.
- Pi 5 (Cortex-A76), Pixel 9 Pro, and Jetson are separate from that Neoverse core. On the Pi the scalar-rider NEON fill was about 0.83× the previous NEON fill and about 0.61–0.71× RustCrypto. Still to measure: this portable permutation.
- AVX-512 stays only where it wins on Zen 4 or 5 and on Sapphire Rapids. Neither is measured. A 5th-gen Xeon is Emerald Rapids, and the Xeon 6975P-C GitHub runner (below) is Granite Rapids, so neither number closes the rule.
- AVX-512 constant time is `admin/ct-sde argon2` (Sapphire Rapids model, test `ct_sde_argon2_avx512`), from `nix develop .#sde`. Not run on this branch.

### Measured

2026-11-17, `cargo bench -p rind-bench --bench argon2` with criterion's defaults, each configuration built once and run three times, interleaved with the order rotated each round. The GitHub runners pin to one CPU. Each value is the median of the three runs' criterion medians, in ms; spread is (max - min) / median. Ratio is the portable `rind` time over this row's. Tree: this branch at `e3e4d0cd` plus a measuring workflow only (`steelhead99x/rind`, branch `wip/argon2-measure`), rustc 1.100.0.

Neoverse-N2 GitHub runner (`ubuntu-24.04-arm`, 4 CPUs, has `sha3`). `default` is the portable permutation, `neon` takes the SHA3 fill, and `neon-plain` is plain NEON with the scalar rider (`RIND_CPU_DISABLE_sha3=1`). `neon_matches_scalar` passes with and without the gate.

| rind fill | 16MiB-t1-p1 | spread | vs portable | 64MiB-t3-p4 | spread | vs portable |
|---|---|---|---|---|---|---|
| portable (`default`) | 7.16 | 2.3% | 1.000x | 129.60 | 1.5% | 1.000x |
| SHA3 (`rind_argon2_neon`) | 7.98 | 2.1% | 0.897x | 135.04 | 3.6% | 0.960x |
| plain NEON + rider | 6.72 | 2.4% | 1.066x | 122.84 | 1.7% | 1.055x |
| RustCrypto (in the `default` runs) | 7.12 | 6.2% | 1.005x | 136.10 | 2.4% | 0.952x |

Apple M1 Pro (macOS 14, has `sha3`), rustc 1.98.1, not pinned (macOS has no `taskset`), each round under the machine's bench lock while no other build or bench ran. Load rose during rounds 2 and 3 from work outside the lock, hence the wider 64 MiB spread. Every NEON run still beats every portable run. `neon_matches_scalar` passes with and without the gate.

| rind fill | 16MiB-t1-p1 | spread | vs portable | 64MiB-t3-p4 | spread | vs portable |
|---|---|---|---|---|---|---|
| portable (`default`) | 6.20 | 5.9% | 1.000x | 99.76 | 15.6% | 1.000x |
| SHA3 (`rind_argon2_neon`) | 3.52 | 2.9% | 1.760x | 60.58 | 17.8% | 1.647x |
| plain NEON + rider | 4.00 | 10.3% | 1.547x | 76.46 | 25.1% | 1.305x |
| RustCrypto (in the `default` runs) | 6.08 | 7.1% | 1.020x | 96.29 | 18.4% | 1.036x |

Intel Xeon 6975P-C GitHub runner (`ubuntu-24.04`, Granite Rapids, 4 vCPUs, has `avx512f`). `portable` and `ssse3` deny AVX2 with `RIND_CPU_DISABLE_avx2=1`. `matches_portable` passes for the AVX2, AVX-512, and SSSE3 fills, and `configured_dispatch_matches_portable` passes under `rind_argon2_avx512`.

| rind fill | 16MiB-t1-p1 | spread | vs portable | 64MiB-t3-p4 | spread | vs portable |
|---|---|---|---|---|---|---|
| portable | 7.85 | 0.4% | 1.000x | 106.89 | 0.6% | 1.000x |
| SSSE3 (`rind_argon2_ssse3`) | 7.01 | 0.5% | 1.120x | 94.31 | 3.3% | 1.133x |
| AVX2 (`default`) | 4.57 | 0.5% | 1.718x | 66.15 | 0.2% | 1.616x |
| AVX-512 (`rind_argon2_avx512`) | 3.53 | 0.5% | 2.224x | 54.13 | 4.2% | 1.975x |
| RustCrypto (in the `default` runs) | 6.04 | 0.0% | 1.300x | 94.19 | 0.4% | 1.135x |

On that Xeon, AVX-512 is 1.29x the AVX2 fill at 16 MiB and 1.22x at 64 MiB. Granite Rapids is neither of the plan's two CPUs, so AVX-512 stays gated.

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
