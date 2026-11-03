# m2: later work

## Goal

Work that follows the release MoQ switches to: the speed and armv7 work that
does not block it.

## Required

- [Fastest at every algorithm](/quest/m2/speed/README.md) - every algorithm on every path as fast as any permissive source
- [SDE constant-time checks cover every AVX-512 path](/quest/m2/sde-ct-avx512.md) - AES-GCM and ML-KEM join RSA under the SDE trace harness
- [SDE constant-time checks cover VAES-AVX2 and the SHA extensions](/quest/m2/sde-ct-vaes-sha.md) - the x86_64 paths valgrind cannot run get SDE trace checks
