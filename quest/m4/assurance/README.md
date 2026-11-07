# rind is continuously tested the way established libraries are

## Goal

rind is fuzzed continuously in OSS-Fuzz, differentially fuzzed against every major library through cryptofuzz, and passes NIST's ACVP test vectors for every algorithm ACVP covers.

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. Each child is concrete enough to start directly. Upstream submissions (google/oss-fuzz, guidovranken/cryptofuzz) need the maintainer's approval before posting, since they're outside the moq-dev and kixelated orgs. ACVP also feeds [the FIPS scope](/quest/m4/fips-scope.md).

## Required

- [rind runs in OSS-Fuzz](/quest/m4/assurance/oss-fuzz.md) - the fuzz crate's targets fuzzed continuously
- [cryptofuzz fuzzes rind](/quest/m4/assurance/cryptofuzz.md) - differential fuzzing against every library cryptofuzz knows
- [rind passes NIST's ACVP vectors](/quest/m4/assurance/acvp.md) - every algorithm ACVP covers
