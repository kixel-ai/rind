# [S] No ✓ rests on VG's model keeping a freed stack slot's bytes

## Goal

No VG routine that a ✓ quest proves reads a stack slot in a frame before that frame writes it, or else its ✓ waits until VG's model gives a new frame unknown contents. VG's models keep the bytes below the stack pointer: a slot one frame writes and frees still holds that value in the model when a later frame reads it, though on hardware a signal handler may overwrite it between the two frames.

## Plan

- Found by CodeRabbit on [kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815), against `push`/`alloc` in `proofs/verified-garbage/VerifiedGarbage/TCB/AArch64/Isa.lean`. The x86_64 model's `push`/`alloc` keep memory the same way. VG's own comment there calls this harmless because the contract says nothing about those bytes. That argument does not cover a value the routine itself wrote in an earlier frame.
- For each routine the switch quests vendor, check that every load through the stack pointer or a frame pointer reads a byte its own frame stored first, by walking each frame's stores and loads in VG's assembly text at the pin. Record the result here. If no routine reads first, the ✓ quests are unaffected: delete this quest and its Required lines.
- If one does, the ✓ for it waits on VG's fix, and [the report quest](/quest/m2/verified-garbage/stack-reuse-report.md) carries the reproducer.
