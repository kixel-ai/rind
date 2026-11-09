# [L] BINSEC checks the secret paths no proof covers

## Goal

Nightly, [BINSEC](https://github.com/binsec/binsec)'s constant-time mode checks rind's x86_64 and aarch64 Linux release binaries on every secret-handling path that no constant-time proof covers. It explores every value of the secret, up to its loop bounds, and fails on a branch, memory address, or variable-time instruction that depends on one. Those paths are rind's own Rust, such as RSA's padding checks, ML-KEM's compare, x86_64's AES-GCM intrinsics, and the portable backend forced on x86_64, and the aws-lc and BoringSSL assembly rind imports with no proof. Code BINSEC cannot decode stays with `admin/ct-sde` and `admin/ct-qemu`. TESTING.md lists the check in each primitive's constant-time cell.

ctgrind sees only the paths the tests run, and `admin/ct-sde` and `admin/ct-qemu` compare the traces of just two secrets. BINSEC explores every path its harness's symbolic inputs reach, for every secret, on the compiled binary, so it also catches a branch the compiler adds on a path no test takes.

## Plan

Decided with the maintainer on 2026-11-09:
- Scope: the secret paths no constant-time proof covers ✅ (rejected: every secret path, s2n-bignum's proven routines included; one primitive first). s2n-bignum's routines are proven constant-time in HOL Light, and [asm-bytes](/quest/m3/verified/asm-bytes.md) makes those proofs cover rind's bytes. Until it lands, ctgrind still checks them.
- Milestone: m3, in the confidence epic ✅ (rejected: m4's assurance epic).

Guidance:
- It runs nightly in its own workflow job, not in `just ci`, which `AGENTS.md` keeps for fast checks. Package BINSEC in its own Nix dev shell, as `.#ctgrind` and `.#sde` are.
- Call binsec directly, as rscrypto's [`scripts/ct/binsec.py`](https://dev.to/loadingalias/rscrypto-v040-verifying-constant-time-behavior-instead-of-assuming-it-1p2k) does on x86_64 and aarch64. [cargo-checkct](https://github.com/tarcieri/cargo-checkct) handles only `no_std` code, has no aarch64 target, and cannot follow rind's runtime CPU dispatch.
- Each harness takes one backend path, as ctgrind's feature denials do, marks the secret inputs symbolic, and the public ones, such as lengths, symbolic too where the search stays tractable.
- A planted leak, like `admin/ct-sde`'s and `admin/ct-vartime`'s, must be found, so a harness that checks nothing fails.
- Keep `admin/ct-vartime`, though BINSEC 0.10 also flags variable-time instructions: it scans every function rind reaches, the standard library included, in seconds, where BINSEC sees only what its harnesses call.
- TESTING.md records the limits: loops are explored only to a bound, and BINSEC's lifter merges a branch whose two sides are empty, so it misses a secret branch of that shape ([arXiv 2501.04183](https://arxiv.org/abs/2501.04183)).

## Related

- [A constant-time check on every tier](/quest/m3/confidence/ct-tiers.md) - the test-based checks on the tiers BINSEC cannot decode
