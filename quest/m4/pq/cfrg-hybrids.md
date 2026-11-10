# [S] MLKEM768-P256 and MLKEM1024-P384 hybrid KEMs

## Goal

`rind::kem` offers draft-irtf-cfrg-concrete-hybrid-kems's MLKEM768-P256 and MLKEM1024-P384, and `hpke` offers them as the KEMs draft-ietf-hpke-pq registers, `0x0050` and `0x0051`, which the MLS post-quantum ciphersuites `0x0012` to `0x0014` use.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06.

- Both instantiate the CFRG's CG framework with a SHAKE256 key expansion and a SHA3-256 combiner, as X-Wing does for X25519, over rind's P-256 and P-384 ECDH and ML-KEM. Share the combiner with [X-Wing](/quest/m4/pq/x-wing.md); no new arithmetic.
- Add both to `hpke` beside the KEMs [HPKE's post-quantum KEMs](/quest/m4/protocols/hpke-pq.md) adds. IANA's registry already lists `0x0050` and `0x0051`, against draft-ietf-hpke-pq-04; the construction behind them is what this waits for.
- Test against draft-ietf-hpke-pq's Appendix A vectors and the CFRG draft's own (`test-vectors.json` in [its repository](https://github.com/cfrg/draft-irtf-cfrg-concrete-hybrid-kems)). aws-lc-rs and libcrux have neither KEM, so differential tests run against that repository's Rust `reference-implementation`, or [rozbb/rust-hpke](https://github.com/rozbb/rust-hpke)'s `src/kem/mlkem_nistp.rs` if a release carries it by then, as the [epic](/quest/m4/pq/README.md)'s rule for algorithms aws-lc-rs lacks allows. ctgrind covers key generation from the seed, the one new secret path, and decapsulation.
- Waits for the draft rather than building against -04 (maintainer, 2026-11-07).

## Waiting

- IRTF CFRG: draft-irtf-cfrg-concrete-hybrid-kems reaches the RFC Editor queue, so its key expansion and combiner are fixed. On 2026-11-09 it is at -04 (dated 2026-07-06), in IRTF state "Waiting for Document Shepherd" with a revised draft needed. Check its [datatracker](https://datatracker.ietf.org/doc/draft-irtf-cfrg-concrete-hybrid-kems/) state.

## Required

- [X-Wing](/quest/m4/pq/x-wing.md) - the combiner both share
- [HPKE's post-quantum KEMs](/quest/m4/protocols/hpke-pq.md) - the post-quantum KEMs in `hpke` that these two join
