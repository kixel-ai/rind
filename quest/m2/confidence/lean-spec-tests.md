# [M] Every executable Lean spec is tested against vectors and against rind

## Goal

Every spec the proofs' trust base trusts as a transliteration of its standard (`proofs/README.md`'s trust base: `Rind/Spec.lean`, `HashSpec.lean`, `Sha2.lean`, `Ed25519.lean`, `Rsa.lean`, `Vale.lean`, `Keccak.lean`, the SymCrypt and s2n-bignum transliterations, and the rest) runs on the published vectors for its algorithm and on random inputs compared with rind's output. A disagreement fails `admin/prove`.

## Plan

Decided with the maintainer on 2026-11-18 (/quest-plan): ✅ vectors and random testing against rind, in m2 (rejected: vectors only; no change). The hand-written specs are the least-checked part of the trust base. Today a few fixed vectors check them (`Sha2Test.lean`, `HashSpecTest.lean`, `ChaCha20Poly1305Test.lean`). libcrux shipped spec errors behind admitted proofs ([ePrint 2026/2441](https://eprint.iacr.org/2026/2441.pdf)). Cedar compiles its Lean model and random-tests it against its Rust ([arXiv 2407.01688](https://arxiv.org/abs/2407.01688)).

- The specs already evaluate in Lean, so compile them into a Lean executable, or `#eval` them where that is fast enough. A spec kept `opaque` in proofs, such as Vale's S-box and `MixColumns`, runs through the body the SIMD models already evaluate.
- Vectors: Wycheproof, CAVP, and the RFCs' own, from `thirdparty/vectors/`. Random inputs: a fixed-seed generator in the runner, compared with rind's output through a small Rust driver, so a spec that agrees with every published case but drifts on others is caught.
- Keep it within the `lean` job's budget. If a full sweep would slow every PR, run a fixed sample on PRs and the full sweep nightly, and say so in the PR.
- A spec bug this finds is fixed in the same PR along with every proof that rests on it, and the PR body says which ✓ marks it touched.
