# m1: MoQ coverage and Bun

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.
Bun's fastest asymmetric operations run on rind, ahead of Bun writing its own.

## Required

- [Bun runs its fastest asymmetric crypto on rind](/quest/m1/bun.md) - Ed25519, P-384, and P-521 in Bun on rind, before Bun writes its own
- [Agreement keys that can be stored and reused](/quest/m1/agreement-stored-keys.md) - X25519 and ECDH for Bun
- [Loading an Ed25519 key costs less than a signature](/quest/m1/ed25519-key-load.md) - Bun's per-call PEM path
- [P-256 key generation as fast as BoringSSL](/quest/m1/p256-keygen.md) - so P-256 joins Bun's other curves
- [rind's launch blog post is published](/quest/m1/launch-post.md) - the Bun PR waits on it
- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
- [A prompt migrates a repo to rind](/quest/m1/migration-prompt.md) - a copy-paste prompt has an agent move a repo to rind and report build time, size, and benchmarks before and after
- [The README shows how to use rind and links the details](/quest/m1/readme-restructure.md) - usage, the migration prompt, and an invitation to AI contributors, with the details in linked docs
