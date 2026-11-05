# [S] Only keys are wiped on drop

## Goal

rind wipes keys and keyed state on drop, and nothing else, so per-call state such as digest contexts and scratch buffers costs no wipe. AGENTS.md's wipe rule says so.

## Plan

Decided with the maintainer on 2026-11-05: drop non-key wipes ✅ / drop every wipe that measurably costs, keys included / keep today's rule. Keys and keyed state (HMAC, AEAD, cipher, and signing keys, KDF secrets, DRBG state) keep their wipes, which FIPS 140-3 zeroization also needs ([m4 FIPS scoping](/quest/m4/fips-scope.md)).

- List every drop-wipe in rind and its adapters, mark each as key or keyed state or not, and remove the others. [moq-dev/rind#352](https://github.com/moq-dev/rind/pull/352) found the unkeyed `digest::Context` wipe is most of SHA-256's remaining 64 B gap to RustCrypto.
- Keep the zeroing tests for what still wipes, and delete the tests for what no longer does.
- Narrow AGENTS.md's wipe rule to keys and keyed state, as the maintainer asked.
- Measure short hashes, HMAC, and HKDF before and after, and update `benchmarks/gaps.toml`.
