# [XS] snow's write_message refuses a buffer without room for the static key's tag

## Goal

A draft PR on [mcginty/snow](https://github.com/mcginty/snow) makes `HandshakeState::write_message` return `Error::Input`, rather than panic in the resolver's `Cipher::encrypt`, when the buffer fits the static key but not its tag. That removes the only snow-reachable panic [rind-snow](https://github.com/moq-dev/rind/pull/470) keeps.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#470](https://github.com/moq-dev/rind/pull/470), whose body holds the drafted report and reproduction.

- The bug: the `Token::S` arm in `src/handshakestate.rs` checks `byte_index + self.s.pub_len() > message.len()`, but once the symmetric state has a key the encrypted static key is `pub_len + TAGLEN` bytes. On snow 0.10.0, an XX responder's `write_message(&[], &mut [0u8; 64])` for message 2 (which needs 96 bytes) panics in the default resolver, and in the ring resolver too.
- The fix: add `TAGLEN` when `self.symmetricstate.has_key()`, as the `E1` and payload checks already do, with a test of the reproduction.
- Decided with the maintainer on 2026-11-07: outside posts wait for the [launch post](https://moq.dev/blog/rind/), now up, then go up only as draft PRs. Open it from a kixelated fork as a draft, with the AI use stated and a short body.
- snow has no AI or contribution policy beyond its license terms; check again before posting.
