# [XS] Scope check:site to site inputs and drop its duplicate PR run

## Goal

`check:site` in `sh/dispatch.sh` runs only when a diff touches `site/`, `sh/site.sh`, or one of the repository files `site/src/lib/repo.ts`'s `sources` reads (plus file deletions/renames that could break repo links), and pull requests no longer run the site build twice across both `site.yml` and `pr-check.yml`.

## Plan

Measured across recent PR and merge-queue runs: `check:site` runs `bun install --frozen-lockfile`, `bun test`, `bun run build`, and headless Chrome (`sh/site.sh`) for 43–151s on **every** diff (`module site ''` in `sh/dispatch.sh`), including pure quest or Rust PRs, and `site.yml` runs the exact same `sh/site.sh` a second time in parallel on every pull request.

- ✅ Scope `check:site` to site/doc/README paths only and eliminate the duplicate run between `pr-check.yml` and `site.yml` (maintainer, 2026-11-21).
- `site/src/lib/repo.ts` already declares the exact repository files `site/` reads (`README.md`, `BENCHMARKS.md`, `MIGRATING.md`, `benchmarks/report.json`, `admin/wordmark.svg`, `admin/wordmark-light.svg`, and each routed adapter's `README.md` and `Cargo.toml`). Scope `module site` in `sh/dispatch.sh` to those paths plus `site/`, `sh/site.sh`, and `flake.lock` (and keep a lightweight link check or nightly `just ci --all` catching renamed/deleted linked repo files).
- Remove the duplicate run by either dropping `site.yml` (letting path-scoped `pr-check.yml` cover it) or keeping `site.yml` with matching `pull_request.paths` and skipping `site` in `pr-check.yml` (`CHECK_MODULES=-site`). Prefer dropping `site.yml` if `pr-check.yml` already runs `check:site` on matching diffs, so the path list lives in one place (`sh/dispatch.sh`).

## Related

- [Thin the self-hosted merge queue to host rs and fast lints](/quest/m0/ci-speed/thin-merge-queue.md) - removes `check:site` from `queue-build.yml`
- [PR checks stop running for results no one reads](/quest/m0/ci-speed/unread-results.md) - trims `pr-check.yml` to fast checks
