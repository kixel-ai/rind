# [M] rind imports pyca/verified-garbage's leakage contracts, and retires the harnesses they cover

## Goal

The SDE and QEMU trace harnesses of the VG routines whose leakage rind states as an axiom are retired, each once its wrapper keeps a trace check of its own, and VG's P-256 IFMA ECDH on x86_64 gets its leakage axiom too.
aarch64 SVE2 ChaCha20-Poly1305 (`Rind.Aarch64.VgChaCha20Poly1305Ct`), x86_64 ML-KEM-768 (`Rind.X86_64.VgMlKem768Ct`), and x86_64 P-256 IFMA ECDH (`Rind.X86_64.VgP256Ct`) state VG's `ConstantTime` of VG's own `Prog`, with `admin/vg-bytes --progs` binding that `Prog`'s printed text to VG's assembly and rind's bytes. P-256's `Impl/` closure is vendored but for its two tables of points, which `admin/import-vg-models --tables` writes and checks are VG's byte for byte.
ML-KEM-768's and P-256 ECDH's wrappers are done: `mid::mlkem::ct_binsec_mlkem768_vg` and `low::x86_64::p256_vg::ct_binsec_p256_ifma_ecdh` check them under BINSEC with each AVX-512 routine stubbed by its contract (`admin/ct-binsec`'s `CONTRACTS`), the tests forcing the CPU checks through `cpu::force_vg_contracts`, and `ct_sde_mlkem768` and `ct_sde_p256_ifma_ecdh` are gone.

- What remains is the wrapper of `ct_qemu_chacha20poly1305` on aarch64, which gains a BINSEC region over its Rust the same way: the test forces the CPU check that picks the SVE2 routines, and `CONTRACTS` lists each routine's outputs, which the BINSEC stub fills with fresh secrets, and the inputs its contract leaks, which the stub branches on (open's is only whether it returns 1); gdb's native run returns success without writing them. Seal and open take the message and AAD lengths as arguments, which `CONTRACTS` cannot yet say (its stub loads through every argument and writes outputs of fixed size), so the region extends it with length arguments and outputs sized by them.
- That PR removes the SVE2 cases of `ct_qemu_chacha20poly1305`, never before the region runs green, and TESTING.md's constant-time column cites the axioms and the region instead. The NEON seal and open, which the axioms do not cover (they state SVE2 only) and BINSEC cannot yet check, keep their QEMU cases until a replacement covers that assembly. The region needs `ubuntu-24.04-arm` or another aarch64 Linux host with BINSEC to run, since `admin/ct-binsec` runs the test natively under gdb.

## Hosts

- linux - `admin/ct-binsec` runs the aarch64 region's test natively under gdb, so on aarch64 Linux with BINSEC, such as `ubuntu-24.04-arm` with nix

## Plan

Follow-up from the 2026-11-18 /quest-plan on independence and Lean, which settled with the maintainer: ✅ once a routine's leakage contract is proven in Lean, its dedicated trace harness is retired, and ctgrind keeps running every test (rejected: keep every harness). Kept as a follow-up by the maintainer on 2026-11-18, on [kixel-ai/rind#893](https://github.com/kixel-ai/rind/pull/893): ✅ keep (rejected: drop).

- How each leakage axiom names the routine's code. Decided 2026-11-21 (maintainer, /quest-plan): ✅ VG's own `Prog`, from its vendored `Impl/` closure, with the link to rind's bytes resting on VG's vendored printer (rejected: rebuilding each `Prog` from VG's printed assembly with `Cosim/`'s parser; an opaque `Prog` constant per routine).
- The retained trace check for each wrapper whose SDE or QEMU harness retires. Decided 2026-11-21 (maintainer, /quest-plan): ✅ a BINSEC region over each wrapper's Rust, with the VG routine stubbed by its contract (rejected: adding AVX-512 and SVE2 decoders to BINSEC; ctgrind alone for the part of each wrapper valgrind runs; never retiring the harnesses). BINSEC decodes the wrappers' Rust but not VG's AVX-512 or SVE2 code, which the axiom covers instead.
- Retire a `ct_binsec_…` region only when it covers VG code alone.
- A contract's declared leakage must be public in rind's call too. Checked at VG `0aa40d6c`: ML-KEM-768's `leakRho` is `ρ`, which is in the encapsulation key; P-256 ECDH's `leak` is the peer's public key bytes; ChaCha20-Poly1305 open's `openLeak` is whether it returns 1, which rind returns. Recheck when the VG pin moves.
- The axioms need the cosimulation `admin/prove vg` runs for these instructions. The stack-slot model gap recorded in [the epic](/quest/m2/verified-garbage/README.md) holds back only the routines it holds back there.
