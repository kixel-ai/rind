# [XS] An x86_64 bench tier without AVX-512 IFMA

## Goal

`bench.yml` has an x86_64 tier that denies AVX-512 IFMA, so an RSA change's A/B on GitHub's runners measures the AVX2 path whatever CPU a run draws.

## Plan

[moq-dev/rind#351](https://github.com/moq-dev/rind/pull/351) had to re-dispatch its runs until both landed on a CPU without IFMA, since IFMA CPUs take a separate RSA path. Add a tier that denies it through the existing CPU-feature denial the other tiers use, and say in the speed epic which tier an RSA comparison reads.
