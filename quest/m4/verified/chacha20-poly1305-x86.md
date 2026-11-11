# [XL] ChaCha20-Poly1305 is proven on x86_64

## Goal

ChaCha20-Poly1305 and XChaCha20-Poly1305, TLS's and QUIC's other AEAD, and `cipher::ChaCha20` earn the ✓ on x86_64 CPUs with SSE4.1, every tier from Westmere up.

## Plan

- Runs: aws-lc's stitched `chacha20_poly1305_{seal,open}` and `poly_hash_ad_internal` (`low/x86_64/aws_lc/`), its AVX2 half where the CPU has AVX2 and BMI2 and its SSE4.1 half otherwise, with rind's one change (the AVX2 choice read from the block rind passes); rind's AEAD glue (`mid/chacha20poly1305.rs`, `xchacha20poly1305.rs`) and HChaCha20 over HACL*'s rounds; and for `cipher::ChaCha20`, rind's AVX2 kernels from two blocks, aws-lc's SSSE3 `ChaCha20_ctr32_ssse3_4x` above 128 bytes without AVX2, and HACL*'s rounds below.
- Proven ([moq-dev/rind#627](https://github.com/moq-dev/rind/pull/627)): `proofs/Rind/Spec.lean` transliterates RFC 8439's ChaCha20 encryption, Poly1305, and AEAD, and draft-irtf-cfrg-xchacha-03's HChaCha20 and XChaCha20-Poly1305, which `Rind/ChaCha20Poly1305Test.lean` checks against both documents' test vectors. `Rind/X86_64/ChaCha20Poly1305.lean` proves the AEAD API (`aead::Key` for `CHACHA20_POLY1305`, and `RandomizedNonceKey`), the `mid` glue, and HChaCha20 over HACL*'s rounds, down to the call of aws-lc's one-pass routine, under the hypothesis `OnePass` that the routine computes RFC 8439's AEAD. `Rind/X86_64/HkdfAead.lean` proves HKDF's `From<Okm>` into a ChaCha20-Poly1305 key, so QUIC's `TLS_CHACHA20_POLY1305_SHA256` key schedule needs only `OnePass` (maintainer, 2026-11-10: ✅ fold into this quest).
- Measured, 2026-11-11, seal with 13 bytes of AAD, in ns, pinned to a Lion Cove P-core of an Intel Core Ultra 7 270K Plus, the minimum of three rounds on a host shared with other agents (load average 24 to 33 on 24 threads, single rounds up to 3x the minimum); 32 bytes of AAD moved no row of the table by more than 5%. Proven pairs run ChaCha20 and Poly1305 as separate passes with no glue, so they are lower bounds.

  | Size | aws-lc AVX2 | aws-lc SSE4.1 | libjade AVX2 pair | libjade AVX pair | libjade AVX2 ChaCha20 + Vale Poly1305 |
  | ---: | ---: | ---: | ---: | ---: | ---: |
  | 32 B | 93 | 105 | 170 | 74 | 173 |
  | 1350 B | 450 | 611 | 618 | 812 | 664 |
  | 16 KB | 4228 | 6201 | 4746 | 8686 | 6420 |

  aws-lc's stitched routine is the fastest at 1350 B and 16 KB, so it stays, and its proof is the route below; libjade's AVX pair wins only at 32 B.
- Remaining:
  - Write HOL Light specs of ChaCha20, Poly1305, and the AEAD against RFC 8439, in s2n-bignum's style, and show they are `Rind/Spec.lean`'s, as `Rind/S2nSha256.lean` does for SHA-256.
  - Extend s2n-bignum's x86_64 model with the instructions aws-lc's routines use that it lacks (see Waiting): PALIGNR and VPALIGNR, PSLLD and PSRLD, PSLLDQ and PSRLDQ, PINSRB, PEXTRB, PEXTRQ, POR, VBROADCASTI128, and PUNPCK{L,H}{DQ,QDQ}. [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) adds PALIGNR and PUNPCK{L,H}QDQ, and [awslabs/s2n-bignum#439](https://github.com/awslabs/s2n-bignum/pull/439) PSLLDQ and PSRLDQ.
  - Its decoder refuses `rep ret` (F3 C3), which `poly_hash_ad_internal` returns with: change rind's copy to a plain `ret`, the same instruction to every CPU, whose prefix was only a branch-prediction hint for AMD's K8 (recommended), rather than teach the decoder the prefix.
  - Prove both halves of `chacha20_poly1305_{seal,open}` and `poly_hash_ad_internal` on rind's object code, restate them in `Rind/X86_64/` as axioms about `one_pass` that give `OnePass`, and add the `verified.toml` entries.
  - For `cipher::ChaCha20`, prove rind's AVX2 kernels with Aeneas over modelled intrinsics and aws-lc's `ChaCha20_ctr32_ssse3_4x` in HOL Light on the same spec, and compose them with the HACL* rounds' proof.
- The specs are [aarch64's quest](/quest/m4/verified/chacha20-poly1305-aarch64.md)'s too.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Waiting

- Maintainer: how the instruction semantics above reach s2n-bignum's x86_64 model. (a) rind carries its own extension beside `proofs/hol-light/s2n-bignum/`'s unmerged specs, checks it against the CPU by random-instruction cosimulation as s2n-bignum checks its own, and offers it upstream later; (b) post it to awslabs/s2n-bignum first and prove on it once reviewed, which needs your approval to post; (c) wait for #450 and #439 and carry or post only what they lack. Recommend (a): it unblocks the proofs now, follows how rind already carries unmerged specs, and keeps upstreaming optional. Done when the choice is recorded in this Plan.
