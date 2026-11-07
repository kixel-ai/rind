# [S] Check rustls provider panic reachability

## Goal

Malformed peer input cannot reach the `rind-rustls` AEAD key or IV conversions that use `unwrap`. Reproduce and fix any reachable panic; otherwise close this quest with the input-provenance and trait-contract evidence.

## Plan

- Trace `rind-rustls/src/aead.rs`'s `aead_key` and TLS 1.2 IV conversions from rustls's key schedule and public provider traits. Check whether a peer, a caller using the provider normally, or only a direct trait caller can supply malformed lengths.
- Compare the rustls 0.23 provider contract and its built-in providers. Exercise a malformed path only where the contract permits it; reproduce any reachable panic before fixing it.
- If the only concern is direct misuse outside rustls's contract, record that boundary and close this quest. Plan broader rind-specific API hardening separately if the evidence warrants it.

## Related

- [Test coverage audit](/quest/m3/confidence/audit.md) - maps primitive tests rather than adapter input provenance
