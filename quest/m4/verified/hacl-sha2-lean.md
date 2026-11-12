# [M] HACL*'s SHA-2 block functions are proven in Lean

## Goal

The portable backend's SHA-256 and SHA-512 block functions, libcrux-sha2's `sha256_update_nblocks` and `sha512_update_nblocks`, are translated with the rest of the portable backend and proven against FIPS 180-4 in Lean, so `sha256_update_nblocks_spec` and `sha512_update_nblocks_spec` in `proofs/Rind/Portable/Hacl.lean` stop being axioms and the portable SHA-2 ✓ rests on no HACL* theorem.

## Plan

Follows [the portable backend's proofs](https://github.com/moq-dev/rind/pull/649), which took the axiom route because Charon cannot translate the two functions.

Decided 2026-11-12 (maintainer, /quest-unblock): ✅ approve the HACL* axioms route for [moq-dev/rind#649](https://github.com/moq-dev/rind/pull/649), so two restated F* theorems join the trust base, and replace them here once Charon is fixed (rejected: hold that PR until Charon is fixed).

- The blocker: libcrux-macros' `unroll_for!` unrolls each function's 64 or 80 rounds into one deeply nested body, and Charon panics translating it when it reaches its fixed `MAX_STACK_DEPTH` of 1024 (`charon/src/utils.rs`). `admin/prove`'s portable pass therefore leaves them opaque, as Charon leaves other crates' bodies.
- Once Charon translates them, have `admin/prove`'s portable pass translate the two bodies and prove each against `Rind/HashSpec.lean`'s `sha256.compress` and `Rind/Sha2.lean`'s `processBlock`, as `Rind/X86_64/ChaCha20.lean` proves HACL*'s ChaCha20 rounds. The axioms' statements are the theorems to prove, so nothing above `Hacl.lean` changes.
- The unrolled bodies are long straight-line code; if `step*` is slow on them, prove one round as a lemma and let the unrolled body reuse it.

## Waiting

- AeneasVerif/charon: translate a function whose body nests past Charon's fixed `MAX_STACK_DEPTH` without panicking. Check by bumping Charon in `flake.nix` and running the reproduction in `UPSTREAM.md`'s "Charon panics on HACL*'s unrolled SHA-2", which then translates both functions.
- Maintainer: approve filing an issue on AeneasVerif/charon reporting the panic with that reproduction (recommended; Charon's `AGENTS.md` and `CONTRIBUTING.md` set no policy against agent-written issues, and no open issue reports it), or file it yourself. An agent cannot post outside the moq-dev and kixelated orgs without approval. Done once the issue exists and `UPSTREAM.md`'s entry links it.

## Related

- [Every hand model of untranslated Rust is retired](/quest/m4/verified/aeneas-fn-pointers.md) - retires the other places `proofs/` stands in for Rust the translation leaves out
