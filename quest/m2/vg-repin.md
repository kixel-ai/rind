# [L] rind re-pins pyca/verified-garbage past its audit fixes and clean-room rewrites

## Goal

`admin/import-vg`'s `REV` (and so `admin/import-vg-models`', rind-bench's, and every proof link's) moves from `0aa40d6c` to a VG commit at or past `7768cb5e` (its main on 2026-11-28), with rind's Lean proofs, `admin/prove vg`, `admin/prove bytes`, and the measured VG thresholds all holding on it.

## Plan

Found by the 2026-11-28 [upstream-updates](/quest/m2/upstream-updates.md) run, 1152 VG commits past the pin. Neither a GitHub advisory nor a live bug in code rind runs; the reasons to move:

- Licensing: VG's clean-room rewrites (#6493, #6494, #6496, #6498) replace aarch64 code that VG's own sources at the pin credit to OpenSSL's `p256-armv8-asm.pl`, s2n-bignum's P-384 Montgomery product and square, and mlkem-native's NTTs, which LICENSE's VG entry now names. Once the re-pin carries the rewrites, drop that note.
- Speed rind runs: aarch64 P-384 key generation and verification 12-14% faster (`28b03112`), RSA-3072 CRT on IFMA 1.28x (`5e1abb93`), aarch64 ML-KEM's Keccak 1.5-9.7% (`d2bf5d32`) and NTT about 2% (`d87bcd8e`), aarch64 P-256 1-3% (`9c7e771f`). Some regress: the x86_64 P-384 ADX verification's clean-room doubling about 1.5% slower (`3fc482c3`), aarch64 ChaCha20-Poly1305's shared kernels up to 1.7% (`ec91077e`, `096c2fe8`). Rerun rind-bench's VG thresholds, since nearly every routine's bytes moved.
- Hardening: 21 aarch64 roots and the two x86_64 AES-GCM roots are proven to return with no secret left in registers or stack; the audit fixes (#6397's stack-bound check, #6333's prepared AES-GCM wipe contract) change contracts' stated stack bounds and specs only.

What it takes:

- `admin/import-vg` exits 0 at VG's main but writes broken aarch64 output: `fb54a817` made `vg_p256_comb` and `vg_p384_comb` internal functions, which `module_of` maps to the files of the tables `VG_P256_COMB` and `VG_P384_COMB`, so `mod.rs` declares each module twice. Fix the mapping (and `admin/vg-bytes` if it shares it). All 41 VG names rind's Rust calls still exist; the closures grow from 128 to 143 files on x86_64 and 89 to 101 on aarch64. `admin/import-vg-models` reruns cleanly (32 of 143 modules change, none of the functional contracts rind's axioms restate).
- VG's main is on Lean 4.36.0 and Mathlib v4.36, which the copied models need, so `proofs/` moves from Lean 4.35.0 with its Mathlib and Aeneas; split that toolchain bump into its own quest if it grows past M.
- Proofs likely to break: `proofs/Rind/VgNist.lean`'s `fe_inv` (VG writes `inv` as `x ^ (p-2)` since `4607f424`), `proofs/verified-garbage/Cosim/ProgsX86_64.lean` and `Rind/X86_64/VgMlKem768Ct.lean` (`Impl/Scrub/X86_64` changed), `Cosim/Progs.lean` and `Rind/Aarch64/VgChaCha20Poly1305Ct.lean` (aarch64 ChaCha20-Poly1305 is now scrubbed whole), the ML-KEM contract's new `publicOut` argument (`2d73738f`), and possibly `RindIsa/*` and the proofs over `Isa`, which gained `ptrEq` fields.
- `admin/prove vg`'s cosimulation meets new x86_64 forms in rind's closure: `kxorw`, masked `vpaddq {k1}`, and `vpcmpequq`/`vpcmpnleuq` (`c448a508`), which `Cosim/X86_64.lean` parses by hand.
- Coordinate with any open PR that imports VG routines at the old pin: it reruns its import on the new one.
