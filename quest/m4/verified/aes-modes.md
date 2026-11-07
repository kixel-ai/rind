# [L] AES-CTR, AES-CBC, and AES key wrap are proven with AES hardware

## Goal

`cipher::AesCtr`, AES-CBC, and `key_wrap::AesKek` (RFC 3394 and RFC 5649) earn the ✓ on x86_64 with AES-NI and on aarch64 with the crypto extension.

## Plan

- Runs on x86_64: aws-lc's `aes_hw_ctr32_encrypt_blocks` and `aes_hw_cbc_encrypt` assembly under `low/generic/ctr.rs` and rind's Rust; on aarch64, rind's NEON CTR by 8 (`low/aarch64/aes_ctr.rs`) and CBC (`aes_cbc.rs`) intrinsics; and on both, `mid/aes_kw.rs`'s wrap and unwrap over the block cipher.
- Route: on x86_64, HOL Light proofs of the two aws-lc routines in s2n-bignum's x86_64 model, which has an AES-NI model, against FIPS 197 and SP 800-38A, offered upstream (ask the maintainer before posting outside the moq-dev and kixelated orgs); on aarch64, Aeneas over the intrinsic models [AES header protection](/quest/m4/verified/aes-header-protection.md) adds; and the counter wrapping, CBC chaining, and key wrap in Lean against SP 800-38A and SP 800-38F.

## Required

- [rind's own HOL Light proofs have a home that CI checks](/quest/m4/verified/hol-light.md) - where the HOL Light proofs live and are checked until upstream takes them
- [AES and QUIC AES header protection are proven with AES hardware](/quest/m4/verified/aes-header-protection.md) - the block cipher and its intrinsic models
