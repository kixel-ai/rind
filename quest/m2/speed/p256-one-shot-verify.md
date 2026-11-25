# [S] P-256 verification with a key used once costs no more than aws-lc-rs's on rind's own arithmetic

## Goal

Where rind verifies P-256 ECDSA on its own arithmetic (x86_64 without BMI2 and ADX, armv7, and the portable backend), verifying with a key parsed for that one call, as `UnparsedPublicKey` and rustls do, takes no more than aws-lc-rs's time, while a key parsed once and reused keeps its cached table.

## Plan

Found by the 0.4 report refresh ([kixel-ai/rind#991](https://github.com/kixel-ai/rind/pull/991)) in the weekly bench's `no ADX` tier ([run 44941104585](https://github.com/kixel-ai/rind/actions/runs/44941104585), a Xeon 6975P with ADX denied): one-shot verification took 52.1 µs against aws-lc-rs's 45.3 (1.15×), while the same key parsed once took 46.4 against 44.4 (1.04×), so about 5.7 µs of rind's one-shot time is per-key setup, and the other 2 µs is rind's parsed time.

Both ideas the quest first named were built and benched (`gh workflow run bench -f benches=p256` on a branch each, [Jacobian](https://github.com/kixel-ai/rind/actions/runs/45603803770), [w4](https://github.com/kixel-ai/rind/actions/runs/45620467499)); neither beats the current code, so neither is worth its Lean proof work:

- Keeping P, 3P, ..., 15P Jacobian and adding them with `p256_montjadd` skips the inversion and the batch conversion (an estimated 3.7 µs) but costs more per addition than it saves: each of the ~43 P-digit additions pays a full rather than a mixed addition, and the equal-or-opposite check `public_add_affine` runs before each addition needs two squarings and two multiplications for two Jacobian points, against one each for a Jacobian and an affine point. No-ADX one-shot went from 52.07 to 53.24 µs (1.147× to 1.172× aws-lc-rs); it won only on x86_64's generic portable tier (118 to 107 µs, on different Xeons) and was flat on armv7 (342 to 343 µs) and aarch64.
- A width-4 table for a key used once (P, 3P, 5P, 7P) saves about 1.6 µs of setup and pays 8 more P-digit additions: 51.94 µs on the no-ADX tier (1.142×), within noise of the current code.
- An ideal Jacobian path with no exceptional-input check at all, which is not correct, breaks even by the same operation counts (an estimate, not a measurement), so the setup alone cannot close the 6.7 µs gap.

What does move the numbers is the exceptional-input check itself, which every mixed addition of the parsed path pays too: `public_add_affine` and the new Jacobian addition cost 2 to 4 field operations of 11 to 16 on all ~80 additions. A branch that adds first and checks only when the sum's `z` is zero (`p256_montjmixadd` and `p256_montjadd` compute `z3 = z1·(z2·)H`, so equal or opposite inputs, where H is zero, always give `z3 = 0`; the check then decides double or infinity as now), together with the Jacobian one-shot table, measured on [this run](https://github.com/kixel-ai/rind/actions/runs/45620616790): armv7 (always Neoverse-N2) 0.640× to 0.614× aws-lc-rs one-shot and 0.579× to 0.563× parsed, x86_64 generic 0.676× to 0.627× and 0.587× to 0.574×, and the no-ADX tier's one-shot 1.054× and parsed 0.944×, on an EPYC 9V74 the runner drew instead of the Xeon 6975P, so not comparable with the 1.147× above. Redo that comparison, on the same CPU, before trusting it.

Open design:

- The post-check relies on the s2n-bignum routines' behavior for equal and opposite inputs, which their specs leave unspecified and the HOL Light proofs do not cover: `z3` is zero when `H` is. Every backend (x86_64 assembly with and without ADX, aarch64, armv7, portable Rust) passes `twin_multiply_exceptional` with it today, but the guarantee is by reading the routines, not by proof. Recommendation: take it, add a differential test of each routine on equal and opposite inputs for every backend, and state the argument next to the check; the alternative is to keep the proven pre-check and give up the 3% to 5%.
- `proofs/Rind/X86_64/P256Ecdsa.lean` proves `public_add_affine`, `public_twin_multiply`, `public_odd_multiples`, and `raw_ecdsa_verify` through Aeneas; each change above needs those proofs updated, which only the `prove` workflow (Linux, x86_64 with AVX2) can check, so dispatch it on the branch.
- `mid/p384.rs` and `mid/p521.rs` build their odd multiples the same way on a key's first use; apply what lands here to them in the same PR if it measures.

Bench `p256` on the no-ADX tier, armv7, and the portable tiers before and after, always comparing runs that drew the same CPU (the job summary prints it). `ovh-iad` and `ovh-sea` (Haswell, no ADX) were not reachable over SSH from the Mac mini that ran the first attempt.

## Waiting

- Maintainer: whether verification may rely on `z3 = 0` for equal or opposite inputs to `p256_montjmixadd` and `p256_montjadd`, which their proofs do not state. Take it (recommended: 3% to 5% on armv7 and portable, probably more on no-ADX, closing most of the one-shot gap with a differential test per backend), or keep the proven pre-check and delete this quest, since no setup-only change helps. Check: the answer recorded in the Plan.
