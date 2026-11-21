# [M] ChaCha20-Poly1305 on x86_64 with AVX-512 earns the ✓ from pyca/verified-garbage's proof

## Goal

Every VG routine that ChaCha20-Poly1305 and XChaCha20-Poly1305 run on x86_64 with AVX-512 is imported as a theorem, so both AEADs earn the ✓ on the message lengths that run VG's code there.

## Plan

Decided 2026-11-21 (orchestrator, for the maintainer, in [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949)'s merge pick): ✅ keep this quest (rejected: drop it and record a reason in `benchmarks/gaps.toml`).

- Import each routine's VG theorem as one axiom about rind's opaque wrapper, under [the m4 epic's composition rule](/quest/m4/verified/README.md#composition-rule), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles. VG's ChaCha20-Poly1305 spec is already vendored under `proofs/verified-garbage/` for the aarch64 SVE2 one pass ([kixel-ai/rind#885](https://github.com/kixel-ai/rind/pull/885)).
- `proofs/Rind/X86_64/ChaCha20Poly1305.lean` already proves the AEAD API, the `mid` glue, and HChaCha20 down to the one-pass call, under the hypothesis `OnePass` ([the x86_64 epic](/quest/m4/verified/chacha20-poly1305-x86/README.md)). Discharge `OnePass` for the AVX-512 lengths from the imported theorems, and prove the length choice between VG's routine and aws-lc's.
- Add the `benchmarks/verified.toml` entries for the lengths and CPUs the switch covers. [aws-lc's seal and open](/quest/m4/verified/chacha20-poly1305-x86/aead.md) still owns the AVX2 and SSE4.1 tiers, and the AVX-512 lengths the switch leaves on aws-lc.
- If the switch runs OpenSSL's AVX-512 code at long lengths, those lengths are not this quest's: the switch's PR adds a quest under [the m4 verified epic](/quest/m4/verified/README.md) for a Lean proof of that assembly, as [aws-lc's seal and open](/quest/m4/verified/chacha20-poly1305-x86/aead.md) plans for aws-lc's.
- Model gaps follow the epic's rulings of 2026-11-17 ([kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815#issuecomment-6943056592)).

## Required

- [ChaCha20-Poly1305 on x86_64 with AVX-512 runs pyca/verified-garbage's code where it is faster](/quest/m2/verified-garbage/chacha20-poly1305-x86.md) - the routines this proves
