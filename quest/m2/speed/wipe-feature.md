# [S] Wiping keys on drop is opt-in

## Goal

`rind` wipes keys, keyed state, and private-key heap scratch on drop only when its additive `wipe` Cargo feature is on. The default build skips the wipe, and the PR reports what that saves against aws-lc-rs.

## Plan

Decided with the maintainer on 2026-11-07: make the wipe opt-in now, without measuring first, and plan it in m2 speed. Their reasoning: a memory disclosure such as Heartbleed leaks every live session's keys anyway, so wiping only the dropped ones buys little for the default build. RustCrypto made the same call with its opt-in `zeroize` feature. aws-lc and BoringSSL always cleanse, and ring doesn't wipe.

- Add `wipe = []` to `rind/Cargo.toml`. Without it, `zeroise` and `zeroise_value` in `rind/src/low/generic/zeroise.rs` become no-ops. Keep the Drop impls unchanged so they compile away, rather than putting a `cfg` on each.
- Keep today's scope: keys, keyed state (AEAD keys and their GHASH tables, `hmac::Key` and `Context`, signing and agreement keys, ML-KEM decap keys and shared secrets) and RSA's private-key heap scratch. Re-adding the in-call copies [moq-dev/rind#394](https://github.com/moq-dev/rind/pull/394) dropped is the FIPS scope's question, not this quest's.
- Adapters don't forward the feature. Cargo unifies features, so a consumer who wants it enables `rind/wipe` directly. Say so in the README.
- Build and test with `--features wipe` somewhere in CI so the wipe keeps compiling, with any existing wipe tests gated on it.
- Rewrite AGENTS.md's Required wipe rule to match. The maintainer approved this; suggested wording: "Wipe keys, keyed state, and heap scratch derived from a private key on drop, but only under the `wipe` feature. Wipe nothing else: ...".
- Put CI bench rows before and after in the PR (one-shot HMAC, HKDF, ECDH and other handshake-sized ops) against aws-lc-rs, taken from the GitHub bench runners. Record the result, but don't gate on it.

## Related

- [FIPS scope](/quest/m4/fips-scope.md): a FIPS build turns `wipe` on and may extend it to in-call copies.
