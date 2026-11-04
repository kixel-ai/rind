# [M] x86_64 AES-GCM's Vale glue is proven

## Goal

On x86_64 CPUs with AVX and MOVBE but no VAES, the Rust around HACL*'s Vale AES-GCM in `rind/src/low/x86_64/aes_gcm_avx.rs` is proven to meet the routines' preconditions and to make their result AES-GCM, so AES-GCM earns the report's ✓ there for messages and AAD under 2^32 bytes.
That Rust includes rind's own key setup on that tier: its AES key expansion (`aes128_expand` and `aes256_expand` in `rind/src/low/x86_64/aes.rs`) and its GHASH key powers (`ClmulTable::new` and `ClmulTable::vale_hkeys` in `rind/src/low/x86_64/ghash.rs`) are proven to produce the round keys and `hkeys_reqs_pub` layout Vale's proof assumes.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. [moq-dev/rind#329](https://github.com/moq-dev/rind/pull/329) switched that tier to Vale for the counter block, encryption, and tag check. Vale's proof (`Vale.Wrapper.X64.GCMencryptOpt`) covers it given EverCrypt's Low* wrapper, which rind's Rust mirrors: it copies the nonce and the partial blocks of the message and AAD to scratch, and splits the message into the six-block loop's share, the single blocks, and the partial block.

The maintainer chose performance first: Vale's own key expansion and `keyhash_init` took 1.5-1.6x aws-lc-rs's key setup time, against 0.78x for rind's, so rind computes the round keys and H powers itself and leaves those two steps outside Vale's proof. A test checks them byte for byte against Vale's routines, which rind imports for that test only. Prove them here instead of moving back to Vale's setup:

- the key expansion equals FIPS 197's (Vale's `key_to_round_keys_LE`), stored as each round key's 16 bytes in order;
- the eight powers are `hkeys_reqs_pub`'s: `gf128_power h n` for H to H^6 in slots 0, 1, 3, 4, 6, and 7, E_K(0) byte-reversed in slot 2, and zero in slot 5.

Prove that Rust with Aeneas → Lean in `proofs/`, Vale's theorems entering as axioms under [the epic's composition rule](/quest/m3/verified/README.md), then add the ✓ entries to `benchmarks/verified.toml`.
