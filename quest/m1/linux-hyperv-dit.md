# [S] aarch64 Linux under Hyper-V runs with DIT

## Goal

On aarch64 Linux guests whose hypervisor hides DIT from the kernel, such as Azure Cobalt and GitHub's `ubuntu-24.04-arm` runners, rind enables data-independent timing around secret-dependent code whenever the CPU has it, or the README states exactly where it cannot.

## Plan

[moq-dev/rind#366](https://github.com/moq-dev/rind/pull/366) found that Hyper-V hides DIT from both Windows and Linux, while `mrs DIT` still runs and takes effect. It fixed Windows with a probe scoped to one thread, and recorded the Linux gap in the README. Linux has no scoped equivalent: probing means a library installing a process-wide SIGILL handler, which can race the program's own.

Weigh, with numbers and an adversarial look at each:
- a probe that installs and restores a SIGILL handler around one instruction, and what happens if the program or another thread changes handlers meanwhile;
- probing in a short-lived child process or thread at first use;
- an allowlist of CPU models (`MIDR_EL1`, readable on Linux) known to implement DIT;
- keeping the gap documented.

Ask the maintainer before picking a route that changes process-wide state. Test on the `ubuntu-24.04-arm` runner, with a check like #366's that fails if the CPU has DIT and rind leaves it off.
