# [XS] HKDF's key conversions are proven

## Goal

HKDF's `From<Okm>` impls for `aead::Key`, `aead::quic::HeaderProtectionKey`, and `hmac::Key` (`rind/src/high/hkdf.rs`) are proven in `proofs/` to fill each key from `kdf.hkdf_fill`'s bytes, composing with the HKDF theorems in `Rind/<Arch>/Hkdf.lean`, on x86_64 and aarch64.

## Plan

Split out of [the hash-glue quest](/quest/m2/verified/hash-glue.md) with the maintainer on 2026-11-07, after [moq-dev/rind#476](https://github.com/moq-dev/rind/pull/476): these conversions need no HOL Light, so they shouldn't wait behind [hol-light.md](/quest/m3/verified/hol-light.md) as the compares do.

- Each impl is a thin wrapper over `fill`; prove it with the same Aeneas translation and `admin/prove` flow #476 used.
- The resulting keys feed QUIC's packet protection, so state the theorem in terms the AEAD and header-protection proofs can consume.
- The three impls are at `rind/src/high/hkdf.rs:190`, `:197`, and `:204`. [moq-dev/rind#531](https://github.com/moq-dev/rind/pull/531), open on 2026-11-09, adds a fourth, `From<Okm<'_, &'static hkdf::Algorithm>> for Prk`, which chains one expand into the next as QUIC's key schedule does. Once it lands, prove that one here too.
