# [S] Ed25519's key-pair verification assumes no group fact

## Goal

Ed25519's `ed25519_key_pair_verify`, on x86_64 and aarch64, drops its assumption `hA` that the base point times the key's scalar is a point of `edwards25519_group`.

## Plan

- The fact is closure of `edwards25519_group` under `edPow`, which `Rind/Ed25519Group.lean` proves as `edOnCurve_pow` and `edOnCurve_B`, over `Rind/Edwards.lean`'s group of points over `ZMod p25519`. x86_64's `ed25519_key_pair_verify` already drops `hA` with them, so only aarch64's remains, when [Ed25519 verification on x86_64](/quest/m4/verified/ed25519-half-scalar.md) moves both targets' theorems into the shared file or sooner.
- P-256's half of this quest landed in `Rind/NistOrder.lean`: every finite point of a NIST curve has order n, by an elementary count (at most 2p + 1 points, Lagrange, Cauchy, and a kernel check that x³ - 3x + b has no root mod p), so `P256Order` is `p256_order`, a theorem.

## Related

- [Ed25519 verification on x86_64 is proven again](/quest/m4/verified/ed25519-half-scalar.md) - lands the group and x86_64's half
