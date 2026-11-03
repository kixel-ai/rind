# [S] SDE constant-time checks cover VAES-AVX2 and the SHA extensions

## Goal

Every x86_64 path valgrind cannot execute gets a constant-time check under the SDE trace harness (`admin/ct-sde`): AES-GCM's VAES-AVX2 kernel, and SHA-1 and SHA-256 on the SHA extensions.

## Plan

Planned with the maintainer on 2026-11-03, from the findings of [moq-dev/rind#276](https://github.com/moq-dev/rind/pull/276). Valgrind 3.27.1 hides VAES, VPCLMULQDQ, and SHA from CPUID and cannot execute them, so ctgrind never reaches these paths on any runner.

- Let each `admin/ct-sde` case pick its SDE CPU model. VAES-AVX2 AES-GCM needs a chip with VAES but no AVX-512 (such as `-adl`), since `-spr` takes the AVX-512 path.
- Add an HMAC case with a secret key for SHA-1 and SHA-256 on the SHA extensions, plus an AES-GCM VAES-AVX2 case covering the bulk loop and the tail.
- Prove each new case catches a planted secret-dependent branch, and keep them in the nightly, not the gate.
- Fix the `ctgrind.yml` comments that say the `no-adx` row's VAES denial and the `no-avx` row's SHA denial matter under valgrind: those paths are already unreachable there.
