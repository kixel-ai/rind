# [XS] rind-jsonwebtoken and rind-instant-acme check the CPU themselves

## Goal

Every adapter refuses a CPU missing a feature rind requires through its own API, returning its own `MissingFeature`, so no adapter's user depends on `rind` directly just to call `rind::cpu::check()`.

## Plan

Decided with the maintainer on 2026-11-07. Since [moq-dev/rind#420](https://github.com/moq-dev/rind/pull/420), rind-rustls, rind-dimpl, and rind-object-store refuse such a CPU in `default_provider()`, returning their own `MissingFeature`. rind-jsonwebtoken and rind-instant-acme expose a `DEFAULT_PROVIDER` static instead, and their docs tell callers to run `rind::cpu::check()` first, which needs `rind` as a direct dependency.

- Replace each public `DEFAULT_PROVIDER` with `default_provider() -> Result<&'static CryptoProvider, MissingFeature>`, matching the other adapters' name and error. Keep one way to do it: the static becomes private. If an upstream API needs something other than `&'static`, say so in the PR.
- Release this with rind-jsonwebtoken 11.0.0, before the open release PR publishes it, so the break rides the major bump the adapter-version change already takes. rind-instant-acme is unpublished.
- Update the READMEs, crate docs, MIGRATING.md, and MIGRATE.md examples.
