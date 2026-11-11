# [S] Check Cortex-A53's 64-bit multiply timing

## Goal

PLATFORMS.md says whether Arm's Cortex-A53 multiplies in fixed time, citing a primary source: Arm's documentation, a published measurement, or one rind makes. The A53 runs the Raspberry Pi 3 and Zero 2 W, which PLATFORMS.md names. If its 64-bit `mul`, `umulh`, or `smulh` takes fewer cycles for some operands, it joins the list of cores rind is not constant-time on.

## Plan

Decided with the maintainer on 2026-11-10, while landing [moq-dev/rind#586](https://github.com/moq-dev/rind/pull/586): plan this as a small research quest ✅ (rejected: drop it).

- The lead is secondary: a search snippet citing [arXiv 2311.14246](https://arxiv.org/abs/2311.14246) ("Constant-Time Wasmtime") claims an operand-width timing difference in the A53's 64-bit `mul`. Read the paper and whatever it cites before trusting it.
- The Cortex-A53 Software Optimization Guide, if Arm publishes one, or the TRM may list multiply latencies. A single latency there is weaker evidence than a measurement, since Arm's manuals rarely promise data-independent timing outside DIT, which the A53 lacks.
- If no source settles it, measure on an A53 board with the cycle counter, comparing small against full-width operands for each multiply rind's aarch64 code emits. Without hardware, record the open question in PLATFORMS.md as it does for IBM Z.
- The same answer covers 32-bit `arm` built for an A53, such as the Pi 3 running a 32-bit OS, for `umull` and `smull`.

## Related

- [BINSEC checks the secret paths no proof covers](/quest/m2/confidence/binsec.md) - finds secret-dependent variable-time instructions, but takes the CPU's word on which those are
