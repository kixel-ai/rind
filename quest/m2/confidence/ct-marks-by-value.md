# [M] Constant-time marks reach the copy the code reads

## Goal

Every `low::ct` mark reaches the bytes the code goes on to read, under every profile ctgrind builds, so neither valgrind nor BINSEC passes code that reads a secret's unmarked copy (a missed leak) or fails code that reads a public value's still-secret copy (a false alarm).

## Plan

Found on 2026-11-28 by ctgrind's `profile (opt-z)` row in the rind 0.4.0 release check: fat LTO at `opt-level = "z"` decoded ML-KEM-768's encapsulation key from a copy of VG's key generation output that it made before `ct::public_slice` marked the original. `secret_slice` and `public_slice` take a shared reference, which promises the compiler the bytes do not change, while valgrind's mark changes only that address's shadow state and BINSEC's writes only that address. The PR that found it marks that key by value with `ct::into_public`, and `low::ct_binsec`'s module comment states the rule; the other 303 calls of the two keep the hazard.

- `secret_slice` is the dangerous direction: code that reads a copy made before the mark runs on a public value under both harnesses, and a leak there passes silently. `public_slice` fails loudly.
- Recommended: `secret_slice` and `public_slice` take `&mut [T]`, so the compiler must reread the bytes after the mark; a call that holds only a shared reference marks at the owner, or by value with `into_secret` or `into_public`. Rejected: BINSEC declassifying by an `assume` on the value instead of a write, which covers no valgrind run and adds a constraint per declassified byte to every solver query; auditing each new region's disassembly, which no check enforces.
- No call should change what non-test builds run: the marks compile to nothing there.
