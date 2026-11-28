# [M] Cortex-A72 runs s2n-bignum's alt2 Keccak-f for lone states, if it measures faster

## Goal

On Cortex-A72 (the Raspberry Pi 4 and CM4), a lone Keccak-f1600 state runs s2n-bignum's proven `sha3_keccak_f1600_alt2` instead of `sha3_keccak_f1600`, if the A72 check in the Plan shows `main` still loses to aws-lc-rs on SHA3-256 there and `_alt2` closes it. Every other core keeps the routine it runs now, the SHA-3 ✓ keeps covering every core, and BENCHMARKS.md's numbers show no regression. If the check shows [kixel-ai/rind#884](https://github.com/kixel-ai/rind/pull/884) and [kixel-ai/rind#851](https://github.com/kixel-ai/rind/pull/851) already cover it, this quest's PR records the measurement in ALGORITHMS.md and deletes the quest.

## Plan

[steelhead99x/rind#223](https://github.com/steelhead99x/rind/pull/223) (`perf/a72-keccak-alt2`, a fork PR) carries the work. It was written against a base that has #884's four-way hybrid, but the evidence below predates a rerun on `main` with #851, so the first step is a measurement, not a merge.

Measured in #223, ns per permutation, median of 5 rounds, a standalone harness linking each routine:

| core | `sha3_keccak_f1600` | `_alt2` | aws-lc `KeccakF1600_hw` |
|---|---|---|---|
| Cortex-A72 (Pi 4) | 1322.5 | 884.9 | 867.0 |
| Cortex-A76 (Pi 5) | 389.0 | 484.0 | 444.9 |
| Cortex-A78AE (Jetson Orin) | 485.9 | 555.6 | 554.9 |

`_alt2` is 1.49x faster on the A72 and 1.24x and 1.14x slower on the A76 and A78AE, so only the A72 can take it. End to end on the Pi 4 (before = #223's base, after = its head, one pinned core, interleaved, median of 5, µs; the ratio is rind's time over aws-lc-rs's): SHA3-256 of 16 KB 163.14 to 110.27 (1.511x to 1.021x), of 32 B 1.444 to 1.013 (1.205x to 0.844x), ML-KEM-768 key generation 66.70 to 59.60 (1.069x to 0.954x), encapsulation 67.34 to 60.38 (1.012x to 0.907x), decapsulation 42.84 to 36.71 (0.581x to 0.496x).

Why #884 and #851 may not cover it: #884's hybrid takes four states at once, and #851 made SHA-3 run rind's code off Apple's cores, but the sponge absorbs and squeezes one state at a time (a SHA3-256 of 16 KB runs about 120 permutations, so 0.44 µs saved each is about 52 of the 55 µs gap to aws-lc-rs), and one to three states still run one at a time on the scalar routine. Why they might: if the "before" column above already included both, it is settled; if it was taken before #851 or #884 merged, `main` may differ.

Decision rule, measured on a Cortex-A72 at `main` and at #223's head merged with `main`, interleaved, one pinned core, a same-run aws-lc-rs baseline, `bench` run for `sha3` and `mlkem` only (`gh workflow run bench --ref <branch> -f benches='sha3 mlkem'` where a runner exists, else by hand on the Pi 4):

- Take it if, on the A72, SHA3-256 of 16 KB at `main` is at least 5% slower than with `_alt2`, and no ML-KEM-768 operation or SHA3-256 of 32 B gets slower. #223's numbers are 32%, 30%, and 10 to 14%.
- Refuse it, delete this quest, and record the numbers in ALGORITHMS.md's Keccak-f list if `main` is within 5% of `_alt2` on SHA3-256 of 16 KB: the weight of a MIDR-keyed dispatch, a second Lean branch, and an axiom is not worth less than that.
- Either way the A76 and A78AE rows stay as they are: neither runs `_alt2`.

If taken, #223's changes land as it carries them:

- `admin/parse-asm` imports `sha3_keccak_f1600_alt2` into `rind/src/low/aarch64/`. It is scalar base Armv8, compiled for the A72, and already vendored. s2n-bignum proves it correct (`SHA3_KECCAK_F1600_ALT2_SUBROUTINE_CORRECT`) and constant time (`SHA3_KECCAK_F1600_ALT2_SUBROUTINE_SAFE`), and `admin/prove bytes` checks rind's build against the proof. No unverified assembly is added. aws-lc's `keccak1600-armv8` is 2% faster on the A72 but unverified, so it is not taken.
- `cpu::keccak_alt2` picks it only when `MIDR_EL1` names Cortex-A72, cached, with `RIND_CPU_DISABLE_keccak_alt2` and `RIND_CPU_FORCE_keccak_alt2` as for the other overrides and `RIND_TEST_MIDR=a72` as a fixture. `sha3_keccak_f1600_mux` dispatches to it and `sha3_keccak_nof4_f1600` runs one to three states through that dispatch; four states keep #884's hybrid.
- Lean, so the ✓ keeps covering every core: an opaque `keccak_alt2` in `proofs/Rind/Aarch64/FunsExternal.lean`, its contract as an axiom in `proofs/Rind/Aarch64/Axioms.lean` and `S2nBignum.lean` restating s2n-bignum's `_alt2` theorem the way the existing Keccak axioms do, and a branch in `KeccakDispatch.lean`. `admin/prove lean` must pass and the axiom list must grow by that one contract only.
- `admin/ctgrind` forces `_alt2` in its narrow pass and each pass asserts which kernel ran (`detects_the_expected_cpu`). ct-qemu and BINSEC do not force it; ctgrind covers it because valgrind runs it natively on an A72.
- ALGORITHMS.md's Keccak-f list, PLATFORMS.md, and BENCHMARKS.md say the A72 runs it, with the table above.

## Waiting

- steelhead99x: the A72 check, on the Raspberry Pi 4 they hold, since an agent has no A72 host. Options: (A) run the decision rule's interleaved `main` against #223-merged-with-`main` comparison and post both tables in the quest's PR; (B) lend the maintainer SSH access to the Pi 4 for the run; (C) skip the check and take #223's numbers as they stand. Recommendation: A, because #223's base is not `main` and the rule needs the `main` column; C risks landing a dispatch that #884 and #851 already made redundant. Check: the PR body holds the two tables.
- Maintainer: confirm the 5% threshold and the A72-only scope once the check is in. Options: (A) take the rule as written, `_alt2` on Cortex-A72 only; (B) a higher bar of 10% on SHA3-256 of 16 KB, trading the 52 µs of #223's gap for less dispatch code; (C) widen to other cores without the SHA3 instructions that #223 did not measure, such as the Cortex-A53, after a measurement on each. Recommendation: A, as the Pi 4 is the one core whose lone-state gap to aws-lc-rs is measured, and every other row in #223's table is slower with `_alt2`.

## Related

- [aarch64 without the crypto extension is proven](/quest/m5/verified/aarch64-no-crypto.md) - the other A72-specific proof work
