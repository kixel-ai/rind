# [L] rind for Dart and Flutter

## Goal

The `rind` package on pub.dev brings rind to Dart and Flutter through FFI,
with rind's own API, built by Dart's native-asset hooks for Android (aarch64,
armv7, x86_64), iOS, macOS, Linux, and Windows, where pure-Dart crypto
(pointycastle, `cryptography`'s Dart backend) is up to 100x slower.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview:

- Two packages, as rind and rind-ring are: this one with rind's own API, and
  [a `cryptography` backend](/quest/m2/adoption/rind-dart-cryptography.md) on
  top ✅ / one package.
- It lives in this workspace as a `rind-dart` crate with its Dart package,
  released by this repository's CI ✅ / a separate repository.

Guidance:

- Google's webcrypto.dart bundles BoringSSL through native assets
  ([google/webcrypto.dart#334](https://github.com/google/webcrypto.dart/pull/334));
  follow that build shape.
- Flutter web has no rind (no wasm); the package refuses that target rather
  than falling back.
- Benchmark on a real Android armv7 or aarch64 phone against pointycastle and
  `cryptography`, where rind's lead is largest.
