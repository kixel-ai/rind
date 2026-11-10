# [S] Check rustls provider panic reachability

## Goal

Malformed peer input cannot reach the `rind-rustls` AEAD key or IV conversions that use `unwrap`. Reproduce and fix any reachable panic; otherwise close this quest with the input-provenance and trait-contract evidence.

## Plan

Moved from m3 into m2's confidence epic with the maintainer on 2026-11-09: ✅ active assurance moves to m2 (rejected: redefine m3, move only this security check). It waits on nothing outside the tree, and `AGENTS.md` requires that malformed input is an error, never a panic, so it is not deferred work. On that day the conversions were still unchecked `unwrap`s, at `rind-rustls/src/aead.rs:12`, `:77`, and `:241`.

- Trace `rind-rustls/src/aead.rs`'s `aead_key` and TLS 1.2 IV conversions from rustls's key schedule and public provider traits. Check whether a peer, a caller using the provider normally, or only a direct trait caller can supply malformed lengths.
- Compare the rustls 0.23 provider contract and its built-in providers. Exercise a malformed path only where the contract permits it; reproduce any reachable panic before fixing it.
- If the only concern is direct misuse outside rustls's contract, record that boundary and close this quest. Plan broader rind-specific API hardening separately if the evidence warrants it.

## Related

- [Test coverage](/TESTING.md) - maps primitive tests rather than adapter input provenance
- [Hostile peer bytes never panic an adapter](/quest/m2/confidence/adapters-hostile-input.md) - a fuzz target for the same boundary, which this trace does by hand
