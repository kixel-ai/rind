# m2: later work

## Goal

Work that follows the release MoQ switches to: the speed and armv7 work that
does not block it.

## Required

- [Fastest at every algorithm](/quest/m2/speed/README.md) - every algorithm on every path as fast as any permissive source
- [x86_64 RSA wipes its heap exponent tables](/quest/m2/x86-heap-wipe.md) - match the heap-wipe rule the other backends follow
- [SDE constant-time checks cover every AVX-512 path](/quest/m2/sde-ct-avx512.md) - AES-GCM and ML-KEM join RSA under the SDE trace harness
