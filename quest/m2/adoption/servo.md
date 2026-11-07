# [L] Servo's WebCrypto runs on rind

## Goal

A PR to [Servo](https://github.com/servo/servo), with numbers, moves every
WebCrypto operation rind covers in `components/script_webcrypto` from
RustCrypto onto rind, as Deno's swap does.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview.

- Servo is moving its WebCrypto from aws-lc-rs to RustCrypto for one Rust
  ecosystem ([servo/servo#49215](https://github.com/servo/servo/issues/49215)),
  and RustCrypto's pbkdf2 already times out in WPT in unoptimized builds
  ([servo/servo#49227](https://github.com/servo/servo/pull/49227)). The pitch
  is pure Rust at aws-lc's speed. Read #49215's reasons first: if they rule
  out a second library, raise it before building anything.
- What rind lacks (Ed448, X448, ML-DSA, AES-OCB, Argon2) stays on RustCrypto.
- Servo builds for desktop, Android, and OpenHarmony; check each target
  against rind's before proposing.
- Posting is the maintainer's call; prepare the branch and text, then ask.
