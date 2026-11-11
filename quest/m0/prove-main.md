# [S] The proof checks pass on main again

## Goal

`admin/prove` passes on `main`, so the `lean` and `hol-light` jobs of `prove.yml` go green on main's nightly and on every PR. Today both fail on main for reasons no PR touches, which hides real proof breakage behind a red check everyone ignores.

## Plan

Planned with the maintainer on 2026-11-10 as a follow-up of [moq-dev/rind#584](https://github.com/moq-dev/rind/pull/584) and [moq-dev/rind#564](https://github.com/moq-dev/rind/pull/564): ✅ m0, since m0 owns a failing `main` (rejected: m2/verified).

- **`lean`:** `admin/prove` refuses intrinsic models that no vector tests: `admin/prove: no vectors test these intrinsic models:` followed by the `core.core_arch.x86.*` AES, PCLMULQDQ, SSE2, and SSSE3 models (`_mm_aesenc_si128`, `_mm_clmulepi64_si128`, `_mm_shuffle_epi8`, and the rest the message names). [moq-dev/rind#588](https://github.com/moq-dev/rind/pull/588) added the vector check and those models are not covered by `admin/simd-vectors.rs`. Give each one vectors that run against the CPU, as #588 did for the others.
- **`hol-light`:** `admin/prove-bytes: ALGORITHMS.md's inventory is stale; admin/prove-bytes inventory .tmp/prove/bytes prints it`. Regenerate the inventory, and check the diff it prints against what main's proofs actually cover before committing it.
- Caused by: #588 for the vectors. Name the PR that left the inventory stale under `## Caused by` once the inventory diff points at it.
