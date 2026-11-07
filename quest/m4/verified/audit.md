# [M] Audit what's left to prove

## Goal

A report lists every operation, backend, and CPU tier still without a ✓ after the [m3 verified epic](/quest/m3/verified/README.md), with the code it runs, what is already proven, and the cheapest route to a proof of that same code, with an effort estimate. It plans one leaf quest per gap under the [epic](/quest/m4/verified/README.md), most-used operations first.

## Plan

- Start from `benchmarks/verified.toml`, the m3 audit ([moq-dev/rind#318](https://github.com/moq-dev/rind/pull/318)), and ALGORITHMS.md's Sources table. Check upstream for proofs published since, such as s2n-bignum's SHA-2 work ([awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450)), new Vale or HACL* routines, and mldsa-native.
- Routes per gap: prove rind's Rust with Aeneas, prove the assembly in HOL Light against s2n-bignum's x86_64 and aarch64 models, or port an existing proof to the code rind runs. Switching sources is a route only when the new one is at least as fast.
- Include the algorithms the [post-quantum](/quest/m4/pq/README.md) and [protocols](/quest/m4/protocols/README.md) epics add as they land.
