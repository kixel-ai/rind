# [S] llrt offers rind

## Goal

[llrt](https://github.com/awslabs/llrt), AWS's low-latency JavaScript runtime
for Lambda, offers rind behind `crypto-rind` and `tls-rind` features next to
its `crypto-graviola` and `tls-graviola`
([llrt_crypto's Cargo.toml](https://github.com/awslabs/llrt/blob/main/modules/llrt_crypto/Cargo.toml)),
in a merged upstream PR.

## Plan

- Lambda runs x86_64 and arm64, both rind targets, and llrt already accepts a
  pure-Rust backend, so the pitch is rind's broader coverage than graviola's
  for its WebCrypto and `node:crypto` surface, and its speed on Graviton.
- llrt's graviola backend fills its gaps from RustCrypto (AES-CBC, AES-CTR,
  AES-KW, RSA-OAEP, MD5, and more); with the WebCrypto epic done, the rind
  backend implements llrt's whole `CryptoProvider` trait on rind alone.
- Benchmark llrt's crypto on its graviola and rind builds and put the numbers
  in the PR.

## Required

- [What WebCrypto adopters need](/quest/m2/adoption/webcrypto/README.md) - the operations llrt's provider trait needs that rind lacks
