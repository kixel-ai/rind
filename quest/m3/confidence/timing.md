# [M] Statistical timing tests

## Goal

A slow workflow runs dudect-style statistical timing tests on every secret operation. On the RSA paths it also runs tlsfuzzer's Marvin toolkit against PKCS#1 v1.5 and OAEP decryption, so timing leaks that no static check models show up on real hardware.

## Plan

- dudect compares the timing distributions of two classes of secret input; use an existing Rust harness such as `dudect-bencher` if it fits. Run on GitHub's x86_64 and arm64 runners, and on `desktop`, `nixos`, and `kixtop` held with `quest gate --host`.
- Marvin: follow the toolkit's own instructions for library testing, as aws-lc did after the Marvin attack.
- A finding is a bug: fix it or plan a quest. Don't tune thresholds until a test passes.
