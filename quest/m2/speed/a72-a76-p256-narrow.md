# [M] Cortex-A72 and Cortex-A76 run rind's own P-256 key generation, ECDH, and signing, if they measure faster

## Goal

On Cortex-A72 (Raspberry Pi 4) and Cortex-A76 (Raspberry Pi 5), P-256 key generation, ECDH, and ECDSA signing run rind's own s2n-bignum routines, which measure faster there than pyca/verified-garbage's, and every other aarch64 core keeps VG's. Verification keeps VG's routine, and the aarch64 P-256 ✓ keeps covering every core. If the check in the Plan does not show the win at `main`, this quest's PR records the measurement in ALGORITHMS.md and deletes the quest.

## Plan

`main` takes VG's P-256 routines on every aarch64 core (`low/aarch64/p256_vg.rs`: "they measured faster than rind's on every aarch64 CPU"). [steelhead99x/rind#141](https://github.com/steelhead99x/rind/pull/141) (`perf/p256-keygen-aarch64`, a fork PR) carries the work and measured that claim false on the two Raspberry Pi cores. It began as "close the 1.05x keygen gap" and became a core-keyed selection; it merges `main` at `c9304441`, so the first step is to rerun its A/B at `main` now.

The gap, from the fork's sweep of `main` (rind over aws-lc-rs, Pi 5, Cortex-A76): P-256 keygen 1.05, ECDSA keygen 1.08, ECDH 1.32 (stored key 1.39). `benchmarks/gaps.toml` has no entry for it because it covers the hosts in `benchmarks/data` (`desktop`, `kixtop`, `nixos`, `ovh-iad`, `ovh-sea`) and the weekly CPU tiers, and no Raspberry Pi is one of them, so this gap shows only in the fork's own runs.

Measured in #141, microseconds, median of per-round medians, one pinned core, a stand-alone harness with rind and aws-lc-rs 1.19 in one process, interleaved, the clock read before and after each run:

| core | op | VG | rind's own | rind's own over VG | aws-lc-rs |
|---|---|---:|---:|---:|---:|
| A76 (Pi 5, 5 rounds) | keygen | 45.24 | 37.67 | 0.833 | 43.1 |
| A76 | ECDSA keygen | 46.45 | 38.89 | 0.837 | 43.2 |
| A76 | ECDH | 282.3 | 201.3 | 0.713 | 213.8 |
| A76 | ECDSA sign | 53.67 | 46.12 | 0.859 | 75.7 |
| A76 | ECDSA verify | 247.6 | 247.4 | 1.000 | 256.8 |
| A72 (Pi 4, 7 rounds, 1.8 GHz `ondemand`, no sudo so the governor was not pinned) | keygen | 44.6 | 41.3 | 0.927 | 53.1 |
| A72 | ECDH | 264.9 | 229.1 | 0.865 | 251.8 |
| A72 | ECDSA sign | 65.8 | 61.9 | 0.940 | 87.2 |
| A72 | ECDSA verify | 228.3 | 228.5 | 1.001 | 249.8 |

Own routines win keygen, ECDH, and sign in every one of the 7 A72 rounds, and verify is unchanged because it keeps VG's. On the Jetson Orin Nano's Cortex-A78AE the wide path is untouched and already 0.945 for keygen, 0.749 for ECDH. Neoverse N1 and N2 were never timed by #141 and stay on VG; the published N2 tier cell (1.01 and 1.04) is from older code.

Decision rule, measured at `main` and at #141's head merged with `main`, interleaved, one pinned core, a same-run aws-lc-rs control (a round whose control moved more than 2% is dropped), on an A72 and an A76:

- Take it, for that core, if keygen, ECDH, and sign are each at least 5% faster than at `main` and verify is no more than 2% slower. #141's numbers are 7 to 29%.
- Refuse it for a core where any of the three is within 5%: a core-keyed dispatch, a second Lean branch, and a second proof surface are not worth less than that. Delete this quest if neither core passes, and record the numbers in ALGORITHMS.md's P-256 note.
- A core nobody timed (Neoverse N1, Cortex-A53, Cortex-A55) keeps VG. Widening the list is its own measurement, never an inference from these two.

If taken, #141's changes land as it carries them:

- `cpu::narrow_p256_core` reads `MIDR_EL1` and names part 0xd08 (A72) and 0xd0b (A76), cached, with the `RIND_CPU_*` override and fixture the other cores use. `p256_vg.rs` keeps VG for verification and everywhere else; keygen, ECDH, and signing take s2n-bignum's `p256_scalarmulbase` and `p256_scalarmul` on those two cores.
- No assembly is added: both routines are already imported and are s2n-bignum's proven ones, so `admin/prove bytes` has nothing new to check, but #141 did not run it on this selection. Run it.
- Lean, so the ✓ keeps covering every core: `P256.check_ecdh` is declared in `proofs/Rind/{Aarch64,X86_64}/FunsExternal.lean`, `NoVgP256` gains it, and `diffie_hellman_spec` uses `hvg.eq_ecdh`. `admin/prove lean` must pass (3735 jobs at #141's head) and the axiom list must not grow.
- `.cargo/mutants.toml` excludes `check_ecdh`'s equivalent mutant and re-pins `cpu_forced`; `admin/mutants --pins` passes.
- `admin/ctgrind` runs the selection in a forced pass and asserts which routine ran. #141 did not run ctgrind on it: the narrow routines were ctgrind-run when imported, but the new selection was not, and Valgrind runs on the Pi 5 and Pi 4 natively. Run it there.
- ALGORITHMS.md's P-256 note, PLATFORMS.md, and BENCHMARKS.md say which cores take which routines, with the table above.

## Waiting

- steelhead99x: rerun #141's A/B at current `main` on the Pi 4 and Pi 5 they hold, since the numbers above are against `c9304441`, and run `admin/ctgrind` and `admin/prove bytes` on the selection, which #141 did not. Options: (A) rerun both cores, interleaved as the rule says, and post the tables in the quest's PR; (B) give the maintainer SSH access to the Pis; (C) skip the rerun and take #141's numbers. Recommendation: A, because `main` has moved since `c9304441` and the rule needs a `main` column; C risks landing a selection that a later VG change already made redundant. Check: the PR body holds the two tables and the ctgrind and `prove bytes` results.
- Maintainer: confirm the 5% bar and the two-core scope once the rerun is in. Options: (A) the rule as written, A72 and A76 only; (B) a 10% bar, which still passes every op measured here except A72 keygen (7.3%) and sign (6%); (C) also time Neoverse N1 (Graviton 2, Ampere Altra), where `main` keeps VG, and widen to it if it passes. Recommendation: A, since each core is added only on its own measurement, and N1 is not in hand.

## Related

- [aarch64 without the crypto extension is proven](/quest/m5/verified/aarch64-no-crypto.md) - the other A72-specific proof work
