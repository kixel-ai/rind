# [M] rind-snow

## Goal

A published `rind-snow` crate implements [snow](https://github.com/mcginty/snow)'s
`CryptoResolver` on rind (ChaCha20-Poly1305, AES-256-GCM, X25519, SHA-256,
SHA-512), so any snow user, such as rathole's Noise transport, opts in with
no upstream change.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview.

- snow's resolver returns `None` for what it cannot build, and snow composes
  resolvers at setup, so BLAKE2 and X448 come from whatever resolver the user
  pairs with rind-snow; rind-snow never falls back by itself.
- rathole reaches snow through snowstorm 0.4, which pins snow 0.9, so its
  users need snowstorm on snow 0.10 first, or rind-snow on 0.9 too; check
  which is cheaper before naming rathole in the README.
- Test with snow's vectors and a handshake against its default resolver;
  benchmark transport throughput against the RustCrypto and ring resolvers.
- Noise is a security-critical handshake: say in the README that rind is
  young.
