# [XS] Adopt the human sign-off policy for unsafe, assembly, and proof axioms

## Goal

The repository states which changes need the maintainer's sign-off, so a security reviewer can read what a human has looked at, while day-to-day agent-assisted PRs stay light. The maintainer confirms or adjusts the draft below, and the PR that adopts it adds it to `CONTRIBUTING.md` and, if chosen, a `.github/CODEOWNERS`.

## Plan

[The TCB & Axiom Ledger](/proofs/README.md#tcb--axiom-ledger) and `admin/vg-binding` landed (the 2026-11-21 plan's first two parts); this is what remained, a governance promise only the maintainer can make.

Drafted wording for `CONTRIBUTING.md`, under a new `# Sign-off` heading, which the PR that adopts it copies:

> These changes land only on the maintainer's explicit approval, which an agent never gives itself and a merge queue pick does not imply:
>
> - **`unsafe`**: any added or changed `unsafe` block or `unsafe impl`. The generated `unsafe` table in AUDIT.md moves in the same PR, so the diff shows it.
> - **Assembly**: a hand edit to `asm!`, `naked_asm!`, or `global_asm!` under `rind/src/low/`, or a bump of an importer's `REV` (`admin/import-*`, `thirdparty/s2n-bignum/RIND.md`), which regenerates it.
> - **Proof trust**: a new or changed Lean `axiom`, `bv_decide`, or hand model (an `admin/prove` `check_quote`), the TCB & Axiom Ledger's tables moving, a change to `UNCOVERED` in `admin/vg-binding`, `proofs/hol-light/`, or `admin/prove-bytes`'s allowed differences.
> - **FFI**: a change to an exported `extern "C"` function or its types in rind-dart, rind-openssl, rind-python, or rind-fips.
>
> Everything else, including new safe Rust, tests, docs, and benchmarks, needs no sign-off beyond the queue's checks.

Drafted `.github/CODEOWNERS`, if the maintainer wants the review requested automatically:

```
/rind/src/low/                  @kixelated
/proofs/                        @kixelated
/admin/prove*                   @kixelated
/admin/vg-binding               @kixelated
/admin/ledger                   @kixelated
/admin/import-*                 @kixelated
/thirdparty/s2n-bignum/         @kixelated
/rind-dart/                     @kixelated
/rind-openssl/                  @kixelated
/rind-python/                   @kixelated
/rind-fips/                     @kixelated
```

## Waiting

- Maintainer: confirm, adjust, or reject the policy wording above, and pick how it is enforced. Recommended: ✅ adopt the wording in `CONTRIBUTING.md` and add the `CODEOWNERS` file, so each such PR requests the maintainer's review, without requiring code-owner approval in `main`'s ruleset. Why: GitHub does not let an author approve their own PR, so a required code-owner review would block the maintainer's own PRs on those paths until a second maintainer exists, and the queue pick (`quest merge --land`) already gates every merge on the maintainer. Rejected: requiring code-owner review now (blocks the maintainer's own changes; set it in dotfiles' `bin/repo-settings` once a second owner exists); the wording alone (nothing requests the review); no policy (a reviewer cannot tell what a human has read). Check it is done: `CONTRIBUTING.md` has the `# Sign-off` heading, `.github/CODEOWNERS` exists, and this quest is deleted.
