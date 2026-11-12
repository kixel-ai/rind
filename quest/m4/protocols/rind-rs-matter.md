# [M] rind-rs-matter backs Matter commissioning on rind

## Goal

A published `rind-rs-matter` adapter implements the crypto provider rs-matter ships, including Matter PASE on `rind::spake2plus::MATTER_PASE`, so an rs-matter device can drop its built-in SPAKE2+.

## Plan

Follow-up from SPAKE2+ landing in `rind::spake2plus`. The in-tree differential stays `matter-crypto` 0.5.1 (`high::spake2plus::matches_matter_crypto`): rs-matter 0.4.1 keeps `sc::pase::spake2p` `pub(crate)`, and `deny.toml` refuses a git dependency, so this crate cannot test against that module until a release exports it.

- Follow the adapter rules: its own crate, a version that begins with rs-matter's breaking version (`CONTRIBUTING.md`'s Releases), no re-exported rind types, and exactly the API of the provider rs-matter ships, adding nothing (`AGENTS.md`, [the adapters epic](/quest/m0/adapters/README.md)). The README lists only what rind cannot back.
- PASE calls `MATTER_PASE`, draft-bar-cfrg-spake2plus-01, not `RFC9383`. The caller still stretches the passcode, as both specifications leave that step outside the handshake, unless the provider rs-matter ships folds it in.
- Test against rs-matter's own provider tests once that API is public. Do not take rs-matter from git.

## Waiting

- project-chip/rs-matter: a crates.io release whose crypto provider, or `sc::pase::spake2p`, is public. 0.4.1 keeps `sc::pase::spake2p` `pub(crate)` (`rs-matter/src/sc/pase.rs`).
