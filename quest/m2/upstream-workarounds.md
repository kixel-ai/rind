# [M] UPSTREAM.md lists every workaround for someone else's bug

## Goal

A new root `UPSTREAM.md` lists every place rind works around a bug or gap in a tool or dependency it doesn't own: compilers and linkers (rustc, rust-lld, LLVM), analysis tools (valgrind, BINSEC, Aeneas, cargo-mutants), emulators (qemu, SDE), dependencies (libcrux, aws-lc), and CI runner images. Each entry says what breaks, how to see it (a minimal reproducer where one is cheap), the workaround and the files it lives in, whether it is reported upstream (with a link), and what lets the workaround go. Nothing is posted upstream here; [the reporting quest](/quest/m2/upstream-reports.md) does that later.

## Plan

Planned with the maintainer on 2026-11-10, from [moq-dev/rind#554](https://github.com/moq-dev/rind/pull/554)'s suggestion to report two linker bugs: ✅ write every workaround down now and post upstream once rind is more mature (rejected: post the two linker bugs now; drop them).

- ✅ A new root `UPSTREAM.md`, linked from CONTRIBUTING.md (rejected: a section of PLATFORMS.md, since many workarounds are CI and tooling, not platforms; a section of CONTRIBUTING.md, which is always read).
- ✅ Upkeep: CONTRIBUTING.md says a PR that adds a workaround adds its entry, and each workaround's comment names its entry (rejected: a `just ci` check pairing marker comments with entries; nothing extra).
- ✅ m2 (rejected: m3).
- Inventory by reading, not only by grepping "workaround": the code rarely uses the word. Start from `flake.nix`, `.github/workflows/`, `sh/`, `admin/` (including `admin/ctgrind.supp`, `admin/ct-sde`, `admin/ct-qemu`, and `.cargo/mutants.toml`'s excludes), `rind/build.rs`, and `cfg`s or `allow`s in `rind/src` that exist for a toolchain rather than for rind. Known entries:
  - `powerpc64-unknown-linux-gnu` defaults to rust-lld, which cannot link ELFv1 (#554).
  - lld gives undefined weak functions a nonzero address in ppc32 PIEs, crashing on BSS-PLT objects ([moq-dev/rind#580](https://github.com/moq-dev/rind/pull/580)).
  - libcrux-platform calls `__cpuid` outside `unsafe`, holding i686 at Rust 1.94; reported as [celabshq/libcrux#1646](https://github.com/celabshq/libcrux/issues/1646) ([the x86 quest](/quest/m2/adoption/targets/x86.md)).
  - BINSEC cannot decode some of the code rind runs, which stays with `admin/ct-sde` and `admin/ct-qemu` ([the BINSEC quest](/quest/m2/confidence/binsec.md), still open; record the instructions it names once it lands).
  - valgrind on ARM does not fault a read of a guard page so `__ctgrind` builds leave out `low::guard_pages`'s tests ([moq-dev/rind#607](https://github.com/moq-dev/rind/pull/607), from [moq-dev/rind#591](https://github.com/moq-dev/rind/pull/591)).
  - Aeneas cannot translate several kinds of Rust, function-pointer dispatch among them, so `proofs/` models that Rust by hand ([its quest](/quest/m4/verified/aeneas-fn-pointers.md) lists each limitation).
- Leave out what is not someone else's defect: rind's own bugs, deliberate choices (such as refusing hybrid X9.62 points), and plain version pins.
