# Confidence quests claimed before the epic moved to m2

## Goal

The confidence quests that open PRs claimed before the epic moved finish from this directory. Once the last has merged, this README is deleted.

## Plan

[The epic](/quest/m2/confidence/README.md) moved to m2 with the maintainer on 2026-11-09, and holds the Goal, the Plan, and every other child. A claimed quest cannot move, since its branch is named after its path, so these stay until their PRs merge.

## Required

- [A differential fuzz target for every primitive](/quest/m3/confidence/fuzz-every-primitive.md) - signing, ciphers, MD5, and GCM's any-IV API compared with aws-lc
- [Mutation testing on armv7](/quest/m3/confidence/mutants-armv7.md) - the code only 32-bit ARM compiles, under qemu-arm
