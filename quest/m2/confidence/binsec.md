# [L] BINSEC checks the secret paths no proof covers

## Goal

Nightly, [BINSEC](https://github.com/binsec/binsec)'s constant-time mode checks rind's x86_64 and aarch64 Linux release binaries on every secret-handling path that no constant-time proof covers. It explores every value of the secret, up to its loop bounds, and fails on a branch, memory address, or variable-time instruction that depends on one. Those paths are rind's own Rust, such as RSA's padding checks, ML-KEM's compare, x86_64's AES-GCM intrinsics, and the portable backend forced on x86_64, the aws-lc and BoringSSL assembly rind imports with no proof, and the s2n-bignum routines whose proof is of correctness alone, such as aarch64's X25519. Code BINSEC cannot decode stays with `admin/ct-sde` and `admin/ct-qemu`. TESTING.md lists the check in each primitive's constant-time cell.

ctgrind sees only the paths the tests run, and `admin/ct-sde` and `admin/ct-qemu` compare the traces of just two secrets. BINSEC explores every path its harness's symbolic inputs reach, for every secret, on the compiled binary, so it also catches a branch the compiler adds on a path no test takes.

## Plan

Decided with the maintainer on 2026-11-09:
- Scope: the secret paths no constant-time proof covers ✅ (rejected: every secret path, s2n-bignum's proven routines included; one primitive first). s2n-bignum proves routines constant-time in HOL Light, and `admin/prove bytes` checks that those proofs cover rind's bytes.
- Milestone: m3, in the confidence epic ✅ (rejected: m4's assurance epic). The epic's active work then moved to m2 the same day, this quest with it ✅ (rejected: redefine m3, move only the security check).

Found by the 2026-11-09 audit:
- That scope includes s2n-bignum routines, which the Goal first left out. s2n-bignum's constant-time theorems (`_SAFE`) cover the functions AWS-LC uses, with the rest planned ([SOUNDNESS.md](https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/SOUNDNESS.md#L99-L109)), and rind runs some it does not. At rind's pin, aarch64's [`curve25519_x25519_alt.ml`](https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/arm/proofs/curve25519_x25519_alt.ml) and [`curve25519_x25519base_alt.ml`](https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/arm/proofs/curve25519_x25519base_alt.ml) define no `_SAFE` theorem, though `proofs/Rind/Aarch64/S2nBignum.lean:27` and `:35` cite their correctness theorems for the X25519 rind runs there; the `_byte` variants and x86_64's X25519 files have one. x86_64's `mlkem_ntt.ml`, `mlkem_intt.ml`, `mlkem_basemul_k3.ml`, `bignum_kmul_16_32.ml`, and `bignum_kmul_32_64.ml` define none either, though aarch64's `mlkem_ntt.ml` and `bignum_kmul_16_32.ml` do.
- The harness list comes from ALGORITHMS.md's inventory of s2n-bignum's `_SAFE` theorems, which `admin/prove bytes` keeps current, rather than a second survey: a harness for every s2n-bignum routine it finds no `_SAFE` theorem for, and none for a routine it finds one for. Where a variant with a theorem exists, such as X25519's `_byte` ones, measure it first: switching is cheaper than a harness if it is as fast at every size.
- Open question, armv7: BINSEC ships an ARMv7 lifter ([`src/isa/armv7`](https://github.com/binsec/binsec/tree/master/src/isa/armv7)), but nobody has run it on rind's armv7 build, so what it decodes there is unknown. No proof covers any armv7 path, so every secret path there falls in this scope if it decodes them. Try it on one armv7 harness, then ask the maintainer: add armv7 to the nightly job (recommended if it decodes aws-lc's NEON and crypto-extension assembly), or record armv7 as left to ctgrind and `admin/ct-qemu` with the reason.

Guidance:
- It runs nightly in its own workflow job, not in `just ci`, which `AGENTS.md` keeps for fast checks. Package BINSEC in its own Nix dev shell, as `.#ctgrind` and `.#sde` are.
- Call binsec directly, as rscrypto's [`scripts/ct/binsec.py`](https://dev.to/loadingalias/rscrypto-v040-verifying-constant-time-behavior-instead-of-assuming-it-1p2k) does on x86_64 and aarch64. [cargo-checkct](https://github.com/tarcieri/cargo-checkct) handles only `no_std` code, has no aarch64 target, and cannot follow rind's runtime CPU dispatch.
- Each harness takes one backend path, as ctgrind's feature denials do, marks the secret inputs symbolic, and the public ones, such as lengths, symbolic too where the search stays tractable.
- A planted leak, like `admin/ct-sde`'s and `admin/ct-vartime`'s, must be found, so a harness that checks nothing fails.
- Keep `admin/ct-vartime`, though BINSEC 0.10 also flags variable-time instructions: it scans every function rind reaches, the standard library included, in seconds, where BINSEC sees only what its harnesses call.
- TESTING.md records the limits: loops are explored only to a bound, and BINSEC's lifter merges a branch whose two sides are empty, so it misses a secret branch of that shape ([arXiv 2501.04183](https://arxiv.org/abs/2501.04183)).

## Related

- [TESTING.md's tiers table](/TESTING.md#tiers) - the test-based checks on the tiers BINSEC cannot decode
