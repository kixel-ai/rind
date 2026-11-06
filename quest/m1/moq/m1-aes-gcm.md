# [S] AES-GCM at packet sizes on Apple Silicon is level with aws-lc-rs

## Goal

On Apple M-series CPUs, AES-128-GCM and AES-256-GCM seal and open 1200-1452 B QUIC packets at least as fast as aws-lc-rs.

## Plan

[moq-dev/rind#408](https://github.com/moq-dev/rind/pull/408) runs s2n-bignum's by-8 kernels for AES-128 as well as AES-256 on cores with SHA3, which took M1 from 0.69-0.93x aws-lc-rs's speed at 1200-1452 B to 0.75-1.00x, and is 3-9% faster on Neoverse N2 too. What remains is DIT. On GitHub's `macos-15` (Apple M1, virtual) runner, rind with DIT already set when it is called, so it skips the toggle, runs 0.98-1.15x aws-lc-rs at 1350-1452 B, and as fast as rind with DIT never set; toggling it on and off in each call costs about 50-60 ns, more than the two `msr DIT` cost alone in a loop (9-25 ns). aws-lc-rs never sets DIT. Measure on `macos-15`, comparing only matching `CPU:` lines.

## Waiting

- Maintainer: how rind pays for DIT on Apple cores, which only the maintainer can trade against the 2026-11-06 decision to toggle it once per call. Options: (a) keep the per-call toggle and drop this quest, accepting about 0.75-1.00x aws-lc-rs at packet sizes on M1; (b) leave DIT set on a thread once rind first sets it, which makes every rind call after the first skip the toggle but keeps DIT on for the caller's own code; (c) add a public guard, such as `rind::Dit::hold()`, that sets DIT until dropped, so a QUIC stack holds it across a batch of packets, while rind still toggles it per call for everyone else; or (d) only document that rind skips the toggle when DIT is already set, leaving callers to set it with their own `unsafe` assembly. Recommendation: (c), since it keeps today's default and lets moq opt in where it seals packets. Check: a maintainer comment on [moq-dev/rind#408](https://github.com/moq-dev/rind/pull/408) or an edit here.
