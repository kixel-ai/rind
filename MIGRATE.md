# Migrate a repository to rind

These are instructions for a coding agent. The user's prompt sent you here to
move their Rust repository from ring or aws-lc-rs to
[rind](https://github.com/moq-dev/rind), on a local branch, and to report
what changed. Follow them in order.

Never push, open a PR, or file an issue unless the user agrees when you offer
it at the end. Work only in their repository and its ignored scratch space.

## 1. Survey

Start from a clean checkout of the default branch, and note its commit.

1. Find where ring and aws-lc-rs come from, with the default features and
   each feature set the project's release or CI builds:

   ```sh
   cargo tree --locked --target all -e normal,build -i ring
   cargo tree --locked --target all -e normal,build -i aws-lc-rs
   cargo tree --locked --target all -e normal,build -i aws-lc-sys
   ```

   Each path reaches them in one of four ways:

   - **rustls, or a crate above it**, such as reqwest, hyper-rustls, tonic,
     or ureq.
   - **A crate a `rind-*` adapter serves**: rcgen, dimpl, jsonwebtoken,
     object_store, or instant-acme.
   - **The project calls ring's API.**
   - **The project calls aws-lc-rs's API.**

   Look up each crate in [MIGRATING.md]'s "Crates with their own crypto
   backend". A crate listed as Unsupported, or one not listed whose source
   calls ring or aws-lc-rs with no feature or hook to replace it, hard-wires
   them. Dev-dependencies may keep ring; only what ships must move.

2. Find the release targets: the CI release workflow, `dist-workspace.toml`
   or `[workspace.metadata.dist]`, `Cross.toml`, and the install docs. rind compiles only for x86_64, aarch64, and 32-bit ARM, so i686,
   wasm32, riscv64, and every other architecture fail to build. Within those
   three, a target rind's CI does not cover yet, such as musl, aarch64
   Windows, iOS, Android, or ARM older than ARMv7, may still fail: step 4
   builds each one.

3. Compare the project's `rust-version` with the latest rind release's,
   which `cargo info rind` prints. If the project's is older, ask the user
   whether to raise it, and stop if they decline.

Stop here, before changing anything, if a release target is on another
architecture, a dependency hard-wires ring or aws-lc-rs in what ships, or the
project calls an item rind lacks: one [MIGRATING.md] maps to none or, through
ring's API, one [rind-ring's README] leaves out. Check every condition, then
report each that holds in the format of step 5, without the table, naming the
target, dependency path, or item, and make the offers in step 6. Do not patch
around a dependency or migrate part of the graph: a build that still links
ring or aws-lc-rs gains nothing.

## 2. Measure before

Measure on the default branch, then on the migrated branch, with the same
toolchain, command, and profile, back to back, on an otherwise idle machine.

1. Read the project's CI to find its build, test, and benchmark commands and
   its release profile and features. Use those, adding `--locked`.
2. Run `cargo fetch`, so downloads stay out of the timing.
3. Time a clean release build: `cargo clean`, then the release build
   command, timed with `time`.
4. For each binary the project releases, strip a copy with the platform's
   `strip` and record its size in bytes.
5. Run the tests and record what passes and fails.
6. Run the project's existing benchmarks that exercise TLS, hashing, signing,
   or encryption, and save their output. Note any you skip and why, such as
   one that runs for hours. Write no new benchmarks.

## 3. Migrate

Create a branch named `rind`. Add the latest crates.io release of each rind
crate you use, and change no unrelated dependency: run `cargo update -p` only
for crates whose features you change, never a bare `cargo update`.

[MIGRATING.md] on `main` may name items that are not released yet. Check the
docs.rs page of the version you added; an unreleased item counts as missing.

For each way the survey found:

