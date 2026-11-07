# [S] pyrind's musl and armv7 wheels are tested

## Goal

`python.yml` loads and tests every wheel it publishes. Today the musl wheels
(x86_64 and aarch64) and the armv7 glibc wheel are built and uploaded but
never imported, so a wheel that fails to load or computes wrongly on those
targets reaches PyPI unnoticed.

## Plan

Planned on 2026-11-07, when the maintainer settled
[moq-dev/rind#459](https://github.com/moq-dev/rind/pull/459)'s decisions.

- Run the wheel job's test step (the unit tests, Wycheproof, and mypy
  stubtest) for these three targets, as it runs for the others.
- musl: a musl CPython 3.11 container on the runner that built the wheel,
  which is already the wheel's architecture.
- armv7: an armhf CPython 3.11 container under qemu-user. Check that the run
  lands on a CPU rind supports and say which of rind's armv7 paths it takes.
- Where pyca/cryptography ships no wheel for a target, skip the comparisons
  against it, as the Windows on Arm entry does, rather than building pyca.
- The workflow runs nightly and from the release, never in the merge gate,
  so the emulated job's time costs no PR.
