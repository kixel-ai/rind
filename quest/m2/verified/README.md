# The proofs every later proof builds on

## Goal

The groundwork for proving the code rind runs is in place: rind's assembly is byte-identical to the proven object code, the first proofs through `proofs/hol-light/` have landed, and one calibration proof has measured what a hand-written HOL Light proof of unproven assembly costs.

## Plan

Decided with the maintainer on 2026-11-09, after an audit of the whole tree: ✅ these move to m2 (rejected: redefine m3 to hold them, leave them in m3). The settled rules, the strict ✓ and the composition rule among them, stay in [the m3 verified epic](/quest/m3/verified/README.md).

The HOL Light tree itself, `proofs/hol-light/` checked by `admin/prove`, landed in [moq-dev/rind#533](https://github.com/moq-dev/rind/pull/533).

Staging (maintainer, 2026-11-09): ✅ calibrate first, and move the cold tiers to m5 (rejected: calibrate only, leave the 2026-11-07 plan). The [m4 verified epic](/quest/m4/verified/README.md) plans dozens of HOL Light proofs of assembly nobody has proven, with no measured cost. The calibration proof here is the first of them, and every other quest that writes new HOL Light requires it.

## Required

- [The hash and KDF glue's constant-time compares are proven](/quest/m2/verified/hash-glue.md) - the compares behind `hmac::verify` and `pbkdf2::Secret::verify`, in HOL Light
