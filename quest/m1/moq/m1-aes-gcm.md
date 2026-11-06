# [M] AES-GCM at packet sizes on Apple Silicon is level with aws-lc-rs

## Goal

On Apple M-series CPUs, AES-128-GCM and AES-256-GCM seal and open 1200-1452 B QUIC packets at least as fast as aws-lc-rs, from 0.69-0.89x of its speed today.

## Plan

Found during [moq-dev/rind#393](https://github.com/moq-dev/rind/pull/393), which made short messages on aarch64 a single pass; packet-sized ones still run s2n-bignum's aarch64 kernels, which trail aws-lc-rs on M1 while leading on Neoverse N2. Decided with the maintainer on 2026-11-06: plan it as an m1/moq speed quest. For bulk encryption the fastest source wins outright, with no tie margin for verified code. Profile against aws-lc's aarch64 AES-GCM (its EOR3/SHA3-instruction and by-8 variants) on macos-15 runners, choose per CPU if the best kernel differs between Apple cores and Neoverse, and keep DIT toggled once per call. Measure on GitHub's macos-15 (M1) and ubuntu-24.04-arm (Neoverse N2) runners, comparing only matching `CPU:` lines.
