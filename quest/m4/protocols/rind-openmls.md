# [M] rind-openmls runs MLS on rind

## Goal

A published `rind-openmls` adapter implements openmls's `OpenMlsCrypto` provider traits on rind, covering the MLS ciphersuites rind's primitives back, so an openmls user drops its RustCrypto or libcrux provider for rind.

## Plan

Decided with the maintainer on 2026-11-07, as a follow-up from [moq-dev/rind#449](https://github.com/moq-dev/rind/pull/449). openmls needs HPKE with the exporter, which [HPKE](/quest/m4/protocols/hpke.md) builds, plus AEADs, HKDF, and signatures rind already has.

- Follow the adapter rules: its own crate, a version matching openmls's breaking version (CONTRIBUTING.md's Releases), its own `MissingFeature` from `default_provider()`, and no re-exported rind types.
- Run openmls's provider test suite and its interop tests against the RustCrypto provider. Document unsupported ciphersuites, such as X448 and Ed448, in the README.

## Required

- [HPKE and ECH](/quest/m4/protocols/hpke.md) - the HPKE openmls needs
