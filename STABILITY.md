# Stability

[README.md](README.md#versions) says what a version number promises: below 1.0 a minor release may break the API, a patch release adds API and fixes bugs, and each adapter's version follows the upstream it adapts. This file says what is checked before a release, and what 1.0 waits on.

## Checked before every release

- **A break needs a mark.** `sh/semver.sh`, in `just ci`, runs cargo-semver-checks on each published crate a branch changes, comparing it with the same crate at the branch's merge-base, not with crates.io, since `main` holds every breaking change the next minor release batches. A break in `rind` fails unless the PR title or a commit subject carries `!` (`feat!: ...`); a break in an adapter fails even then, unless the change sets its version to its upstream's next breaking release, since an adapter's API is its upstream's. `pr-check.yml` passes the PR title, so a PR retitled with `!` needs a new push to rerun; the merge queue reads the squash commit.
- **Releases.** release-plz runs the same tool when it opens a release PR, and proposes the next breaking version when it finds a break. `sh/adapter-versions.sh` fails an adapter version that drifts from its upstream's, and `admin/adapter-api` fails an adapter whose API differs from its upstream's. [CONTRIBUTING.md](CONTRIBUTING.md#releases) has the rest.
- **Rust version.** Each crate's `rust-version` is built and linted on in CI (`msrv`), and rises only as README.md says.
- **Changelogs.** `rind/CHANGELOG.md` lists the commits that touch `rind/`. `rind/README.md` is a copy of the repository's `README.md`, checked by `just ci`, not a symlink to it: release-plz counts a commit that touches a symlink's target as touching the crate, so every edit to the front door entered rind's changelog.

## Before 1.0

README.md names three conditions, and each is open work:

- The API takes one shape. The per-algorithm signature modules landed in [kixel-ai/rind#781](https://github.com/kixel-ai/rind/pull/781); [the API epic](quest/m2/api/README.md) holds what remains.
- Every key type loads, exports, and names things the same way.
- No breaking change is planned. [rind 0.4 ships once](quest/m2/api/release-0.4.md) carries every one planned so far.

What rind lacks today, which README.md also says:

- An outside audit: README.md says no one outside the project has audited rind, and [the audit scope quest](quest/m2/trust/third-party-audit-scope.md) prepares one.
- FIPS 140-3 validation.

The checks a release already passes are in [TESTING.md](TESTING.md): constant time (ctgrind and the `ct-vartime` scan), fuzzing, nightly coverage, mutation testing, and the proofs a release waits for.
