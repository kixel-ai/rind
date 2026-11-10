# [XS] HKDF's key conversions are proven

## Goal

HKDF's `From<Okm>` impls for `aead::Key`, `aead::quic::HeaderProtectionKey`, `hmac::Key`, and `Prk` (`rind/src/high/hkdf.rs`) are proven in `proofs/` to fill each key from `kdf.hkdf_fill`'s bytes, composing with the HKDF theorems in `Rind/<Arch>/Hkdf.lean`, on x86_64 and aarch64.

## Plan

Split out of [the hash-glue quest](/quest/m2/verified/hash-glue.md) with the maintainer on 2026-11-07, after [moq-dev/rind#476](https://github.com/moq-dev/rind/pull/476): these conversions need no HOL Light, so they shouldn't wait behind the HOL Light tree as the compares did.

- Each impl is a thin wrapper over `fill`; prove it with the same Aeneas translation and `admin/prove` flow #476 used.
- The resulting keys feed QUIC's packet protection, so state the theorem in terms the AEAD and header-protection proofs can consume.
- The impls are at `rind/src/high/hkdf.rs:201`, `:208`, and `:215`, and a fourth at `:221`, `From<Okm<'_, &'static hkdf::Algorithm>> for Prk`, which [moq-dev/rind#531](https://github.com/moq-dev/rind/pull/531) added to chain one expand into the next as QUIC's key schedule does. Prove all four.