- **rustls and the crates above it.** Depend on `rind-rustls`. Turn off each
  crate's default provider feature and turn on the providerless one that
  [MIGRATING.md] lists, such as reqwest's `rustls-no-provider`. Then either
  pass `rind_rustls::default_provider()?` where the crate takes a provider,
  or install it as the process default before any TLS config is built:

  ```rust
  rind_rustls::default_provider()?.install_default().expect("no provider installed yet");
  ```

  Install it in each binary's `main` and in each test or example that builds
  a TLS config.
- **A crate a `rind-*` adapter serves.** Follow the adapter's row in
  [MIGRATING.md] and its README.
- **ring's API.** Rename the dependency, with no code changes:
  `ring = { package = "rind-ring", version = "0.1" }`. Where a library
  exposes ring's types in its public API, the rename changes them to
  rind-ring's, which breaks its users: say so in the report.
- **aws-lc-rs's API.** Port each call to rind's, using MIGRATING.md's tables.

rind panics on a CPU missing a feature it requires. Unless the binary already
fails on the error `rind_rustls::default_provider()` returns, call
`rind::cpu::check()` at the start of its `main` and exit with that error.

Commit as you go, with messages in the project's style.

## 4. Verify and measure after

1. Confirm nothing that ships links ring or aws-lc-rs: for each feature set,
   the three `cargo tree` commands from the survey print no dependency path,
   or only dev-dependencies.
2. Build each release target, adding its standard library with
   `rustup target add` where you can. Where the host has the target's linker,
   run the release build with `--target`. Otherwise run
   `cargo build --release --target <target> -p rind`, which assembles rind
   without linking, and report the target as built but not linked. Report a
   target whose standard library you cannot install as not built. A target
   that fails to build stops the migration: report it as a rind gap.
3. Repeat every measurement from step 2, the same way.
4. Run the project's own lints and checks, such as clippy, `cargo fmt`, and
   cargo-deny. rind's licenses include ISC and MIT-0, which a
   cargo-deny allow list may need.

A test that fails only after migrating is a finding to diagnose: a mistake in
your migration gets fixed, and a difference in rind is reported as a rind gap,
never hidden by changing the test.

## 5. Report

Reply with this report, filling in every row:

```markdown
## rind migration: <repository> at <commit>

**Result**: migrated on local branch `rind` (<n> commits) | stopped: <reason>

| | ring or aws-lc-rs | rind | Change |
|---|---|---|---|
| Clean release build (`<command>`) | <seconds> s | <seconds> s | <percent> |
| Stripped `<binary>` | <bytes> | <bytes> | <percent> |
| Tests (`<command>`) | <passed>/<total> | <passed>/<total> | |
| `<benchmark>` | <time> | <time> | <percent> |

- **Release targets**: each target, and built, built without linking, not
  built, or failed.
- **How it moved**: each path from the survey, and what changed for it.
- **Still linked**: dev-dependencies that keep ring or aws-lc-rs, or none.
- **Breaking changes**: any change users see, such as a raised
  `rust-version`, ring's types changed in a public API, or architectures
  that built from source before and no longer do, or none.
- **rind gaps**: anything missing, slower, or harder than it should be, or
  none.
- **Host**: CPU, OS, and `rustc --version`.
```

Give a percentage as the change from before to after, negative when rind is
smaller or faster. Leave out a row that does not apply, such as a binary for
a library, and say why below the table.

## 6. Offer

Ask the user, and do each only if they agree:

1. **Open a PR on their repository** from the `rind` branch, with the report
   as its description.
2. **File an issue on [moq-dev/rind](https://github.com/moq-dev/rind/issues)**
   for each rind gap. Search its open issues and the plans under
   [`quest/`](https://github.com/moq-dev/rind/tree/main/quest) first, and
   comment on a match instead of filing a duplicate. Each issue names the
   repository, the item or target, and how the project uses it, and ends
   with `(Written by <your model>)`.

[MIGRATING.md]: https://raw.githubusercontent.com/moq-dev/rind/main/MIGRATING.md
[rind-ring's README]: https://raw.githubusercontent.com/moq-dev/rind/main/rind-ring/README.md
