# [M] An ABI harness checks every assembly routine

## Goal

A test trampoline calls every assembly routine with canaries in the registers its ABI says it must preserve, and fails when a callee-saved register, the stack pointer, or a flag the ABI fixes comes back changed. It runs on x86_64, aarch64, and armv7, on every CPU tier, and a planted clobber fails it. A check fails when a routine has no harness call.

## Plan

Planned from the 2026-11-09 tooling audit. `rind/src/low/inline_assembly_safety.rs` argues these properties in prose; no test checks them. BoringSSL's [`abi_test`](https://boringssl.googlesource.com/boringssl/+/main/crypto/test/abi_test.h) is the model.

What rind trusts today:

- `admin/parse-asm/driver.py` derives each generated block's clobbers from the register names its text mentions, then drops `rbx`, `rsp`, `rbp`, and `rip` on x86_64 (`driver.py:80`) and `x19` and `x29` on aarch64 (`driver.py:141`), which rustc refuses as operands. A routine that writes one must restore it itself, and nothing checks that it does.
- 25 files hold naked routines imported whole from aws-lc: 17 on x86_64, 8 on aarch64, 44 routines in all. Each keeps its own entry, exit, and callee-saved registers, behind `extern "sysv64"` or `extern "C"`. armv7's eight `global_asm!` files are the same.
- 213 `asm!` blocks sit in 200 files. All but five of those files mark their wrappers `#[inline(never)]`, so a trampoline can call the wrapper.

The harness covers:

- callee-saved general and vector registers, including the ones `ignore_clobber` leaves out;
- the stack pointer on return;
- x86_64's direction flag, clear on return;
- `x18`, which Apple, Windows, and Android reserve: canary it where the OS allows. No aarch64 file names it today.

The harness does not cover these; settle each in the same PR:

- A caller-saved register a block writes without declaring it. The wrapper's ABI lets it change, so the boundary shows nothing; only the text scan guards it. Recommended: once [asm-bytes](/quest/m2/verified/asm-bytes.md) lands, compare each generated block's clobbers with its HOL Light theorem's `MAYCHANGE` list. Until then, leave it to the scan.
- The red zone under `options(nostack)`. Ten blocks set it: the 128-bit compares, a prefetch, armv7's zeroing and compare loops, the constant-time trace markers, and MD5's optimizer barrier. None touches the stack today. Recommended: a rule in `admin/parse-asm` or a lint that a `nostack` block holds no `push`, `pop`, `call`, or stack-pointer operand.
- Landing pads. None of the 17 x86_64 naked files holds `endbr64`, and none of the 8 aarch64 ones a `bti`, though dispatch calls them through function pointers. That matters only to a build with `-Z cf-protection=branch` or `-Z branch-protection=bti`, both unstable. Recommended: record it in [PLATFORMS.md](/PLATFORMS.md) as unsupported, and restore aws-lc's markers in `admin/import-aws-lc` when either flag stabilizes.
- Unwind tables, beyond what `apple_routines_open_one_cfi_frame` (`rind/src/low/tests.rs:42`) checks.

Guidance:

- Generate the harness calls for generated files from the `admin/parse-asm` drivers, which know each signature; write the naked routines' by hand.
- These are unit tests: `just ci` runs them on the host's tier, and the nightly tiers inherit them.

## Related

- [rind's assembly is byte-identical to the proven object code](/quest/m2/verified/asm-bytes.md) - its theorems name every register a proven routine may change
