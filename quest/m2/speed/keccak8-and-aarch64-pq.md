# [M] ML-DSA samples on the 8-way AVX-512 Keccak-f

## Goal

On x86_64 CPUs with AVX-512, ML-DSA's matrix expansion and its secret and mask vector sampling permute eight Keccak-f states at once on the AVX-512 kernel ML-KEM's sampler already ships, wherever that measures faster than s2n-bignum's four-way AVX2 permutation, and within the rule [avoid-zmm](/quest/m2/speed/avoid-zmm.md) settles for cores that downclock.

## Plan

Planned with the maintainer on 2026-11-21 (`/quest-plan`): ✅ wire the existing 8-way AVX-512 Keccak into ML-DSA and SLH-DSA, add pipelined `aarch64` SHA-256 lanes, and port NEON ML-KEM compress/decompress (rejected: skip). [kixel-ai/rind#1036](https://github.com/kixel-ai/rind/pull/1036) landed aarch64's SHA-256 lanes and NEON ML-KEM compression, and left this one, which needs x86_64 hosts to measure. NEON decompression was not taken: it measured no faster than the proven Rust.

- The kernel is `_sha3_keccak8_f1600` in `rind/src/low/x86_64/mlkem_sample_poly_ntt_8x.rs`. Move it to a module of its own, and rotate with `_mm512_rol_epi64` (`vprolq`), one instruction, instead of its `sllv`, `srlv`, and `or`, which also speeds ML-KEM-1024's sampler.
- `mid::sha3::Shake4x` (ML-DSA's `Shake128x4` and `Shake256x4`) takes eight lanes where the kernel runs; `mid::mldsa` asks for up to eight polynomials at a time instead of four.
- Measure on `fedora` (Zen 5, full-width AVX-512) and on an Intel AVX-512 core if one is reachable: GitHub's hosted runners rarely draw AVX-512, so a dispatched `bench` may never time the path. Zen 4 splits 512-bit operations in two, so the gain there may be nil; keep the four-way path where it is not faster.
- ML-DSA's secret vectors come from a secret seed, so the 8-way path needs a `ct_sde_*` test under `admin/ct-sde`; valgrind decodes no AVX-512.
- SLH-DSA's SHAKE sets are [SLH-DSA SHAKE on x86_64](/quest/m4/pq/slh-dsa-shake-x86.md)'s, whose [kixel-ai/rind#872](https://github.com/kixel-ai/rind/pull/872) keeps four states transposed across calls on XKCP's AVX2 permutation and runs eight lanes on AVX-512 in its fork's follow-up.
- Dropped: keeping s2n-bignum's four-way AVX2 states transposed across permutations in `mid::sha3`. The transposition is inside s2n-bignum's proven routine, so removing it would void the proof, and #872 does it for SLH-DSA, where it pays.

## Related

- [Avoid 512-bit kernels on Intel cores that downclock for them](/quest/m2/speed/avoid-zmm.md)
- [SLH-DSA SHAKE on x86_64](/quest/m4/pq/slh-dsa-shake-x86.md) - owns SLH-DSA's SHAKE lanes on x86_64
