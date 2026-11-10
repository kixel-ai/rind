# [S] Nightly rows for the tiers nothing times

## Goal

The nightly `bench` workflow times three tiers no benchmark host or row runs today: aarch64 with the crypto extension but without the SHA3 and SHA-512 instructions, x86_64 with AVX-512 denied, and armv7 without the crypto extension. BENCHMARKS.md's CPU tiers show each as a column.

## Plan

Planned from the 2026-11-09 speed audit; the maintainer accepted it that day and placed measurement quests in m2. This adds measurement only: no speed gain is expected, and each gap a new row shows is triaged like any other.

aarch64 without SHA3 and SHA-512, as a Cortex-A76 (Raspberry Pi 5) and a Neoverse N1 (Graviton2) are:

- The native row runs a Neoverse-N2 (`.github/workflows/bench.yml:79`), which has `sha3`, as `kixtop`'s M4 does (`benchmarks/data/kixtop.json`, `rind_cpu`). The `no crypto` row denies everything at once (`.github/workflows/bench.yml:178`).
- So nothing times what rind picks in between: s2n-bignum's 4-way AES-GCM kernels (`rind/src/low/aarch64/aes_gcm.rs:285`), the composed AES-192-GCM (`rind/src/low/aarch64/aes_gcm.rs:265`), `sha512_block_data_order_nohw` (`rind/src/low/aarch64/sha512.rs:20`), and scalar Keccak-f (`rind/src/low/aarch64/sha3_keccak_f1600_mux.rs:6`).
- Deny rind `sha3` with `RIND_CPU_DISABLE_sha3=1`, and aws-lc its SHA512 and SHA3 bits in `OPENSSL_armcap`: the two bits the `no crypto` row's `~0x87c` adds to the crypto extension's, to check against aws-lc's `arm_arch.h`. ring cannot be denied, so the row leaves it out, as the other denied rows do.

x86_64 without AVX-512, as Zen 3 and Intel's client cores from Alder Lake are:

- The native row times whichever CPU GitHub draws: an EPYC 9V74 (Zen 4, AVX-512) in [run 41932862737](https://github.com/moq-dev/rind/actions/runs/41932862737), and an EPYC 7763 (Zen 3) in [run 42526977036](https://github.com/moq-dev/rind/actions/runs/42526977036). The VAES AVX2 tier and the AVX-512 tier are each timed only on some nights.
- Add a row that denies rind's `avx512*` features (`rind/src/low/x86_64/cpu.rs:472`) and aws-lc's AVX-512 bits in `OPENSSL_ia32cap`, keeping VAES and VPCLMULQDQ, so the VAES AVX2 tier is timed every night. It runs the benches AVX-512 changes: AES-GCM, ML-KEM, and RSA signing.
- The AVX-512 tier cannot be forced on a runner without it, and rented hosts were rejected on 2026-11-01. Recommend that the native column name the tier its CPU ran, so a night that drew no AVX-512 CPU is not read as one that timed it.

armv7 without the crypto extension, as every ARMv7 core is:

- The one armv7 row (`.github/workflows/bench.yml:86`) runs with the crypto extension, on the arm64 runner in 32-bit mode. `TESTING.md:56` tests armv7 with NEON alone and without NEON, and nothing times either.
- Deny rind with `RIND_CPU_DISABLE_aes`, `_pmull`, `_sha1`, and `_sha2` (`rind/src/low/arm/cpu.rs:85`).
- `benchmarks/armv7-sha256.md` found that `OPENSSL_armcap=~0x10` does not deny aws-lc its SHA-256 instructions on Linux ARM32. Read aws-lc's 32-bit ARM capability detection for a way to deny it. If there is none, the row times rind alone: it has no ratio, and serves as the record and A/B host for [armv7's SHA](/quest/m3/cold-speed/armv7-sha.md).

For all three: add the column to `TIERS` (`admin/bench-report:765`), and extend `bench.yml`'s comment, which says what each row denies and why.

## Related

- [The nightly bench fails on a gap nobody decided](/quest/m2/bench/gate.md) - watches these rows once they exist
- [ARMv7 without the crypto extension runs the fastest SHA-256 and SHA-1](/quest/m3/cold-speed/armv7-sha.md) - measures on the armv7 row
