# [S] Short hashes through digest::Context match the one-shot

## Goal

A short message hashed through `digest::Context` (new, update, finish, and reset) costs about what the one-shot `digest` does, so streaming callers such as HMAC, HKDF, and rustls's transcript hash don't pay for the context's setup.

## Plan

[moq-dev/rind#376](https://github.com/moq-dev/rind/pull/376) removed the padding stall: a 32-byte SHA-1 one-shot now runs at 0.57x main's time on Zen 3, but through `digest::Context` only at 0.81x. Most of what remains is building and resetting the context. Profile where it goes (buffer initialization, state copies, and dispatch on each call), cut it without changing the API, and measure SHA-1, SHA-256, and SHA-512 at 32 B and 64 B against the one-shot and aws-lc-rs. Start once #376 has landed.
