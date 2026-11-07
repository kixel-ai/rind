# [XS] Check CBC consumers for padding-oracle exposure

## Goal

No current consumer of rind's AES-CBC exposes a distinguishable padding result for attacker-controlled ciphertext before authenticating it. Reproduce and fix any reachable defect; otherwise close this quest with the evidence.

## Plan

- Trace current production callers of `cipher::AesCbcDecryptingKey`, including adapters and their downstream use, to the point where a decryption failure can be observed.
- [The AES-CBC PR](https://github.com/moq-dev/rind/pull/381) deliberately kept the generic unauthenticated primitive and documented its padding-oracle risk. That risk alone is not a defect to fix here.
- Change a consumer only if its actual input and error path exposes the oracle. Reproduce that path before the fix and verify the result after it. Leave a broader rind API redesign for a separate decision if the evidence calls for one.

## Related

- [Test coverage audit](/quest/m3/confidence/audit.md) - maps primitive tests across backends, rather than consumer misuse
