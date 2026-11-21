# [M] AES-GCM on x86_64 with AVX-512 earns the ✓ from pyca/verified-garbage's proof

## Goal

Every VG routine that AES-GCM runs on x86_64 with AVX-512 is imported as a theorem, so AES-GCM earns the ✓ there at the directions and lengths that run VG's code.

## Plan

- Import each routine's VG theorem as one axiom about rind's opaque wrapper, under [the m4 epic's composition rule](/quest/m4/verified/README.md#composition-rule), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles, and vendor VG's AES-GCM spec into `proofs/verified-garbage/` with `admin/import-vg-models`.
- Prove rind's glue around it, with the length choice between VG's kernel and rind's by-16 and by-8 intrinsics, which `proofs/Rind/X86_64/AesGcmAvx512.lean` already proves below 2 KB given the key-power predicates.
- VG's spec and the two GCM specs rind's x86_64 proofs already use (Vale's, and s2n-bignum's that [the VAES quest](/quest/m4/verified/aes-gcm-x86-vaes.md) proves against) must meet: prove VG's equal to whichever the glue's theorems state, or reuse that quest's equivalence theorem if it lands first.
- Add the `benchmarks/verified.toml` entries for the lengths and CPUs the switch covers.
- Model gaps follow the epic's rulings of 2026-11-17 ([kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815#issuecomment-6943056592)).

## Required

- [AES-GCM on x86_64 with AVX-512 runs pyca/verified-garbage's code where it is faster](/quest/m2/verified-garbage/aes-gcm-avx512.md) - the routines this proves
