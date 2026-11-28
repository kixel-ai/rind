# [L] Every Lean file in rind's proofs is a module

## Goal

Every Lean file rind writes under `proofs/Rind/` and `proofs/verified-garbage/RindIsa/` starts with `module`, so a proof-only edit rebuilds the edited file and the importers whose public `.olean` it changes, not every file downstream, and each file loads only the public `.olean`s of what it imports.

Non-goals: changing a theorem statement, an axiom, or anything [the TCB ledger](/proofs/README.md#tcb--axiom-ledger) trusts; restructuring files beyond what the conversion needs; VG's vendored files, which change only when `admin/import-vg-models` brings upstream's.

## Plan

Measured 2026-11-27 in [kixel-ai/rind#1176](https://github.com/kixel-ai/rind/pull/1176), on Lean 4.35 and Lake 5.0:

- Lake rebuilds a `module` importer only when the public `.olean` of something it imports changes, but a file without `module` hashes the `.olean.private` of everything it transitively imports, so any edit upstream, even a comment line, rebuilds it. On rind, adding a probe theorem to `Rind/X86_64/Kdf/TypesExternal.lean` and then changing only its proof rebuilt the file and its 5 non-module importers, and skipped its 4 module importers.
- 87 of the 449 files, the shared hubs and the translations among them, are already modules, so converting more hubs one at a time gains little: modeled over every edit to `proofs/Rind/` since 2026-11-04 (1,127 file edits in 172 commits), weighted by each module's build time in CI's `lean` job, a proof-only edit rebuilds 568 s of module build time today, 629 s with no module at all, and 12 s with every file a module. The gain is in the leaves, the large proof files.
- A file that imports all of Mathlib and Aeneas peaks at 4.0 GB as a module and 7.1 GB without `module`, and imports in 6.5 s against 10.6 s. Import is about a fifth of the corpus's profiled build time.
- Lean writes each theorem's axioms into the public `.olean`, so a proof edit that changes them, such as replacing `simp` (`propext`) with `rfl` (none), still rebuilds every importer. Most of rind's proofs use `propext`, `Classical.choice`, and `Quot.sound` alike, so most proof edits keep them.
- A module can import only modules, so convert in import order, roots first: `module`, `public import`, and `@[expose] public section`, as the converted hubs do. Add `import all` only where a proof needs a private declaration's body, and say why beside it.
- Measure CI's `lean` job wall time, the peak RSS of the five largest files, and the rebuild set of a proof-only edit to a hub such as `Rind/RowSelect.lean`, before and after.

## Related

- [Split charon/aeneas Funs.lean per algorithm family, parallelize, and cache](/quest/m2/split-aeneas-extractions.md) - a Rust edit changes the translation's exposed definitions, which this quest cannot cut
