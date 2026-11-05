# [XS] aws-lc-rs extras on demand

## Goal

Each aws-lc-rs algorithm beyond ring's set gets a quest when a consumer asks for it: ML-KEM-512 and ML-KEM-1024, AES's ECB, CFB, and OFB modes, DES, CMAC, KBKDF and SSKDF, the TLS 1.2 PRF, AES-GCM-SIV, SHA-224, ECDSA on secp256k1 or with SHA-1, SHA-224, or SHA-3, and ML-DSA. RSA-OAEP, AES-192, AES-CBC, AES key wrap, SHA-3, and ECDSA's other SHA-2 pairings moved to the [adoption epic's WebCrypto set](/quest/m2/adoption/webcrypto/README.md) (maintainer, 2026-11-04). `MIGRATING.md` maps each to this quest. This quest only waits; check new issues and MoQ's needs when triaging, plan the asked-for algorithm with `/quest-plan`, and delete this quest once the list is empty or abandoned.

## Plan

Decided by the maintainer on 2026-10-30, planning ring and aws-lc-rs parity.
