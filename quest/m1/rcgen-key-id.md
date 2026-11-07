# [XS] rind-rcgen sets subject key identifiers as rcgen does

## Goal

Certificates made with rind-rcgen carry the same subject and authority key identifiers that rcgen gives them with its `crypto` feature: a SHA-256 of the public key, truncated to 20 bytes. Chains built on rind then match those built on rcgen's own backend.

## Plan

Decided with the maintainer on 2026-11-07, as a follow-up from [moq-dev/rind#451](https://github.com/moq-dev/rind/pull/451). Without `crypto`, rcgen leaves the key identifier empty unless the caller sets `CertificateParams::key_identifier_method` by hand.

- Offer the smallest API that fills it in, such as a `key_identifier(&KeyPair) -> KeyIdMethod` helper or a params constructor. Check what rcgen's API allows, and match rcgen's bytes exactly.
- Test that a chain made on rind-rcgen has the same identifiers as one made on rcgen with `aws_lc_rs`, and that webpki accepts it under rind-rustls.
