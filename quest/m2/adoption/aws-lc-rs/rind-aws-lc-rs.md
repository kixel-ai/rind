# [L] rind-aws-lc-rs offers aws-lc-rs's API on rind

## Goal

A published `rind-aws-lc-rs` 1.x offers aws-lc-rs 1.x's API, name for name, for every item rind can back. A crate on aws-lc-rs switches with `aws-lc-rs = { package = "rind-aws-lc-rs", version = "1" }` and no code changes.

## Plan

- Start from what aws-lc-rs's consumers call: rustls's `aws_lc_rs` provider, rustls-webpki, quinn-proto, s2n-quic-crypto, libp2p, jsonwebtoken, and rcgen. Cover those items first, then the rest of the public API rind can back. Items rind refuses, such as FIPS mode, `unstable`, or primitives rind lacks, stay out so code using them fails to build. The README lists them, as rind-ring's does.
- Share code with rind-ring where aws-lc-rs keeps ring's API, rather than copying it. Behavior follows aws-lc-rs where it differs from ring, such as errors and accepted encodings.
- Accept aws-lc-rs's features (`aws-lc-sys`, `prebuilt-nasm`, `bindgen`, `fips`, and so on) where a build can safely ignore them. Refuse `fips`, since rind isn't validated.
- Test it differentially against aws-lc-rs, and hold its version to aws-lc-rs's major with `sh/adapter-versions.sh`.
