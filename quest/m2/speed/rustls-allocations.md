# [S] rind-rustls handshakes allocate no more than aws-lc-rs's provider

## Goal

A full TLS 1.3 handshake over rind-rustls's default provider makes no more heap allocations than one over rustls's aws-lc-rs provider, or each one it keeps beyond that has a stated reason. An RSA certificate's handshake makes the same number on every x86_64 dispatch path, and `rind-rustls/tests/allocations.rs` pins the new counts for every key type, RSA included.

## Plan

Found on 2026-11-13 by the PR that added the allocation test. Both peers of one full handshake, measured on x86_64 with the test's harness (`ALLOCATIONS_PROVIDER=aws-lc-rs` switches it to aws-lc-rs's provider):

| certificate | rind-rustls | aws-lc-rs |
|---|---|---|
| ECDSA P-256 | 245 | 214 |
| ECDSA P-384 | 249 | 218 |
| ECDSA P-521 | 253 | 223 |
| Ed25519 | 245 | 214 |
| RSA-2048 | 249 | 214 |
| RSA-3072 | 251 | 214 |
| RSA-4096 | 249 | 216 |

rustls makes most of them for either provider, so the gap, about 31 per handshake, is rind-rustls's own. RSA's count also depends on the CPU, which is why the test pins only ECDSA and Ed25519 for now. With ADX denied (`RIND_CPU_DISABLE_adx=1`, one of CI's forced tiers), RSA-2048 makes 247 and RSA-4096 makes 251. RSA signing with AVX-512 IFMA goes through `RsazAvx512`, which allocates one shared power table (`rind/src/low/x86_64/rsaz_avx512.rs:193`). On the portable backend, RSA-3072 makes 249. RSA-3072 also makes two more than RSA-4096 on the default x86_64 path. None of this is explained yet. The other forced x86_64 tiers leave every count unchanged.

- Find where each extra allocation comes from, such as by recording each allocation's size and backtrace in the test's allocator and diffing the two providers' handshakes, and remove the ones a handshake does not need: per-operation boxing, key copies into fresh `Vec`s, and heap scratch a fixed-size stack buffer could hold.
- Make RSA's private-key path allocate the same on every dispatch path, such as by allocating its scratch the same way whichever routine runs, then add the RSA keys back to the test's `EXPECTED`.
- An allocation that must stay, such as heap scratch sized by an RSA modulus, gets its reason in the PR.
- Allocations cost time under contention, so read the threaded handshake rows in BENCHMARKS.md before and after.

## Related

- [The bench epic](/quest/m2/bench/README.md) - added the threaded handshake rows and the allocation test this follows
