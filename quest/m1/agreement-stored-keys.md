# [M] Agreement keys that can be stored and reused

## Goal

rind's agreement API has a private key that can be loaded, exported, and used for many agreements, for X25519 and ECDH on P-256, P-384, and P-521. Bun can then move X25519 and ECDH to rind, where the Bun prototype measured rind 4x to 10x faster on P-384 and P-521.

## Plan

Found by the Bun prototype ([moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368)). `agreement::PrivateKey::agree(self)` consumes the key, as ring's ephemeral keys do, so WebCrypto's `deriveBits` and node's `ECDH`/`diffieHellman`, which reuse a stored key, cannot use it.

- Follow aws-lc-rs's `agreement::PrivateKey` where it is clear: `agree` by reference, loading from raw bytes, PKCS#8, and SEC1, and exporting.
- Keep the ephemeral type if a stored one would make one-shot use worse.
- Wipe on drop. Add a ctgrind test for every new secret path.
- Keep X25519's and aarch64 P-256 ECDH's proofs passing, extending them to the new entry points if they're on the proven path.
- Test against Wycheproof and aws-lc-rs.
