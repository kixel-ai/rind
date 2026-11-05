# [S] AES key wrap with padding

## Goal

rind wraps and unwraps keys of any length with AES key wrap with padding (RFC 5649, NIST SP 800-38F's KWP), for pyca-compatible pyrind's `aes_key_wrap_with_padding`.

## Plan

[moq-dev/rind#359](https://github.com/moq-dev/rind/pull/359) adds RFC 3394 key wrap on AES decryption for every backend; KWP builds on it, with the same API shape and the same constant-time integrity check that clears the output on failure. Test against Wycheproof's KWP vectors and aws-lc-rs. Start once #359 has landed.
