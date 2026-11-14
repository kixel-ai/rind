# [S] rind-rustls handshakes allocate no more than aws-lc-rs's provider

## Goal

A full TLS 1.3 handshake over rind-rustls's default provider makes no more heap allocations than one over rustls's aws-lc-rs provider, or each one it keeps beyond that has a stated reason, and `rind-rustls/tests/allocations.rs` pins the new counts.

## Plan

Found on 2026-11-13 by the PR that added the allocation test. Both peers of one full handshake, measured on x86_64 with the test's harness (`ALLOCATIONS_PROVIDER=aws-lc-rs` switches it to aws-lc-rs's provider):

| certificate | rind-rustls | aws-lc-rs |
|---|---|---|
| ECDSA P-256 | 246 | 215 |
| ECDSA P-384 | 250 | 219 |
| ECDSA P-521 | 254 | 224 |
| Ed25519 | 246 | 215 |
| RSA-2048 | 250 | 215 |
| RSA-3072 | 252 | 215 |
| RSA-4096 | 250 | 217 |

rustls makes most of them for either provider, so the gap, about 31 per handshake, is rind-rustls's own. Two things stand out besides its size: RSA-3072 makes two more than RSA-4096, and on the portable backend RSA-3072 makes 250, two fewer than on x86_64's assembly. Neither is explained yet.

- Find where each extra allocation comes from, such as by recording each allocation's size and backtrace in the test's allocator and diffing the two providers' handshakes, and remove the ones a handshake does not need: per-operation boxing, key copies into fresh `Vec`s, and heap scratch a fixed-size stack buffer could hold.
- An allocation that must stay, such as heap scratch sized by an RSA modulus, gets its reason in the PR.
- Allocations cost time under contention, so read the threaded handshake rows in BENCHMARKS.md before and after.

## Related

- [The bench epic](/quest/m2/bench/README.md) - added the threaded handshake rows and the allocation test this follows
