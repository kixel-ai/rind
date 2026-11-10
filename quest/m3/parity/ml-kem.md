# [M] ML-KEM-512 and ML-KEM-1024

## Goal

`rind::kem` offers ML-KEM-512 and ML-KEM-1024 beside ML-KEM-768, on every backend, at least as fast as aws-lc-rs, with one key, ciphertext, and secret type per parameter set, so a ciphertext of one set fails to compile against a key of another.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06, whose epic still owns the API decisions below and the leaves that build on them. Moved from that epic to m3's parity epic with the maintainer on 2026-11-09: ✅ m3/parity, beside the rustls parity quest that needs ML-KEM-1024 (rejected: m2, or pushing rustls parity back to m4). rustls's aws-lc-rs provider ships `MLKEM1024` today (rustls 0.23.46, `src/crypto/aws_lc_rs/mod.rs:247`), which rind-rustls filters out of its parity test (`rind-rustls/src/lib.rs:327`), and an m3 quest could not finish while this sat in m4.

- Generalize `mid/mlkem768.rs` over the rank `K` (2, 3, 4) and the compression widths (`du`, `dv`: 10/4 for 512 and 768, 11/5 for 1024), and ML-KEM-512's `eta1 = 3` noise. No new source: s2n-bignum's HOL Light-proven `mlkem_basemul_k2` and `k4` are already vendored at the pinned revision, and mlkem-native v2.0.0's x86_64 AVX2 `poly_compress_d5`/`d11` and `decompress_d5`/`d11` are HOL Light-proven, constant time included, like the `d4`/`d10` rind already copies; aarch64 and the portable tiers extend rind's port of mlkem-native's C.
- API: sealed marker types `MlKem512`, `MlKem768`, `MlKem1024` parameterize `DecapsulationKey<A>`, `EncapsulationKey<A>`, and `Ciphertext<A>`; `Ciphertext::<A>::new(&[u8])` checks the length, and `decapsulate` takes `&Ciphertext<A>`. This replaces `kem::ML_KEM_768` and `generate(&ML_KEM_768)`, a breaking change for rind-rustls, rind-bench, and the fuzzers, released in rind's next breaking release, since 0.3 shipped on 2026-11-07 without it (`rind/Cargo.toml:3` is 0.3.3, and `rind/src/high/kem.rs:26` still has `ML_KEM_768`); update ARCHITECTURE.md's rule that each module takes a `&'static` algorithm to say KEMs and signing key pairs take a type per parameter set (maintainer, 2026-11-07).
- An encapsulation key caches the transposed matrix, 8 KiB at rank 4, which breaks the `< 8192` size asserts in `high/kem.rs` that keep CodSpeed from charging `memcpy` per byte. Keep the cache and box it, or drop it, whichever measures faster.
- Tests: Wycheproof's `mlkem_{512,1024}_*` vectors (keygen from seed, encaps, semi-expanded decaps), differential against aws-lc-rs, ctgrind for keygen and decaps.
- rind-rustls moves to the new API; its `MLKEM1024` group belongs to [rustls provider parity](/quest/m3/parity/rustls.md).
- Decapsulation key import and export, which rind's ML-KEM-768 lacks today (aws-lc-rs's raw expanded key, RFC 9935's 64-byte seed and PKCS#8), wait for a consumer; HPKE's `DeriveKeyPair`, which takes the seed, will be one, in [HPKE's post-quantum KEMs](/quest/m4/protocols/hpke-pq.md).
- Measured on desktop and kixtop, aws-lc-rs takes 5.8 to 12.6 µs per ML-KEM-512 and ML-KEM-1024 operation, and libcrux 4.9 to 16.4 µs; rind's ML-KEM-768 already takes 0.5 to 0.9 times aws-lc-rs's time. Benchmark all three sets against both, as `mlkem768` does today.

## Related

- [rind passes NIST's ACVP vectors](/quest/m2/confidence/acvp.md) - its ML-KEM keyGen and encapDecap sets, which this extends to the two new parameter sets if it has landed
