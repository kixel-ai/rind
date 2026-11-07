# [S] MLKEM768-P256 and MLKEM1024-P384 hybrid KEMs

## Goal

`rind::kem` offers draft-irtf-cfrg-concrete-hybrid-kems's MLKEM768-P256 and MLKEM1024-P384, which draft-ietf-hpke-pq registers as HPKE KEMs `0x0050` and `0x0051` and the MLS post-quantum ciphersuites `0x0012` to `0x0014` use.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06.

- Both instantiate the CFRG's CG framework with a SHAKE256 key expansion and a SHA3-256 combiner, as X-Wing does for X25519, over rind's P-256 and P-384 ECDH and ML-KEM. Share the combiner with [X-Wing](/quest/m4/pq/x-wing.md); no new arithmetic.
- Test against draft-ietf-hpke-pq's Appendix A vectors; aws-lc-rs and libcrux have neither KEM.
- Waits for the draft rather than building against -04 (maintainer, 2026-11-07).

## Waiting

- IRTF CFRG: draft-irtf-cfrg-concrete-hybrid-kems (at -04, 2026-07-24) reaches the RFC Editor queue, so its key expansion and combiner are fixed. Check its [datatracker](https://datatracker.ietf.org/doc/draft-irtf-cfrg-concrete-hybrid-kems/) state.

## Required

- [X-Wing](/quest/m4/pq/x-wing.md) - the combiner both share
