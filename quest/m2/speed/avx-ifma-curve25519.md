# [L] X25519 and Ed25519 verification run on AVX-IFMA without AVX-512, if the unproven tier is accepted

## Goal

On x86_64 CPUs that have IFMA only as AVX-IFMA (VEX encoding, ymm registers, no AVX-512, such as Arrow Lake), X25519 and Ed25519 verification run pyca/verified-garbage's IFMA routines re-encoded for VEX, instead of s2n-bignum's mulx ones, if the maintainer accepts that the re-encoded bytes are not VG's proven ones and the check in the Plan shows the win on an idle host. Every other CPU keeps the routine it runs now. If the maintainer refuses the unproven tier, or Ed25519 verification measures under 5% faster, this quest's PR records the measurement and deletes the quest, or keeps only X25519.

## Plan

[steelhead99x/rind#178](https://github.com/steelhead99x/rind/pull/178) (`perf/avx-ifma-curve25519`, a fork PR, draft) carries the work. VG's `vg_x25519_ifma` and Ed25519 verification routines take 0.5 to 0.7 of s2n-bignum's time on Zen 4, but rind gates them on `avx512ifma`, so a CPU with only AVX-IFMA (CPUID.7.1:EAX bit 23) runs the slower routine.

Measured in #178 on a Core Ultra 9 275HX (Arrow Lake: AVX-IFMA, no AVX-512), one binary for both variants (`RIND_CPU_DISABLE_avxifma=1` selects the mulx path), A and B interleaved, `rind-bench` against aws-lc-rs in the same run, microseconds per operation. The host was busy, so only 1 round for X25519 and 3 for Ed25519 pass the 1.02 control rule, against the 5 required, and every figure is indicative:

| operation | core | mulx (A) | AVX-IFMA (B) | B over A | aws-lc-rs |
|---|---|---:|---:|---:|---:|
| X25519 generate and agree | E-core, best quiet pair | 35.7 | 26.15 | 0.73 | 37.24 |
| Ed25519 verify | E-core, best quiet pair | 30.02 | 27.29 | 0.91 | 42.22 |
| X25519 | P-core, round 2 (8 rounds, 1 clean) | 20.39 | 18.68 | 0.916 | 22.38 |
| Ed25519 verify | P-core, round 2 | 17.65 | 15.48 | 0.877 | 25.17 |

Over all 8 P-core rounds, unfiltered, B over A has a median of 0.93 (0.81 to 1.01) for X25519 and 0.89 (0.72 to 0.98) for Ed25519 verify. Against aws-lc-rs, X25519 goes from 0.96 to 0.70 on the E-core and Ed25519 verification from 0.71 to 0.65. Zen 5 was not measured, since no host was at hand.

What makes this quest a decision and not only a measurement: the converted routines are not VG's proven bytes. `admin/avx-ifma/convert.py` re-encodes 335 instructions of the ladder and 517 of the verification equation from EVEX to VEX, renames the ladder's three ymm16 to ymm18 accumulators onto registers dead across their range, and spills one around the range where none is (28 spills into a 96-byte frame the ladder allocates, zeroed before each of its 11 `ret`s). Nothing proves the output equal to the input. AGENTS.md's rule is to run the fastest source and plan its proof; this is that case, with one more wrinkle: the verified ✓ for `x25519-ecdh` is lost on the hosts that take the tier (5 host columns of BENCHMARKS.md), until VG ships VEX variants, which would replace the converter and carry a proof.

Decision rule, measured on an idle AVX-IFMA host (a P-core pinned, then an E-core), `main` against #178 merged with `main`, interleaved, 5 rounds with the aws-lc-rs control within 1.02, and on Zen 5 as well if a host with AVX-IFMA turns up:

- Take X25519 if it is at least 5% faster than at `main` and Wycheproof, the differential tests, and `admin/ct-sde` pass on the tier. #178's P-core median is 7%, its E-core 27%.
- Take Ed25519 verification only if it is also at least 5% faster. Below that, dispatch X25519 only, and drop the verification routines and their converter output.
- Refuse it, delete this quest, and record the numbers in ALGORITHMS.md if the maintainer will not accept an unproven tier, or if both fall under 5%: the weight of a generator, 12,000 lines of generated assembly, and a lost ✓ is not worth less than that. The alternative is to wait for VG's own VEX variants, which would land proven. Recommendation below.

If taken, #178's changes land as it carries them:

- `admin/avx-ifma/convert.py`, run by `admin/avx-ifma/generate`, which `admin/regenerate` calls so CI catches drift, produces `rind/src/low/x86_64/avx_ifma/` from VG's vendored `vg_x25519_ifma`, `vg_x25519_exchange_ifma`, `vg_ed25519_verify_equation_ifma`, and `vg_ed25519_verify_avx2_ifma` (the variant without SHA-512 instructions). The output is byte-identical under binutils 2.41 and 2.46. VG's base-point and signing routines use 512-bit registers and stay on s2n-bignum.
- `cpu` gains `avxifma`; `Curve25519AvxIfma` and an aarch64 stub as for `Curve25519Ifma`; `adx_mux::curve25519_x25519` and `mid::ed25519` pick it after the AVX-512 tier. `RIND_CPU_DISABLE_avxifma` is its override, and `build.yml` gains a tier with it denied.
- The ladder allocates its 96-byte frame at entry (`lea -96(%rsp),%rsp`), not the red zone, since Windows has none. A test reads the generated sources for any `(%rsp)` access below the stack pointer.
- Constant time: `admin/ct-sde x25519_avx_ifma` under the Arrow Lake model (`-arl`) gave identical 187,933-line traces for two seeds and differs on the planted leaks; Ed25519 verification takes only public inputs. `admin/ctgrind` cannot cover the tier (valgrind hides ADX, so it is never taken), and `admin/ct-binsec` denies `avxifma` untested.
- The unproven tier shows in `benchmarks/verified.toml` (`x25519-ecdh` reads `!avx512ifma, !avxifma`) and ALGORITHMS.md marks it with ⚡, not ✓.
- Differential: 100,000 X25519 and 10,000 Ed25519 verifications against aws-lc-rs, 0 mismatches and the same result digest with the tier and with it denied; 200 tier tests pass both ways. A second run on 1,000,000 X25519 and 100,000 Ed25519 gave the same.

The proof, if the tier is taken, is not this quest's: it waits for VG's VEX variants (which supersede `admin/avx-ifma`), or becomes its own quest to prove the converter's output equal to VG's Lean-modelled bytes.

Not covered by #178: Zen 5, Windows runs (CI only), the aarch64 stub build, `admin/regenerate` in CI, BINSEC, and a P-core re-run on an idle host.

How this relates to [avoid-zmm](/quest/m2/speed/avoid-zmm.md): avoid-zmm decides whether Intel cores that downclock for 512-bit vectors (Skylake-SP through Tiger Lake) run 256-bit kernels instead of 512-bit ones. This quest adds a tier for cores that have no AVX-512 at all, and runs ymm registers only, so avoid-zmm's rule never applies to it. The two share no code. If avoid-zmm's measurement ever finds ymm-width IFMA routines also slow such a core, that finding covers this tier too. The speed epic's list of work left out raises an RSA tier on AVX-IFMA; this is X25519 and Ed25519 only, and the same evidence caution applies: that quest was left out for lack of an A/B, and this one has one.

## Waiting

- Maintainer: whether rind accepts an unproven tier for X25519 and Ed25519 verification. Options: (A) accept it as `⚡` until VG ships VEX variants, on the rule above; (B) wait for VG's VEX variants and take them proven, dropping the converter, and delete this quest then; (C) accept it for X25519 only, since Ed25519's win is the smaller and the less certain. Recommendation: A, because AGENTS.md says to run the fastest source and plan its proof, and #178's differential, ct-sde, and tier tests are the evidence a reviewer can check; B is the safe default if the ✓ on 5 host columns matters more than a 7 to 27% gain.
- steelhead99x: the idle-host measurement the rule needs, since #178's own runs were on a busy shared machine (1 clean round of 8 on the P-core). Options: (A) 5 clean interleaved rounds on an idle AVX-IFMA host, P-core and E-core, with tables posted in the quest's PR; (B) give the maintainer SSH access to an AVX-IFMA host (Arrow Lake or Alder Lake); (C) take the indicative numbers. Recommendation: A, because the Ed25519 figure is the one near the bar and C risks landing a tier for under 5%. Check: the PR body holds the 5 clean rounds.
- steelhead99x: a run on any second AVX-IFMA core, such as Zen 5 or Lunar Lake, if they hold one; #178 measured Arrow Lake only. Recommendation: skip it unless such a host turns up.

## Related

- [Intel cores that downclock for 512-bit vectors run the 256-bit kernels](/quest/m2/speed/avoid-zmm.md) - the other side of the same instruction-set split
- [x86_64's dual RSAZ IFMA exponentiation is proven](/quest/m4/verified/rsa-x86-ifma.md) - the other proof work on IFMA kernels
