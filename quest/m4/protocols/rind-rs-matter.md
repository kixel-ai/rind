# [M] rind-rs-matter, an rs-matter crypto backend on rind

## Goal

A `rind-rs-matter` crate implements rs-matter's public crypto trait on rind, so a Rust Matter device can commission and run its secure sessions with no other cryptography crate.

## Plan

- rs-matter 0.4.1's public `rs_matter::crypto::Crypto` trait asks its backend for raw P-256 arithmetic (`EcScalar` and `EcPoint` with mul, neg, and add_mul) and AES-128-CCM, and runs its own SPAKE2+ over them. An adapter on that trait cannot use `rind::spake2plus`; it would need rind to expose scalar and point arithmetic, which [the protocols epic](/quest/m4/protocols/README.md) keeps crate-internal.
- Decided with the maintainer on 2026-11-12: ✅ not yet (rejected: widen rind's public API now; drop the adapter). Build it when a user needs it or rs-matter offers an API that takes SPAKE2+ whole.
- Follow `AGENTS.md`'s adapter rules: its own crate, exactly the API rs-matter's upstream backend offers, its README listing what rind cannot back, and a version beginning with the breaking part of rs-matter's.

## Waiting

- project-chip/rs-matter: a public crypto API that takes SPAKE2+ whole, so the adapter can back it with `rind::spake2plus`, or a user who needs the adapter on the current trait. On 2026-11-12, rs-matter 0.4.1's `Crypto` trait took raw P-256 arithmetic and AES-128-CCM. Check the newest release's `rs_matter::crypto` docs on docs.rs, and rind's and rs-matter's issue trackers for a request.
