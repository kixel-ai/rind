# The proofs every later proof builds on

## Goal

The groundwork for proving the code rind runs is in place: rind's assembly is byte-identical to the proven object code, the first proofs through `proofs/hol-light/` have landed, and one calibration proof has measured what a hand-written HOL Light proof of unproven assembly costs.

## Plan

Decided with the maintainer on 2026-11-09, after an audit of the whole tree: ✅ these move to m2 (rejected: redefine m3 to hold them, leave them in m3). The settled rules, the strict ✓ and the composition rule among them, stay in [the m3 verified epic](/quest/m3/verified/README.md).

The HOL Light tree itself, `proofs/hol-light/` checked by `admin/prove`, landed in [moq-dev/rind#533](https://github.com/moq-dev/rind/pull/533).

Staging (maintainer, 2026-11-09): ✅ calibrate first, and move the cold tiers to m5 (rejected: calibrate only, leave the 2026-11-07 plan). The [m4 verified epic](/quest/m4/verified/README.md) plans dozens of HOL Light proofs of assembly nobody has proven, with no measured cost. The calibration proof here is the first of them, and every other quest that writes new HOL Light requires it.

## Required

- [rind's assembly is byte-identical to the proven object code](/quest/m2/verified/asm-bytes.md) - the transliteration leaves the trust base, and s2n-bignum's constant-time proofs cover rind
- [The hash and KDF glue's constant-time compares are proven](/quest/m2/verified/hash-glue.md) - the compares behind `hmac::verify` and `pbkdf2::Secret::verify`, in HOL Light
- [HKDF's key conversions are proven](/quest/m2/verified/hkdf-okm.md) - the `From<Okm>` keys QUIC's packet protection starts from
- [aarch64 SHA-256 on the SHA-2 instructions is proven](/quest/m2/verified/sha256-aarch64-hw.md) - the calibration: what a hand-written HOL Light proof of unproven assembly costs
- [The Lean models of CPU intrinsics are tested against the instructions](/quest/m2/verified/simd-models.md) - a model that misreads the manual fails `admin/prove`
