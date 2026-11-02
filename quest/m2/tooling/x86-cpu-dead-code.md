# [XS] admin/x86-cpu drops its dead code

## Goal

`admin/x86-cpu` no longer ends in a commented-out workflow generator.

## Plan

From [moq-dev/rind#217](https://github.com/moq-dev/rind/pull/217): delete the
commented-out block at the bottom of `admin/x86-cpu`; `x86-cpu.yml` is
maintained by hand.
