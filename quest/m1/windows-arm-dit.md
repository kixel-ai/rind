# [S] aarch64 Windows runs with DIT

## Goal

On aarch64 Windows, rind enables data-independent timing (DIT) around secret-dependent code whenever the CPU has it, as it does on Linux and macOS, so Bun's Windows on Arm builds keep rind's constant-time guarantee.

## Plan

Raised on 2026-11-05 by [moq-dev/rind#356](https://github.com/moq-dev/rind/pull/356), unverified: `rind/src/low/aarch64/cpu.rs` enables DIT only when `detected!("dit")` reports it, and Rust's feature detection on Windows may never report DIT. Check on the `windows-11-arm` runner whether it is detected and whether the `dit` module's enable runs. If detection is missing, find another way Windows exposes it (see what LLVM, aws-lc, and other libraries do there), or record why it cannot be and what that means for the constant-time guarantee. Add a test that fails if DIT is available but not enabled.
