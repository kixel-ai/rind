# [M] cryptofuzz fuzzes rind

## Goal

cryptofuzz has a rind module that runs every operation rind offers and cryptofuzz supports, differentially against aws-lc, BoringSSL, OpenSSL, and the other libraries it builds. rind runs in cryptofuzz's OSS-Fuzz project.

## Plan

- Write the module through cryptofuzz's Rust module support, as its RustCrypto and ring modules do, and fix any differences it finds in rind first.
- Draft the guidovranken/cryptofuzz PR and show it to the maintainer before posting it.
