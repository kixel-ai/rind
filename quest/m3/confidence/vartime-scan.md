# [M] No variable-time instruction on a secret path

## Goal

CI disassembles rind's release builds for x86_64, aarch64, and armv7 and fails when a function on a secret path contains an instruction whose latency depends on its operands. That closes the gap ctgrind, `admin/ct-sde`, and `admin/ct-qemu` share. Examples are integer division (DIV/IDIV, UDIV/SDIV), and on some cores multiplications or shifts with data-dependent timing.

## Plan

- Take the instruction lists from published sources: Intel's and Arm's data-independent timing documentation (DOIT and DIT lists) and BearSSL's constant-time notes. Record each list's source.
- Find the secret paths from the `ct_*` tests' marked calls, or by marking secret entry points, and scan everything they reach in the compiled binary, including code the compiler generated, such as a `/` the optimizer kept.
- Include the planted test the other tools use: a deliberate division on a secret must fail the scan.
