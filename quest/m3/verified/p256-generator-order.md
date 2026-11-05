# [M] P-256's generator is proven to have order n

## Goal

Lean proves that P-256's generator G has prime order n, so the aarch64 P-256 theorems stop assuming what follows from it: that a multiple of G by a scalar in [1, n) is a finite point. Key generation, the public key, and ECDSA signing's k·G then hold with no such hypothesis.

## Plan

[moq-dev/rind#343](https://github.com/moq-dev/rind/pull/343) made `p256Pow` HOL Light's `group_pow`, with the group law proven from Mathlib's elliptic-curve group, so n·G = 0 is a computation the kernel can check, as `P256Table.lean` checks the generator table and `P256Group.lean` checks that p is prime.

- Prove n prime by a kernel-checked certificate, and n·G = 0 by `decide +kernel` over the inverse-free arithmetic #343 uses. No `native_decide`.
- Drop the hypotheses this discharges, in `P256.lean` and in [the ECDSA proof](/quest/m3/verified/p256-ecdsa.md) if it has landed.
- A peer's point in ECDH is a different case: k·P is finite for every curve point P only if the curve's group has order n (cofactor 1), and proving that needs a point count Mathlib lacks (Hasse's bound or more). Keep `p256_agree`'s fault case unless a cheap route turns up, and say why in the theorem's docstring.
- Keep `admin/prove` fast: it took about 100 s after #343. Say what this adds.
