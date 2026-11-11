# [XS] aws-lc-rs extras on demand

## Goal

Each aws-lc-rs algorithm beyond ring's set gets a quest when a consumer asks for it: AES's ECB, CFB, and OFB modes, DES, CMAC, KBKDF and SSKDF, the TLS 1.2 PRF, AES-GCM-SIV, SHA-224, ECDSA on secp256k1 or with SHA-1, SHA-224, or SHA-3. ML-KEM-512, ML-KEM-1024, and ML-DSA left this list for quests of their own (maintainer, 2026-11-07): ML-KEM-512 and ML-KEM-1024 have shipped, and ML-DSA is [ML-DSA-44, ML-DSA-65, and ML-DSA-87](/quest/m3/parity/ml-dsa.md) in this epic (maintainer, 2026-11-09). RSA-OAEP, AES-192, AES-CBC, AES key wrap, and SHA-3 were added for WebCrypto adopters (maintainer, 2026-11-04), and ECDSA's other SHA-2 pairings came with ECDSA over a digest. `MIGRATING.md` maps each to this quest. This quest only waits; check new issues and MoQ's needs when triaging, plan the asked-for algorithm with `/quest-plan`, and delete this quest once the list is empty or abandoned.

## Plan

Decided by the maintainer on 2026-10-30, planning ring and aws-lc-rs parity.

## Waiting

- A consumer: asks for one of the algorithms above, in a moq-dev/rind issue or as a need of MoQ's. On 2026-11-09 moq-dev/rind had no open issue. Check with `gh issue list -R moq-dev/rind` and MoQ's needs when triaging.
