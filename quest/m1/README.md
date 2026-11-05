# m1: MoQ coverage and Bun

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.
Bun's fastest asymmetric operations run on rind, ahead of Bun writing its own.

## Required

- [Bun runs its fastest asymmetric crypto on rind](/quest/m1/bun.md) - Ed25519, X25519, P-384, and P-521 in Bun on rind, before Bun writes its own
- [Agreement keys that can be stored and reused](/quest/m1/agreement-stored-keys.md) - X25519 and ECDH for Bun
- [P-256 key generation as fast as BoringSSL](/quest/m1/p256-keygen.md) - so P-256 joins Bun's other curves
- [ECDSA over a precomputed digest](/quest/m1/ecdsa-prehash.md) - node's createSign and other hash pairings in Bun
- [Bun parses its moved keys with rind](/quest/m1/bun-key-parsing.md) - Bun's key import, 670 µs for P-384 today
- [rind's public API is audited before 0.2.0](/quest/m1/api-audit.md) - every public item against AGENTS.md's API rules
- [rind 0.2.0 is released](/quest/m1/release-0.2.md) - the audited API on crates.io for Bun and MoQ
- [rind's launch blog post is published](/quest/m1/launch-post.md) - the Bun PR waits on it
- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
- [The README shows how to use rind and links the details](/quest/m1/readme-restructure.md) - usage, the migration prompt, and an invitation to AI contributors, with the details in linked docs
