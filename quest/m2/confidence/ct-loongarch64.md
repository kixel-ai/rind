# [M] The portable backend's secret branches are checked on loongarch64

## Goal

rind's portable backend built for `loongarch64-unknown-linux-gnu` gets a nightly constant-time check that fails on a branch or memory address that depends on a secret, as `ctgrind.yml`'s `portable-targets` jobs check i686, s390x, riscv64gc, and PowerPC with valgrind. Any branch it finds is fixed in its PR.

## Plan

Split from [ct-portable-targets](/quest/m2/confidence/ct-portable-targets.md), which checks every other portable target valgrind runs: valgrind (through 3.27) has no LoongArch port (UPSTREAM.md, "Valgrind has no LoongArch port").

- Recommended: extend `admin/ct-qemu` with `qemu-loongarch64`, whose plugin is already architecture-neutral, and add `ct_qemu_*` tests for the portable backend, gated on `rind_backend = "portable"`. ct-qemu compares two seeds' traces, so it misses a branch both seeds steer the same way: each test picks secrets that drive every branch-prone idiom both ways, such as a carry or borrow set and clear, zero and nonzero coefficients, and a sign mask set and clear. Cover what the portable backend runs on a secret: the NIST field and scalar arithmetic, hash-to-curve, X25519 and Ed25519, `aes_nohw` and `ghash_nohw`, Poly1305, ML-KEM, ML-DSA, SLH-DSA, and RSA.
- Alternative: wait for a valgrind LoongArch port, then add `loongarch64` to `flake.nix`'s `portable` set and the `portable-targets` matrix; nothing else changes.
- The same `ct_qemu` tests would also check what valgrind cannot run elsewhere, such as ARMv5TE (`arm-linux-androideabi`), which is not worth a quest of its own.
