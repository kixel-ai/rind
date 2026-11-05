# [XS] MD5

## Goal

rind offers MD5 under a `legacy` module, as it does SHA-1, for hashing APIs
that expose it (llrt's and Bun's node:crypto, pyrind, Dart).

## Plan

Decided with the maintainer on 2026-11-04 ✅ over refusing it. aws-lc-rs
does not export MD5, so the differential test runs against another
implementation such as RustCrypto's md-5. Never offer it as a signature or
HMAC hash.
