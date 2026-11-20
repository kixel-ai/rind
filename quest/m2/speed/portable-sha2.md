# [M] The portable backend's SHA-256 and SHA-512 run the fastest permissive source

## Goal

The portable backend's SHA-256 and SHA-512 (and with them SHA-224, SHA-384, SHA-512/256, their HMACs, and HKDF) run the fastest permissively licensed portable source, measured on a 64-bit target at every size, closing the 1.11 to 1.22× gap to aws-lc's C that `benchmarks/gaps.toml`'s portable SHA-2 entry records.

## Plan

Decided 2026-11-18 (maintainer, [kixel-ai/rind#619](https://github.com/kixel-ai/rind/pull/619#issuecomment-6994276361)): ✅ keep this quest (rejected: drop it). It subsumes the earlier SHA-256 measurement and SHA-512/256 per-call follow-ups.

- Today `low/portable/sha.rs` runs rind's own `generic::sha256` and the rolled `generic::sha512`, not HACL*'s through libcrux-sha2, which [kixel-ai/rind#794](https://github.com/kixel-ai/rind/pull/794) removes. On 2026-11-15, one criterion run of `rind-bench`'s sha2 harness (warm-up 1 s, measurement 3 s, 100 samples) on a shared x86_64 host, with `--cfg rind_portable` and aws-lc's C built without assembly at opt-level 2, measured generic SHA-256 at 1.17 to 1.18× aws-lc and 1.21 to 1.23× libcrux-sha2 from 1350 B to 16 KB, and rolled SHA-512 at 1.07 to 1.12× aws-lc and 1.08 to 1.18× libcrux-sha2 from 1200 B to 16 KB. [Run 43646114817](https://github.com/kixel-ai/rind/actions/runs/43646114817) measured the HACL* code it replaces at 1.11 to 1.17× aws-lc's C for SHA-256 and HMAC-SHA-256 and 1.15 to 1.22× for SHA-512, SHA-512/256, and HMAC-SHA-384 from 1200 B up. HMAC, HKDF, and PBKDF2 call this compression; the harness timed the hash.
- Candidates: aws-lc's C `sha256_block_data_order_nohw` and `sha512_block_data_order_nohw` ported to Rust, Graviola's portable SHA-2, `low::generic`'s own, and HACL*. Measure each on the portable tier of the weekly bench at every hash size; HACL* stays where it measures as fast at every size, per the source rule.
- The proof of whatever runs is planned in [portable SHA-256 and SHA-512 proven in Lean](/quest/m4/verified/rolled-sha2-esp.md); a replacement source needs that plan updated.
