# [L] aarch64 SHA-256 on the SHA-2 instructions is proven in Lean, constant time included

## Goal

`low::aarch64::sha256::sha256_block_data_order_hw`, as rind's release build emits it, is proven in Lean on pyca/verified-garbage's aarch64 model to compute the FIPS 180-4 block function, with a leakage contract: its trace of addresses and branches depends only on its public inputs. `Rind/Aarch64/Sha256Hw.lean` derives `compress_hw`'s contract from that theorem, and `proofs/hol-light/aarch64/sha256_block_data_order_hw.ml` is deleted along with its entry in `admin/prove`'s `hol_light_proofs`. The PR body measures the Lean proof against the HOL Light one and recommends a route for each m4 child waiting on it.

## Plan

Decided with the maintainer on 2026-11-18 (/quest-plan):

- ✅ rind's new assembly proofs go in Lean, on VG's models, after this trial measures the cost (rejected: keep HOL Light for assembly; VG's models with HOL Light kept forever; LNSym or cslib-community/bignum, which are aarch64-only or partial and outside today's trust base). This reverses the 2026-11-07 decision in [the m4 epic](/quest/m4/verified/README.md) that new assembly proofs go in HOL Light. Lean is the default route; the trial's PR may recommend HOL Light for a waiting child only where its measurements show Lean impractical for that routine, and the maintainer decides each such exception. Why: one kernel checks the whole chain, with no restated theorem at the HOL–Lean seam, and VG's models are already vendored and cosimulated by `admin/prove vg`, so the trust base does not grow.
- ✅ The trial routine is aarch64 SHA-256 (rejected: `ct_compare_16`, too small to show how a real kernel goes; an unproven m4 routine, which leaves nothing to compare against). HOL Light's calibration proved this same routine in [kixel-ai/rind#552](https://github.com/kixel-ai/rind/pull/552), so the two proofs compare directly. VG's aarch64 model already has `sha256h`, `sha256h2`, `sha256su0`, and `sha256su1`.
- ✅ Constant time is proven for the assembly, in VG's style (`VerifiedGarbage/TCB/Artifact.lean` and `Code.lean`: runs from states that agree on public data leave identical leakage traces). The contract covers addresses and branches; that `sha256h` and the other instructions take data-independent time is assumed as [`PLATFORMS.md`](/PLATFORMS.md) states rind's DIT policy, outside the proof (rejected: functional only; a Charon taint pass for the Rust, which sees neither the assembly nor compiler-inserted branches, and which BINSEC already covers on the binary). ctgrind, BINSEC, and `admin/ct-vartime` keep checking the Rust and the final binary.
- ✅ Once a routine's leakage contract is proven, its dedicated trace harness (`ct_sde_…`, `ct_qemu_…`, or `ct_binsec_…`) is retired (rejected: keep every harness). Here that means the aarch64 SHA-256 regions, if any harness covers them. ctgrind keeps running every test.

Guidance:

- Prove the bytes rind's build emits, as the HOL Light proofs do: load the object `admin/prove` already extracts into VG's model, and fail unless the build's bytes are the ones the proof lists. VG's own decoder and `admin/vg-bytes` are the tools at hand.
- `admin/prove vg` cosimulates only the instructions VG's code uses. Extend it to every instruction this proof's routine runs, such as the round constants' loads, so each model rind's proof relies on is checked against hardware.
- Keep the FIPS 180-4 spec rind's Lean already uses (`Rind/HashSpec.lean` or `Rind/S2nSha256.lean`), so `Sha256Hw.lean`'s consumers don't change.
- `compress_hw` stays opaque to Aeneas, so the step from the naked function's theorem to the wrapper is still trusted. Shrink it to an ABI bridge under [the composition rule](/quest/m4/verified/README.md#composition-rule): one axiom that `compress_hw` returns what VG's model computes when run on the extracted bytes with the wrapper's arguments in the ABI's registers, as the VG wrappers' restatements do, and prove the FIPS 180-4 result from it in Lean. `Axioms.lean`'s pin then names that bridge instead of the HOL Light restatement; the PR says what it trusts.
- Measure and report in the PR body: proof lines and agent effort for each, Lean's check time in CI against `hol-light-aarch64`'s share for this file, and anything VG's models or automation lacked. From that, recommend a route, Lean or HOL Light, for each m4 child below that waits on this quest, and a size for [the m5 port](/quest/m5/verified/hol-light-to-lean.md).
- Proofs already in flight in HOL Light land as they are, and the m5 port picks them up: [kixel-ai/rind#636](https://github.com/kixel-ai/rind/pull/636) (x86_64 SHA-256 on AVX2) and [the AES-CTR and AES-CBC quest](/quest/m4/verified/aes-modes.md), whose CBC proof is half done. The unstarted m4 children that planned new HOL Light list this quest under `Required`.

## Related

- [Every rind path is proven, with the smallest trust base](/quest/m4/verified/README.md) - the epic whose rule this changes
- [rind's HOL Light proofs are ported to Lean](/quest/m5/verified/hol-light-to-lean.md) - sized by this trial
