# [XS] rind-rcgen users don't depend on rind directly

## Goal

rind-rcgen offers `check() -> Result<(), MissingFeature>` with its own `MissingFeature`, and `serial_number() -> rcgen::SerialNumber`, which draws a random 16-byte positive serial. With those, its README's example needs no direct `rind` dependency, like every other adapter's.

## Plan

Decided with the maintainer on 2026-11-07, following [moq-dev/rind#445](https://github.com/moq-dev/rind/pull/445). rcgen built without its default features needs each certificate's serial number set by hand, so the README calls `rind::rand::fill`, and it tells users to call `rind::cpu::check()`. rcgen's key generation returns rcgen's own error type, so the CPU check stays a separate function rather than going through `KeyPair::generate`.

- Match the `MissingFeature` the other adapters define since [moq-dev/rind#420](https://github.com/moq-dev/rind/pull/420).
- Serial numbers: follow RFC 5280's at-most-20-octet positive integer. Check what rcgen and aws-lc-rs-backed rcgen generate, and match them.
- Additive, so it can ship with rind-rcgen 0.14.0 or later. Update the README, crate docs, and MIGRATING.md.
