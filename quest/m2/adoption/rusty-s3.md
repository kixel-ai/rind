# [XS] rusty-s3 offers rind

## Goal

[rusty-s3](https://github.com/paolobarbolini/rusty-s3), an S3 request signer,
offers a `rind` feature next to its `rustcrypto`, `aws-lc-rs`, and `graviola`
ones ([Cargo.toml](https://github.com/paolobarbolini/rusty-s3/blob/main/Cargo.toml)),
in a merged upstream PR.

## Plan

It needs only SigV4's HMAC-SHA256 and SHA-256, and the maintainer already
accepts alternative backends, so the PR should be small. Follow its existing
feature pattern and test matrix.
