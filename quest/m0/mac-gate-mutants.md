# [XS] The mutants gate runs on macOS

## Goal

`CI_STRICT=1 quest gate sh/dispatch.sh ci upstream/main` on an Apple-silicon Mac selects the `mutants` module, needs only python3 for it, and passes: it runs the self-test, runs the pin check where `cargo-mutants` is installed, and says so when it skips. Linux behavior is unchanged, and `admin/mutants` on a Mac lists instead of failing with `no campaign for arm64`.

## Plan

`admin/mutants` has campaigns for x86_64 and aarch64 Linux only: its skipped files and CPU-feature rows name those hosts, and a whole campaign runs only on GitHub-hosted runners. On a Mac, `sh/dispatch.sh`'s `mutants` module demands `cargo-mutants`, and `check:mutants` then dies with `no campaign for arm64`, so the Mac's gate fails before anything about rind is checked. [The merge queue runs rind's tests natively on aarch64](/quest/m0/mac-mini-runner.md) runs this same gate on the Mac mini, and [Apple-silicon nightlies run on the Mac mini](/quest/m2/confidence/apple-nightlies.md) is about scheduled jobs, not the gate, so neither covers it.

[steelhead99x/rind#247](https://github.com/steelhead99x/rind/pull/247) (`claude/mac-gate-fixes`, a fork PR, +23 / -2 in `admin/mutants`, `sh/dispatch.sh`, and the Mac mini quest) carries the work:

- On Darwin, `sh/dispatch.sh` lists only `python3` as the module's tool, and `check:mutants` runs `admin/mutants --pins` only when `cargo-mutants` is on `PATH`, printing a skip notice otherwise. `admin/mutants --expand-diff-self-test` always runs.
- `admin/mutants` maps `Darwin arm64` to `aarch64-apple-darwin`, lists with aarch64 Linux's rows, and refuses a campaign with `macOS has no campaign; it only lists`.
- `quest/m0/mac-mini-runner.md` records the skip and what a Mac without Nix needs: `ALLOW_HOST_TOOLCHAIN=1`, rustup's stable toolchain, each tool `CI_STRICT` names on `PATH`, and `rustup target add` for the cross checks' targets.
- A reviewer's finding to apply: `sh/dispatch.sh` tests `uname -s` for `Darwin` while `admin/mutants` maps only `Darwin arm64`, so an x86_64 shell on a Mac (Rosetta, or an Intel Mac) selects the module and then fails with `no campaign for Darwin x86_64`. Map `Darwin x86_64` too, or test the architecture in `dispatch.sh`, so the two agree.

Measured and tested in #247: with a `uname` stub reporting Darwin arm64, the `mutants` module is selected and needs only python3, `check:mutants` prints the skip notice and passes the self-test, and `admin/mutants -p rind` says macOS only lists; on Linux the module still needs `cargo-mutants` and runs `--pins`. `shellcheck` is clean except an existing note this change does not touch, `sh/alert.sh check`, `sh/pins.sh`, `sh/release-check.sh --check`, `python3 admin/testing`, `quest check`, and `admin/scan-license` pass, and a strict Linux gate passed (exit 0, 1205 s). A review by a model other than the writer scored it 9.4/10 with no High or Medium finding; it reports running `admin/mutants --expand-diff-self-test`, `--pins`, and `--list -p rind` on a Darwin arm64 host, which this quest's author could not confirm. The task that started the work named a rustup `docs` step failing on the Mac; nothing in the repo installs docs through rustup (`cargo doc` needs no `rust-docs` component), and the failure could not be reproduced without its log.

Decision rule, by which the work is taken or refused:

- Take it if one strict gate on a real Mac (Apple silicon, bash 4 or newer first on `PATH`, rustup stable, no Nix) gets past the `mutants` module with this change and fails there without it. That is the whole evidence, since Linux is unchanged.
- Refuse it, and delete this quest, if the Mac gate already passes `mutants` at `main`, or if the Mac mini runner runs the gate in a Linux VM only, so no macOS shell runs it.
- A macOS mutation campaign is not part of this: it needs its own skip list and Apple-core feature rows, and is added only if a run finds what the Linux campaigns miss.

## Waiting

- steelhead99x: run the strict gate on the Mac, which an agent cannot. Options: (A) `git fetch upstream main; CI_STRICT=1 ALLOW_HOST_TOOLCHAIN=1 quest gate sh/dispatch.sh ci upstream/main 2>&1 | tee gate.log` with this change merged, posting the first `error:` or `failed` line if it fails; (B) run only `admin/mutants --expand-diff-self-test`, `--pins`, and `--list -p rind` there, which is what the change touches; (C) skip the check and take the Linux gate and the stub test as enough. Recommendation: A, because the full gate also shows what else a Mac without Nix lacks, which the stub cannot.
- Maintainer: whether macOS ever gets a mutation campaign. Options: (A) no, the Linux campaigns stand and macOS lists and checks pins only; (B) a macOS campaign on the Mac mini once its runner exists, with its own skip list and Apple-core rows. Recommendation: A until a run finds a mutant only a Mac would.

## Related

- [The merge queue runs rind's tests natively on aarch64](/quest/m0/mac-mini-runner.md) - the Mac mini runner that runs this gate
