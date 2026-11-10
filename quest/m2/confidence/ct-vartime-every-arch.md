# [L] admin/ct-vartime scans every architecture rind builds for

## Goal

`admin/ct-vartime`, in `just ci`, scans every architecture rind builds for, each with a cited list of its variable-time instructions. Today it covers x86_64, aarch64, armv7, loongarch64, and the portable backend forced on x86_64 and armv7. This quest adds PowerPC (`powerpc64le`, `powerpc64`, `powerpc`), `riscv64gc`, big-endian `s390x`, and ARMv6. 32-bit x86 joins when [its target](/quest/m2/adoption/targets/x86.md) lands; whichever of the two lands second adds the other's row.

PLATFORMS.md names each core on these targets whose multiplier, or another instruction rind's secret paths cannot avoid, runs in operand-dependent time, with its source, as rind is not constant-time there.

Non-goals: a masked constant-time multiply for affected cores. It waits for a consumer on such a core.

## Plan

Decided with the maintainer on 2026-11-10, planning the follow-up of [moq-dev/rind#554](https://github.com/moq-dev/rind/pull/554) (PowerPC):

- Scope: ✅ every architecture rind builds for that the scan misses (rejected: PowerPC only; one quest per architecture).
- Early-terminating multiplies: ✅ research each target's multiplier timing per core, keep multiplies out of `VARTIME` as the script already keeps the Pentium 4's shifts out, and name every affected core in PLATFORMS.md (rejected: a masked multiply on affected targets, which slows every user of the target; dropping affected targets). Early-out multiplies are an exploited side channel (Curve25519 key recovery through the Cortex-M3's `UMULL`), and rind's bignum, field, and RSA arithmetic multiply secrets.

Guidance:

- Each target gets a `VARTIME` pattern and `SAMPLES`, sourced like the existing ones: a vendor's data-independent-timing list where one exists (RISC-V's Zkt extension), otherwise its divisions and floating-point arithmetic, as loongarch64's are.
- Likely affected: 32-bit `powerpc` on the PowerPC 750 (G3), whose `mullw`/`mulhw` exit early per BearSSL's [ctmul](https://www.bearssl.org/ctmul.html); check the G4 (74xx) and the e500 and e300 embedded cores. Check ARMv6's ARM1176 too. The 64-bit targets' cores (POWER8 and later, G5, IBM Z, RISC-V application cores) are believed fixed-latency; cite a source for each.
- `rind_vartime_planted`'s divisions must be found on every new target, including those whose division is a compiler routine.
- The `ct-vartime` dev shell needs each new target's standard library.
