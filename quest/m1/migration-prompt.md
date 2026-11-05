# [S] A prompt migrates a repo to rind

## Goal

A user pastes a short prompt from the README into their coding agent, and the
agent moves their repository from ring or aws-lc-rs to rind on a local branch,
then reports what changed: clean build time, binary size, and the project's
own benchmarks before and after, and whether its tests pass. The agent offers
to open a PR on the user's repository, and to file rind issues for anything
missing or worth adding, and does neither unless the user agrees.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview. Settled;
don't ask again (✅ is the chosen option):

- Mechanism: a prompt only ✅ / a prompt plus a `cargo` migration tool / the
  whole prompt inline in the README. The README's prompt stays a few lines and
  points the agent at a versioned instructions file in this repository, so the
  steps evolve without changing what users copy.
- Ending: a local branch and a before/after report, then offer to open a PR on
  the user's repo and to file rind issues for shortcomings or useful additions
  ✅ / also open the PR unasked / also post results to rind.
- Milestone: m1, with the README rewrite.

Guidance:

- The instructions cover each way a project reaches ring or aws-lc-rs:
  through rustls and the crates above it (install rind-rustls's provider and
  turn off the default provider features), through a crate a `rind-*` adapter
  serves, through ring's API (rename rind-ring), and directly (`MIGRATING.md`
  maps each item). `cargo tree -i` finds where each comes from.
- Check the project's release targets first: rind builds only on x86_64,
  aarch64, and armv7, and not yet on every OS and ABI of those (see
  [platforms](/quest/m1/platforms.md)), so a project that ships
  others stops with that reason rather than migrating part way. Build each
  release target before reporting success.
- A dependency that hard-wires ring or aws-lc-rs with no hook is reported, not
  patched around.
- Measure fairly: the same clean build command and profile before and after,
  the stripped release binary, and the benchmarks the project already has.
- An issue the agent files on rind says an agent wrote it.
- Verify the prompt by running it on two or three real repositories, such as
  the [adoption epic](/quest/m2/adoption/README.md)'s candidates, without
  pushing, and fix what it gets wrong.

## Related

- [The README shows how to use rind](/quest/m1/readme-restructure.md) - carries this prompt
