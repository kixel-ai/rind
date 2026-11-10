# [S] rind 0.4 ships once

## Goal

rind 0.4.0 on crates.io carries all three of the API epic's breaking changes: the typed AES-CBC IV, agreement keys that keep their public key, and no runtime CPU check. No release before it carries only some of them, and each adapter moves its `rind` requirement from 0.3 to 0.4 once, in a patch release from the same release PR.

## Plan

Decided with the maintainer on 2026-11-09:

- Releases: one rind 0.4 that carries all three breaking changes, and a MoQ-side PR ready before the m0 adapter patch releases publish ✅ (rejected: the 0.4 quest alone, accepting that MoQ's build breaks until fixed; leaving both to release-plz). The MoQ half is in [Adapters offer exactly their upstream's API](/quest/m0/adapters/README.md).

Three breaking releases would re-pin every adapter three times, and each would leave a consumer that pins rind 0.3 with two copies of rind until it follows, the cost [moq-dev/rind#512](https://github.com/moq-dev/rind/pull/512) avoided for a README edit.

The three changes are [moq-dev/rind#530](https://github.com/moq-dev/rind/pull/530) (`AesCbcEncryptingKey` takes a `CbcIv`), [moq-dev/rind#529](https://github.com/moq-dev/rind/pull/529) (`agreement::PrivateKey::public_key()` returns a borrow), and [rind needs no runtime CPU check](/quest/m2/api/cpu-check.md).

The hold uses only what the release tooling has. Publishing happens only when a release PR merges (`CONTRIBUTING.md:138`, `.release-plz.toml:6`), and one release PR covers every crate, as [moq-dev/rind#511](https://github.com/moq-dev/rind/pull/511) does. So the hold is the maintainer leaving the release PR unmerged, and while it lasts no adapter fix and no pyrind release publishes either. In order:

1. [moq-dev/rind#511](https://github.com/moq-dev/rind/pull/511) merges first and publishes rind 0.3.3. `rind/Cargo.toml:3` is set by hand to 0.3.3, ahead of crates.io's 0.3.2, and a version set by hand ahead of the published one is kept as is (`CONTRIBUTING.md:146`), so a breaking change merged before it would publish as 0.3.3.
2. The m0 adapter patch releases publish next, before any of the three merges, so those fixes never sit behind the hold. Each m0 PR sets its adapter's patch version by hand (`CONTRIBUTING.md:145`), as [moq-dev/rind#522](https://github.com/moq-dev/rind/pull/522) does. On 2026-11-09, [moq-dev/rind#515](https://github.com/moq-dev/rind/pull/515), [moq-dev/rind#516](https://github.com/moq-dev/rind/pull/516), [moq-dev/rind#519](https://github.com/moq-dev/rind/pull/519), and [moq-dev/rind#521](https://github.com/moq-dev/rind/pull/521) did not, and their `!` titles make release-plz propose the next breaking adapter version, which `sh/adapter-versions.sh` fails (`CONTRIBUTING.md:144`). The last of them also edits the root `README.md`, which `rind/README.md` links to, so release-plz counts its `!` against rind and proposes 0.4.0, as it did for [moq-dev/rind#510](https://github.com/moq-dev/rind/pull/510). If it does, set rind's next patch version by hand, as [moq-dev/rind#512](https://github.com/moq-dev/rind/pull/512) did, so 0.4.0 is not spent on a README edit.
3. The three merge only while `rind/Cargo.toml`'s version equals the one `cargo search rind` shows, for the reason in step 1. From the first of them, the release PR proposes rind 0.4.0, since a `!` commit against rind forces the breaking bump, as [moq-dev/rind#512](https://github.com/moq-dev/rind/pull/512) records. The CPU-check removal waits on the whole m0 epic, so merge the other two once it is ready too, which keeps the hold short.
4. Before the 0.4.0 release PR merges, check that it moves each adapter's `rind = "0.3.2"` requirement (`rind-rustls/Cargo.toml:13` and its siblings) to 0.4 as a patch release. If it proposes a breaking version for an adapter, `sh/adapter-versions.sh` fails it; the adapter's API did not change, so set its patch version by hand (`CONTRIBUTING.md:146`).

Each change documents its own migration in MIGRATING.md, so this quest adds none. Delete it once 0.4.0 is published.

The benchmark report is refreshed once before each minor release (maintainer, 2026-11-09), so this quest requires that run. Whoever plans the next minor release's quest creates the next run at the same path, from the last one in git history, and requires it.

## Waiting

- Maintainer: once [moq-dev/rind#511](https://github.com/moq-dev/rind/pull/511) and the m0 adapter patch releases have published, merge no release PR until all three changes are on `main`, then merge the one that proposes rind 0.4.0. An agent cannot: a release PR merges on the maintainer's approval (`CONTRIBUTING.md:118`), and `.release-plz.toml` configures no way to hold one crate back, which is why the hold is the unmerged PR. Check: `cargo search rind` shows 0.4.0.

## Required

- [Benchmark report refresh, before rind 0.4](/quest/m2/bench/report-refresh.md) - the report and the README's claims, current for the release
- [AES-CBC encryption takes a typed IV](/quest/m2/api/cbc-iv.md) - the `CbcIv` argument, the first breaking change
- [Agreement keys keep their public key and algorithm](/quest/m2/api/agreement-key-state.md) - `public_key()` returning a borrow, the second
- [rind needs no runtime CPU check](/quest/m2/api/cpu-check.md) - `cpu::check` and `MissingFeature` removed, the third

## Related

- [Adapters offer exactly their upstream's API](/quest/m0/adapters/README.md) - its patch releases publish before the hold starts
