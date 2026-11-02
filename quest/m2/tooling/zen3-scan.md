# [XS] Refresh the Zen 3 scan on real hardware

## Goal

`admin/x86-cpus/amd-zen3.json` holds every feature `rind-cpuid` reports since
[moq-dev/rind#217](https://github.com/moq-dev/rind/pull/217), captured on a
real Zen 3, and `x86-cpu.yml`'s AMD comments agree with it.

## Plan

Decided with the maintainer on 2026-11-02: refresh Zen 3 ✅ / leave both AMD
scans.

- `ssh nixos` reaches a Ryzen 9 5900XT (Zen 3) the maintainer allows for
  testing. Run `rind-cpuid` there and commit its output.
- `amd-zen4.json` stays as it is until Zen 4 hardware is available.
