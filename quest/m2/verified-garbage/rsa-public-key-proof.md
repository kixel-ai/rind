# [S] RSA public-key setup keeps the ✓ on pyca/verified-garbage's precompute

## Goal

Where RSA public-key setup runs VG's `vg_rsa_public_precompute`, its theorem is imported, so RSA verification keeps the ✓ that [kixel-ai/rind#855](https://github.com/kixel-ai/rind/pull/855) gave it on AVX-512 IFMA, and every other ✓ that rests on rind's `pub_montifier`.

## Plan

Decided 2026-11-21 (orchestrator, for the maintainer, in [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949)'s merge pick): ✅ keep this quest (rejected: drop it and record a reason in `benchmarks/gaps.toml`).

- Import the routine's VG theorem as one axiom about rind's opaque wrapper, under [the m4 epic's composition rule](/quest/m4/verified/README.md#composition-rule), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles. VG's RSA routines are internal to VG, so the contract is in its proofs, as for the public operation `proofs/Rind/X86_64/VgRsa.lean` imports already.
- Replace the proof of `pub_montifier`'s result in the verification theorems with the imported one on the tiers the switch covers, and keep `pub_montifier`'s on the others.
- If [the switch](/quest/m2/verified-garbage/rsa-public-key.md) finds the gap in the DER parse instead and takes no VG routine, delete this quest.
- Model gaps follow the epic's rulings of 2026-11-17 ([kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815#issuecomment-6943056592)).

## Required

- [RSA public-key setup runs pyca/verified-garbage's precompute where it is faster](/quest/m2/verified-garbage/rsa-public-key.md) - the routine this proves
