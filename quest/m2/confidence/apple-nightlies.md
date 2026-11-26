# [S] Apple-silicon nightlies run on the Mac mini

## Goal

The scheduled jobs that need Apple silicon run on the maintainer's Mac mini instead of GitHub's `macos-latest` runners, wherever that is faster or lets a job run more often or more completely.

## Plan

Planned with the maintainer on 2026-11-10. The Mac mini (Apple M5 Pro, `ssh mini`, admin account `kixelated`, Nix installed, `sudo` needs a password) also runs the merge queue's two aarch64 runners as tart VMs (`admin/mac-mini-runners`, landed in [kixel-ai/rind#1022](https://github.com/kixel-ai/rind/pull/1022)), benchmarks, Apple-silicon nightlies, and agents.

- Survey the workflows' macOS jobs (`build.yml`'s macOS and iOS rows, `dart` rows; `mutants.yml` has no macOS campaign) and move each one that gains from the machine; leave hosted runners where a clean VM matters, such as release builds.
- Keep each moved job under `quest gate` so it shares the machine with the queue and agents.
