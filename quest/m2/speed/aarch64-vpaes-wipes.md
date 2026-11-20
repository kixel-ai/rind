# [XS] aarch64's vpaes import drops its register zeroing

## Goal

`admin/import-aws-lc` drops the register zeroing from aws-lc's `vpaes-armv8` key setup, as [kixel-ai/rind#913](https://github.com/kixel-ai/rind/pull/913) did for `vpaes-armv7`, and the regenerated `rind/src/low/aarch64/vpaes_armv8.rs` no longer clears registers on return.

## Plan

- AGENTS.md wipes keys on drop and leaves temporaries unwiped. It keeps an imported wipe only in proven code, and vpaes-armv8 isn't proven. The zeroing costs 8 instructions per key setup.
- Do it in the importer, not by hand. The other imported files must come out byte-identical, as #913 checked.
- ctgrind needs no new coverage, since only stores are removed. Benchmark key setup only if the change is visible; it likely isn't.
