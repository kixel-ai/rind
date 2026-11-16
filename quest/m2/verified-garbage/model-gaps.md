# [S] The maintainer sets how ✓ quests treat the gaps reviewers found in VG's models

## Goal

Each gap reviewers have found in VG's ISA models (`proofs/verified-garbage/VerifiedGarbage/`, vendored from VG at the pin `admin/import-vg-models` holds) has the maintainer's ruling on how the ✓ quests treat it, and VG has been told about it if the maintainer approves. These are gaps in what the models allow across instructions, which the cosimulation of single instructions against the CPU cannot catch.

## Plan

Decided without the maintainer (afk, 2026-11-16), on [kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815): ✅ list the gaps here and let the maintainer set how ✓ quests treat them, with every ✓ quest waiting on this quest until then (rejected: a stack-frame rule in the epic that each ✓ quest checks, with the exceptions CodeRabbit asked for, since reviewers kept refining the rule and the bar a ✓ holds is the maintainer's call).

The gaps, at VG `e7b0fe8a82b7777958e078573771d51415f105bb`:

- **Stack slots keep their values after their frame is freed.** `push` and `alloc` in `TCB/AArch64/Isa.lean` keep the bytes below the stack pointer, and so do the x86_64 model's. So in the model, a frame can read a value an earlier frame wrote and freed (`strSp` 7, `free`, `alloc`, `ldrSp` reads 7). On hardware, a signal handler may overwrite those bytes between the two frames. VG's comment there calls this harmless because the contract says nothing of those bytes, but that does not cover a value the routine itself wrote. One option for a ✓ quest: check that each load through the stack pointer, a frame pointer, or an address derived from either reads only bytes its own frame stored, every byte of the load. Excepted would be the return address `call` stores and stack arguments the caller stores. Found by CodeRabbit on #815.
- **`NoResidue` treats undefined flags as equal.** `Outside` in `TCB/X86_64/Residue.lean` counts two `none` flags as the same, though `none` means undefined. `imul` leaves SF and ZF undefined, so `NoResidue` accepts a final state whose flags hardware may set from a secret. rind does not import VG's `NoResidue` theorem: the epic's Plan has rind wipe as its own `wipe` feature says, not by VG's residue rule. So this affects VG, not a rind ✓. Found by CodeRabbit on #815.

Once the maintainer rules, record each ruling here and in the affected ✓ quests' Plans, then delete this quest and its Required lines. A gap found later joins this list.

When posting is approved, draft one issue for pyca/verified-garbage covering both gaps, with the model lines and the examples above. First check VG's current main and its open issues, and drop any gap that is already fixed or reported.

## Waiting

- Maintainer: rule on how ✓ quests treat each gap above. Each sets the bar a VG ✓ holds, which is the maintainer's call, so an agent cannot settle it. Clear it by recording the rulings in this Plan.
- Maintainer: approve posting the drafted issue to pyca/verified-garbage, or drop it. pyca is outside the kixel-ai, kixelated, and moq-dev orgs, where agents need the maintainer's approval to post, and none stands. Clear it by approving the draft or removing this item.
