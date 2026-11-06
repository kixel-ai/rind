# [S] A caller can hold DIT across a batch, and AES-GCM on Apple Silicon is level with aws-lc-rs while it does

## Goal

rind exports a guard that keeps data-independent timing (DIT) on for the thread that made it until it is dropped, so every rind call under it skips the per-call toggle.
With it held, AES-128-GCM and AES-256-GCM on Apple M-series CPUs seal and open 1200-1452 B QUIC packets at least as fast as aws-lc-rs.
Callers that hold no guard keep today's per-call toggle.

## Plan

Decided with the maintainer on 2026-11-06, in [moq-dev/rind#408](https://github.com/moq-dev/rind/pull/408):

- How rind pays for DIT on Apple cores: public hold guard ✅ (rejected: keep per-call and drop the goal, sticky DIT per thread, document only). MoQ holds it across a batch of packets; everyone else keeps the per-call toggle.
- Scope: kernels now, guard after ✅ (rejected: guard in this PR). That PR landed the by-8 AES-128-GCM kernels on SHA3 cores; this quest builds the guard.

Why: on GitHub's `macos-15` runner (Apple M1, virtual), rind with DIT already set when called runs 0.98-1.15x aws-lc-rs at 1350-1452 B, level with rind never setting DIT, while toggling it in each call costs about 50-60 ns and leaves rind at 0.75-1.00x. aws-lc-rs never sets DIT.

The guard's name and shape are the implementing agent's to propose in the PR, and the maintainer approves them before it lands; put them under the PR's `## Waiting` until then.
A starting proposal, to argue against: `rind::cpu::hold_dit()` returning a `#[must_use]` `rind::cpu::DitGuard`.

- It works through `low`'s existing `enter_cpu_state`/`leave_cpu_state`, so on drop it clears DIT only if it set it, and nested guards and per-call `Entry`s compose.
- It is `!Send` and `!Sync`: DIT is per thread, so dropping it on another thread would clear the wrong one. An async task cannot hold it across an `.await` on a multi-threaded runtime, which is the misuse to refuse.
- It exists on every target, as a no-op where rind sets no DIT (x86_64, armv7, aarch64 cores without it), so callers need no `cfg`.
- One way to do the job: no second spelling such as a closure-taking `with_dit`.

Measure on `macos-15` against aws-lc-rs with the guard held around the benchmark loop, comparing only matching `CPU:` lines, and record the table in the PR. Add the held case to the AES-GCM benchmark only if it earns its runtime.
