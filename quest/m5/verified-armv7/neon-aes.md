# [L] armv7's NEON AES is proven

## Goal

aws-lc's `bsaes-armv7` and `vpaes-armv7` NEON routines, which armv7 runs for AES and AES-GCM without the crypto extension, are proven on the AArch32 model against FIPS 197, and with `proofs/hol-light/armv7/gcm_init_neon.ml` and `gcm_ghash_neon.ml`'s GHASH proofs restated in Lean and composed with the Rust proofs of rind's AES-GCM, those operations earn the ✓ on that tier.

## Plan

Decided 2026-11-18 (maintainer, [kixel-ai/rind#619](https://github.com/kixel-ai/rind/pull/619#issuecomment-6994276361)): the proof of the NEON AES switch, which [kixel-ai/rind#913](https://github.com/kixel-ai/rind/pull/913) made, goes under this epic.

- Route: as [armv7's assembly](/quest/m5/verified-armv7/assembly.md) proves the other routines, against the FIPS 197 and SP 800-38D specs the x86_64 and aarch64 quests write, composed with the Rust proofs of rind's AES-GCM and mode glue.
- `ghash-armv4` is proven ([kixel-ai/rind#1088](https://github.com/kixel-ai/rind/pull/1088)); what remains of it is the Lean axioms restating `GCM_INIT_NEON_SUBROUTINE_CORRECT` and `GCM_GHASH_NEON_SUBROUTINE_CORRECT` for `NeonTable::new` and `NeonTable::ghash`, opaque in `Rind/Armv7/FunsExternal.lean`, and the bridge from the fork's `nist_ghash` to `Rind/GhashSpec.lean`.
- `admin/prove`'s `asm_routine` extracts each of `vpaes_armv7.rs`'s `global_asm!` routines by its symbol, as it does GHASH's: one `hol_light_proofs` entry and proof file per routine.
- Bitsliced AES needs a proof that its bit-sliced S-box circuit computes the S-box; vpaes's needs its permutation tables proven to compose to it. Look for an existing proof of either (s2n-bignum, Fiat, Jasmin) before writing one. The fork's `common/fips197.ml` has AES-128 and AES-256 only; rind's schedules include AES-192.
- Lessons from the GHASH proof: a NEON macro's leftover terms in scratch registers make each later step slower, so rename them to fresh variables between macros (its `FORGET_TAC`); name each Q register's initial value before a D-half write; and `BITBLAST_RULE` proves linear identities over 400 variables in seconds once nonlinear pieces are generalized to atoms.

## Related

- [armv7's AES-GCM in Rust](/quest/m5/verified-armv7/prove.md) - shares the SP 800-38D spec
