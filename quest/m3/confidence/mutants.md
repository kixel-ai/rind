# [M] Mutation testing

## Goal

`cargo-mutants` runs over rind's Rust, and every mutant the tests don't catch is either killed by a new test or recorded with its reason, such as an equivalent mutant or a performance-only change. A slow workflow reruns it on changed files.

## Plan

- Start with the code the proofs don't cover and the glue around assembly: parsing, padding, dispatch, and key setup. Report surviving mutants per module.
- Skip generated and imported code (`admin/parse-asm` output, imported assembly); proofs and differential tests own those.
