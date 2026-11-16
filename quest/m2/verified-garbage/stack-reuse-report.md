# [S] VG hears that its stack model keeps a freed frame's bytes

## Goal

pyca/verified-garbage has an issue showing that its models' `alloc` and `push` keep the bytes below the stack pointer. A later frame then reads, in the model, a value an earlier frame wrote and freed, which a signal handler may have overwritten on hardware. The issue proposes giving a newly allocated region unknown contents.

## Plan

- Draft the issue from [the audit quest](/quest/m2/verified-garbage/stack-reuse.md)'s finding: the model lines (`push`/`alloc` in `TCB/AArch64/Isa.lean` and `TCB/X86_64/Isa.lean` at the pinned commit), a two-frame example (`strSp` 7, `free`, `alloc`, `ldrSp`), and any VG routine that reads a slot before its frame writes it.
- Check VG's current main and its open issues first, and drop the report if it is fixed or already reported.
- Post only the draft the maintainer approves; pyca is outside the orgs `AGENTS.md` lets agents post in.

## Waiting

- Maintainer: approve posting the drafted issue to pyca/verified-garbage. An agent may not post outside the kixel-ai, kixelated, and moq-dev orgs without approval, and none stands. Clear it by approving the draft or dropping the report.
