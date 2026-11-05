# [L] aarch64 P-256 ECDSA is proven end to end

## Goal

P-256 ECDSA signing and verification on aarch64 earn the report's ✓: rind's Rust around s2n-bignum's proven routines is proven with Aeneas → Lean in `proofs/`, under [the epic's composition rule](/quest/m3/verified/README.md), from the public signing and verification API down to the routines. The message hash, DER containers, and the nonce's randomness stay outside the ✓, as `benchmarks/verified.toml` defines it.

## Plan

The epic's audit lists it among the closest gaps: every core routine is proven, and only the glue is not.

- Signing: r is the x-coordinate of k·G reduced mod n, through `p256_scalarmulbase` and the generator table, which `tabulated` proves, and s = (e + r·d) / k mod n is assembled from Montgomery multiplications, an addition, and the scalar inversion. The s = 0 redraw ([moq-dev/rind#300](https://github.com/moq-dev/rind/pull/300)) is part of the path.
- Verification: u1 = e/s and u2 = r/s, then the twin multiplication u1·G + u2·Q over windowed digits, the infinity check, and the x-coordinate compare against r.
  - Every mixed addition goes through `public_add_affine`, which compares x's first and settles equal or opposite points by cases ([moq-dev/rind#324](https://github.com/moq-dev/rind/pull/324)), since `p256_montjmixadd`'s theorem requires unequal points. The proof has to discharge that precondition from the case split.
  - The key's odd multiples are made affine at parse by one shared inversion ([moq-dev/rind#331](https://github.com/moq-dev/rind/pull/331)), and `represents2_p256` needs each to be a finite point with reduced coordinates.
  - [moq-dev/rind#334](https://github.com/moq-dev/rind/pull/334), if it merges, adds a width-6 table built on a key's second verification behind a lock-free cache; prove whichever path main runs.
- Unlike ECDH, the twin multiplication's result rests on group laws (that the windowed sum equals u1·G + u2·Q, and that no odd multiple of Q is at infinity). `Rind/P256Group.lean`'s `p256Pow_fromM` gives them from Mathlib's group of points; that no odd multiple is at infinity also needs Q's order.
- Reuse P-256 ECDH's spec, byte lemmas, and routine axioms; each newly composed routine adds its one axiom.
