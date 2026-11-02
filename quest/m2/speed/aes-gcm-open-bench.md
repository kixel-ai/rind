# [XS] The AES-GCM bench times decryption

## Goal

The `aes_gcm` bench times opening (decrypt and verify) beside sealing, against aws-lc-rs and ring, at the epic's sizes, so the decrypt paths' speed shows on every tier.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#240](https://github.com/moq-dev/rind/pull/240), whose new `aesni_gcm_decrypt` path has no timing yet.

- Add the open rows; refresh README's AES-GCM cells from the next runner bench if any open row is the worst.
