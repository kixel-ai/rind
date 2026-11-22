# [M] Trim Rust wrapper, dispatch, and stack-zeroing overhead on hot paths

## Goal

Eliminate the measurable Rust-layer overhead identified across `rind` and `rind-rustls` hot paths (RSA verify stack zeroing and `PosInt` conversions, AEAD double dispatch and oversized ChaCha stack wipe, `rind-rustls`'s per-record DIT toggle and hybrid KX copies, `sha3` `aarch64` feature re-check, and `pbkdf2_vg::Key::verify` heap allocation) without changing any public API or weakening wiping guarantees.

## Plan

Planned with the maintainer on 2026-11-21 (`/quest-plan`): ✅ trim the Rust wrapper and stack overhead across these six hot paths (rejected: skip).

- **RSA verification (`rind/src/mid/rsa_pub.rs:50-66, 136-155`)**:
  - Avoid unnecessary zero-initialization and repeated `PosInt` copy/round-trip conversions during public-key verification (public key operations handle no private material, per `AGENTS.md`'s wipe rule).
- **AEAD double dispatch & oversized ChaCha wipe (`rind/src/aead.rs:234-314`, `rind/src/aead/quic.rs:100-118`)**:
  - Collapse redundant runtime dispatch layers on AEAD seal/open and QUIC header protection calls.
  - Trim the oversized Rust-wrapper stack wipe in ChaCha20-Poly1305 per `AGENTS.md`'s wipe rule (wipe keyed state and key-derived heap scratch, not stack temporaries or plaintext scratch, while leaving any wipe built into proven upstream assembly untouched).
- **`rind-rustls` per-record DIT toggle & hybrid KX copies (`rind-rustls/src/aead.rs:85`, `rind-rustls/src/kx_group/{mlkem.rs:18,hybrid.rs:40-54}`)**:
  - rind-rustls takes no `Dit::hold()` of its own (checked 2026-11-21), so a small record pays rind's toggle once to seal and once to open. A guard around one record would not help: each seal or open is one rind call, which toggles once either way. Only a guard spanning many records removes it, and rind-rustls has no such scope, since rustls calls it once per record. Measure the toggle with `dit-per-call/rustls-records/aes128-gcm/*/64B` against `rustls-records/aes128-gcm/*/64B`, and if it costs more than a few percent of the record on Apple Silicon, document in rind-rustls's README that a caller holds `rind::cpu::Dit::hold()` across its connection's I/O loop.
  - Eliminate redundant `Vec` / slice copies in `rind-rustls`'s ML-KEM and hybrid key-exchange setup/completion.
- **`sha3` `aarch64` feature hoist (`rind/src/low/aarch64/sha3_keccak_f1600_mux.rs:6`)**:
  - Hoist `aarch64` SHA3 CPU-feature detection out of per-block sponge loops (`rind/src/mid/sha3.rs`) so multi-block hashing and XOF squeezing dispatch once.
- **`pbkdf2_vg::Key::verify` stack fast-path (`rind/src/mid/pbkdf2_vg.rs:133`)**:
  - Use a fixed stack buffer fast-path for standard derived key lengths (e.g. `<= 64` bytes) instead of heap-allocating on every password verification.
- Verify every change with targeted before/after Criterion benchmarks, `zeroing.rs`, `heap_scratch.rs`, and CT checks.
