# [M] Ed25519 verification without ADX is level with RustCrypto

## Goal

On x86_64 CPUs that lack or hide ADX, such as the cloud VPSes MoQ's servers run on, rind's Ed25519 verification is within 10% of the fastest library, from about 1.3x RustCrypto's time on BENCHMARKS.md's `ovh-iad` and `ovh-sea`.

## Plan

[moq-dev/rind#397](https://github.com/moq-dev/rind/pull/397) added two OVH VPSes as report hosts. Their virtual CPUs hide ADX, so rind runs s2n-bignum's verified `_alt` routines, and Ed25519 verification there is 1.3x RustCrypto's time. `benchmarks/gaps.toml`'s no-ADX entry assumed only CPUs older than Broadwell and Zen lack ADX; cloud hypervisors make it common. Decided with the maintainer on 2026-11-06: plan it as an m2 speed quest. Profile where the `_alt` path loses (field multiplication with MULX but no ADX, or the double-scalar multiplication's structure), then pick the fastest permissively licensed source for that tier, preferring a verified one within about 10%, per AGENTS.md. Update the no-ADX gap entry with the finding. Measure on the VPS hosts through `admin/bench-report` (run from `desktop`, where the maintainer's key reaches them) and with ADX denied on the dedicated hosts.
