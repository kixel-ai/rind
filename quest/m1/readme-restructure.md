# [M] The README shows how to use rind and links the details

## Goal

After [the pitch and headline](/quest/m1/benchmarks/readme.md), the README
shows a visitor how to use rind (rind-rustls, the direct API, and the other
adapters), carries the copy-paste migration prompt, and invites AI reviews
and contributions through the quest skills. Everything a visitor doesn't need
to decide (the Algorithms table and its sources, CPU requirements and tiers,
the technical details, and the architecture) moves to linked docs.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview. Settled;
don't ask again (✅ is the chosen option):

- Scope: split from the pitch-and-headline quest while iterating on
  [moq-dev/rind#341](https://github.com/moq-dev/rind/pull/341), so that
  quest's PR finishes against an unchanged target ✅ / one quest owns the
  whole README.
- Migration: the README carries the [migration prompt](/quest/m1/migration-prompt.md)
  as is.
- Contributing: the README says AI reviews and contributions are welcome:
  run `/quest-plan` to propose a change, or `/quest-start` to take a backlog
  quest, and links `CONTRIBUTING.md` for the rest (maintainer, 2026-11-04).

Guidance:

- Usage follows the pitch and headline within a screen. The credits to
  Graviola, aws-lc-rs, and the other sources stay, short.
- The moved sections keep their content, and the Algorithms table keeps its
  sources and ✓ columns. Pick the files and names; fix every link into the
  moved sections, including from quests, `MIGRATING.md`, and crate READMEs.

## Required

- [The README sells rind and links the report](/quest/m1/benchmarks/readme.md) - the pitch and headline this builds on
- [A prompt migrates a repo to rind](/quest/m1/migration-prompt.md) - the copy-paste prompt the README carries
