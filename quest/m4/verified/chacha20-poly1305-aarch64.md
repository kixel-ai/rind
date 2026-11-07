# [XL] ChaCha20-Poly1305 is proven on aarch64

## Goal

ChaCha20-Poly1305, XChaCha20-Poly1305, and `cipher::ChaCha20` earn the ✓ on aarch64, with and without the crypto extension.

## Plan

- Runs: aws-lc's NEON `chacha20_poly1305_{seal,open}` and `poly_hash_ad_internal` (`low/aarch64/aws_lc/`), rind's AEAD glue and HChaCha20 over HACL*'s rounds, and for `cipher::ChaCha20`, Graviola's NEON ChaCha20 (`low/aarch64/chacha20.rs`, from cifra).
- Already proven: HACL*'s rounds. No aarch64 ChaCha20 or Poly1305 assembly proof exists; the proven ones (Vale's, libjade's) are x86_64 only.
- Route: HOL Light proofs of aws-lc's routines in s2n-bignum's aarch64 model on [x86_64's quest](/quest/m4/verified/chacha20-poly1305-x86.md)'s RFC 8439 specs, offered upstream (ask the maintainer before posting outside the moq-dev and kixelated orgs); Aeneas for the glue, and for Graviola's NEON ChaCha20 over modelled NEON intrinsics.

## Required

- [ChaCha20-Poly1305 is proven on x86_64](/quest/m4/verified/chacha20-poly1305-x86.md) - the HOL Light ChaCha20 and Poly1305 specs and the shared glue's proof
