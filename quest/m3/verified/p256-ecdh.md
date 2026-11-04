# [S] aarch64 P-256 ECDH is proven end to end

## Goal

On aarch64, P-256 ECDH agreement runs s2n-bignum's `p256_scalarmul_alt`, whose proof covers affine input to affine output including the inversion, so the whole agreement is proven and earns the benchmark report's ✓, unless that is more than about 10% slower than today's path.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#319](https://github.com/moq-dev/rind/pull/319), which showed key generation is already fully proven on aarch64 but agreement converts to affine in rind's own Rust (`JacobianMontPoint::as_affine`).

- Import `p256_scalarmul_alt` (and check its caller-side assumptions), route aarch64 agreement through it, and keep public-key validation where it is.
- Measure against the current path on the GitHub arm64 runner with a branch and base branch (not `main`), and apply the ~10% verified-code rule.
- Add the `p256-ecdh` aarch64 entry to `benchmarks/verified.toml`, citing the proof.
