# [M] ct-vartime's MXCSR scan follows jump tables

## Goal

`admin/ct-vartime` passes or fails on what rind's code does, not on how LLVM lowers it. A `match` that LLVM lowers to a jump table no longer stops the MXCSR scan. The scan follows every target the table can reach, so its coverage of the code that runs outside the MXCSR mitigation is unchanged.

## Plan

Planned with the maintainer on 2026-11-26. On [kixel-ai/rind#1049](https://github.com/kixel-ai/rind/pull/1049)'s head `d7d745ad`, a merge of main at `051feaae`, the PR check failed in `check vartime` ([run 45795091359](https://github.com/kixel-ai/rind/actions/runs/45795091359)) with `ct-vartime: jmp at 0x131 jumps indirectly in <rind::mid::mlkem::MlKem768 as rind::mid::mlkem::Params>::encaps, which the MXCSR scan cannot follow`. That PR changes no ML-KEM code, and the check passed on its next head, `30c24dc0`, after main gained [#1073](https://github.com/kixel-ai/rind/pull/1073) and [#1076](https://github.com/kixel-ai/rind/pull/1076). So the failure is probably deterministic for each tree, not a flake: inlining decides whether a jump table lands in `encaps`, and any unrelated change can bring it back on a PR or the nightly. The `sys.exit` is in `admin/ct-vartime`'s successor walk, from [kixel-ai/rind#969](https://github.com/kixel-ai/rind/pull/969).

- First reproduce it: run `admin/ct-vartime x86_64-unknown-linux-gnu` on `d7d745ad` (and on `051feaae`, to see whether main alone failed), and confirm what the indirect `jmp` is.
- ✅ If it is a jump table, the scan reads the table's entries, from the relocations or the section data, and follows each target (rejected: building the checked code without jump tables, which checks different code from what ships). If the repro shows something else, such as a tail call through a function pointer, say what changed and fix that at its root.
- An indirect jump whose targets the scan cannot bound still fails loudly, as it does now.
- Add a test fixture with a jump table, so this doesn't depend on rind's code happening to produce one.
