# [S] Intel SDE in a dev shell

## Goal

`admin/x86-cpu` runs Intel SDE scans and forced-CPU tests locally on NixOS
from a dev shell, using the same SDE build `x86-cpu.yml` uses, so local runs
and CI match.

## Plan

Decided with the maintainer on 2026-11-02, from
[moq-dev/rind#217](https://github.com/moq-dev/rind/pull/217): a
`devShells.sde` ✅ / a script fallback to `sde64`.

- `ctz/intel-sde`'s `sde` launcher is 32-bit and does not run on NixOS; #217
  pointed a local `sde` at the 64-bit `sde64` by hand.
- Fetch the same SDE `x86-cpu.yml` uses as a flake input or fixed-output
  derivation, run its 64-bit binary (FHS-wrapped if it needs one), and use
  the shell from both `admin/x86-cpu` and the workflow.
