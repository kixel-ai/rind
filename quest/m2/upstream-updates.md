# [M] Take what rind's upstreams changed since their pins

## Goal

Every upstream rind copies, ports, depends on, tests against, or takes design from is checked for changes since the revision rind pins: security fixes first, then bug fixes, speedups, and newly proven code. Pins whose importer reruns cleanly are bumped in this PR, any security fix is taken outright, and each change that needs a hand port or a design decision is planned as a follow-up.

## Plan

Planned with the maintainer on 2026-11-13: ✅ recurring, one run per milestone (rejected: monthly, quarterly), ✅ in m2 (rejected: m0), ✅ first run now (rejected: after m1 finishes), ✅ never ends (rejected: at rind 1.0).

- Recurring. The PR that finishes this run deletes this file and creates the next run at `/quest/m3/upstream-updates.md`, with `Required` linking `/quest/m2/README.md`, so it runs once m2 is done. Each later run moves up one milestone the same way, creating the milestone if needed. The next run keeps this Goal and these decisions, and its Plan replaces this run's baseline and findings with its own: the pins it left, what it took, and what to check first.
- Scope (maintainer, 2026-11-13): ✅ copied and ported code, crate dependencies, test vector sources, and projects rind takes design from.
  - Copied: aws-lc, BoringSSL, and OpenSSL through `admin/import-*`'s `REV`; HACL\* and Vale through `admin/import-hacl`; s2n-bignum through its submodule.
  - Ported by hand: mlkem-native, mldsa-native, curve25519-dalek's AVX2 backend, cifra, SUPERCOP's `neon2`. ALGORITHMS.md's Sources table names what each supplies.
  - Crates: libcrux-\*, fiat-crypto, curve25519-dalek, and the adapters' upstreams. Dependabot proposes their minor and patch releases ([its quest](/quest/m0/dependabot-cargo.md)); the run reviews majors, which for an adapter's upstream mean a new `rind-<consumer>` release, and plans each as a follow-up.
  - Vectors: Wycheproof, CAVP, and CCTV submodules, `admin/sync-acvp`, and `admin/sync-vectors`'s sources.
  - Design: Graviola (rind's origin, no longer tracked), RustCrypto, ring, and libsodium. rind copies nothing from them now, so what they change becomes a follow-up, never a bump.
  - Out of scope: proof tooling and proof projects (Aeneas, Charon, aws-lc-verification, s2n-bignum's new theorems), which [the re-audit](/quest/m4/verified/re-audit.md) surveys; and reporting rind's workarounds, which [upstream-reports](/quest/m2/upstream-reports.md) owns.
- Deliverable (maintainer, 2026-11-13): ✅ bump each pin whose importer reruns cleanly and whose tests, `admin/prove bytes`, and benchmarks hold, and take security fixes outright; plan hand ports and design changes as sized follow-ups (rejected: port everything in the run, which would grow some runs to XL). A bump that moves code a proof covers keeps the proof's revision in step, as ALGORITHMS.md's links pin it.
- Read each upstream's security advisories and changelog since its pin before its commits; nothing else watches advisories for copied assembly, since cargo-deny sees only crates.
- This run's baseline, unchanged since each pin was taken: aws-lc `91c93a8e`, BoringSSL `ed9209cf`, OpenSSL `2f4e3a5f`, HACL\* `f5572590`, s2n-bignum `b4f17ee7`, mlkem-native `d1b2fe78`, mldsa-native v2.0.0, Wycheproof `dab4ea2e`, CAVP `0220357e`, CCTV `b88c4b20`, ACVP-Server `975de31e`, and `admin/sync-vectors`'s aws-lc `2f9a0e95` and BoringSSL `0131ae9d`.
