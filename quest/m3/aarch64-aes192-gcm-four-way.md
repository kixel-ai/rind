# [M] AES-192-GCM on aarch64 cores without SHA3 runs aws-lc's four-way kernel, if the assembly is worth it

## Goal

On aarch64 cores with AES and PMULL but no SHA3 (Cortex-A76, A78, Neoverse N1), AES-192-GCM seals and opens past the short pass's lengths with aws-lc's four-way stitched kernel (`aes_gcm_enc_kernel` and `aes_gcm_dec_kernel`), instead of AES-CTR and GHASH in turn, if the maintainer judges that about 3,000 lines of imported assembly for a cipher no TLS or QUIC suite uses are worth the gain. Cores with SHA3 keep the eight-way kernels, and AES-128 and AES-256 are unchanged. If the maintainer refuses it, this quest's PR records the measurement in ALGORITHMS.md and deletes the quest.

## Plan

[steelhead99x/rind#187](https://github.com/steelhead99x/rind/pull/187) (`perf/aarch64-aes192-gcm-4way`, a fork PR) carries the work. On `main`, `low/aarch64/aes_gcm.rs` sends an AES-192 key without the eight-way kernel to the composed path: s2n-bignum's stitched kernels take only AES-128 and AES-256, and aws-lc's AES-192 eight-way one needs SHA3. aws-lc runs its four-way kernel there, which takes any key size.

Measured in #187, rind over aws-lc-rs, medians of interleaved rounds, one pinned core, aws-lc-rs as a same-binary control that moved under 0.2%:

| core | message | `main` | #187 | #187 over `main` |
|---|---|---:|---:|---:|
| A76 (Pi 5, 3 rounds, performance governor) | seal 1200 B | 1.272 | 0.946 | 0.743 |
| A76 | seal 16 KB | 1.298 | 0.995 | 0.766 |
| A76 | open 1200 B | 1.338 | 0.951 | 0.710 |
| A76 | open 16 KB | 1.371 | 0.995 | 0.726 |
| A78AE (Jetson Orin Nano, 5 rounds) | 1200 B to 16 KB | 1.016 to 1.066 | 0.932 to 0.994 | 0.89 to 0.97 |

The 32-byte short path is unchanged (0.405 against 0.404), and AES-128 and AES-256 ran 0.97 to 1.02 of `main`. In the same sweep AES-192-GCM was the largest gap no other open fork PR owned; it is not in `benchmarks/gaps.toml`, since no report host or CPU tier runs a core without SHA3, so it shows only in the fork's runs.

What makes this quest a decision: AES-192 has no TLS 1.3 or QUIC cipher suite, so the gap has little real traffic, and the fix is 4 imported files (`aesv8-gcm-armv8.pl`'s Linux and Apple outputs for encrypt and decrypt, ISC, with OpenSSL's Apache `aesv8-gcm-armv8-unroll8` already in the tree for the eight-way ones), about 3,000 lines of unverified assembly with licence entries in `LICENSE` and its maintained copies. AGENTS.md says to run the fastest source and plan its proof, and to keep only what is worth its weight; these pull opposite ways here.

Decision rule, measured on a Cortex-A76 or A78 at `main` and at #187 merged with `main`, interleaved, one pinned core, same-run aws-lc-rs control:

- Take it if AES-192-GCM seal and open from 1200 B are each at least 5% faster than `main`, AES-128 and AES-256 move under 2%, and the maintainer accepts the 3,000 lines. #187's numbers are 3 to 29%.
- Refuse it, delete this quest, and record the numbers in ALGORITHMS.md's AES-192 paragraph if the maintainer does not accept the assembly for AES-192, or the speedup falls under 5%.

If taken, #187's changes land as it carries them:

- `admin/import-aws-lc` imports the four files, with one deliberate edit: `ldr w17, [x8, #240]` (the round count from aws-lc's `AES_KEY`) becomes `mov w17, #12`, since rind's 13 round keys have no such field. Rerun against aws-lc 5ed12cce, every existing import and all four new files reproduce byte for byte. The kernels are called only for AES-192.
- `aes_gcm.rs` runs the four-way kernel for an AES-192 key when `eight_way` is absent. Its arguments and in-place use match the eight-way kernel's, and it reads the first six H-table entries, as s2n-bignum's do.
- Tests: `kernels_match_composed` and `counter_wraps` check it against vpaes and NEON GHASH around the short path's, the eight-block loop's, and the tail's boundaries, in both directions, with wrong tags, and across a 32-bit counter wrap; `crosschecks::aead::aes_gcm_large` goes to 16 KiB with AAD to 4 KiB, since the differential tests had stopped at 2.3 KB. Under qemu-user with `-cpu cortex-a76` and `neoverse-n1`, 159 tests pass, `-d in_asm` shows the four-way blocks run and the eight-way not (34 against 0), and aws-lc's AEAD, cipher, and GCM vectors, Wycheproof, and 400,000 random cases pass.
- Constant time: `admin/ct-qemu` gains `--deny FEATURE,...` and a CI step that traces `ct_qemu_aes_gcm` with `sha3,sve2` denied, 108,125 identical records under two secrets with the planted-leak controls differing, since the test asserted SHA3 and so never reached these kernels. `admin/ctgrind` on a Raspberry Pi 5 (valgrind 3.24) ran `low::aarch64::aes_gcm`, `mid::aes_gcm`, and `aead` with 0 memcheck errors. BINSEC cannot decode `aese` or `pmull`, so it does not cover them, as for the eight-way kernels.
- The kernels are not verified, like the eight-way AES-192 ones. [The proof quest](/quest/m4/verified/aes-gcm-aarch64-192.md) is widened to name both kernels, so the proof of the AES-192 ✓ covers the four-way pair too; that edit lands in the PR that takes this.
- ALGORITHMS.md's AES-192 paragraph and PLATFORMS.md say which cores run which kernel, with the table above.

Not covered by #187: `admin/mutants --in-diff` as a campaign (one mutant, `replace cipher with ()` at `aes_gcm.rs:252`, which any AES-GCM test fails, needing an aarch64 host), the Apple flavour's assembly (never runs: Apple cores have SHA3), a Jetson ctgrind run, and CI's own ctgrind and `aarch64-qemu` jobs.

## Waiting

- Maintainer: whether about 3,000 lines of imported assembly are worth AES-192-GCM on aarch64 cores without SHA3. Options: (A) take it: it closes a measured 1.27 to 1.37x gap on the A76 and 1.02 to 1.07x on the A78AE, and AGENTS.md says to take the fastest source; (B) refuse it: leave AES-192 on the composed path, delete this quest, and record the measurement in ALGORITHMS.md; (C) take it only if AES-128 and AES-256 also gain on the same cores, which they cannot from this change: they already run the stitched kernel where SHA3 is absent, and #187 adds only the AES-192 case. Recommendation: A, because it closes the one AES gap measured on those cores and reuses the existing kernel dispatch, but it is the maintainer's call; B is defensible given there is no cipher suite for AES-192.
- steelhead99x: rerun the A/B at current `main` on the Pi 5, since #187's base is `529ff5c0`. Options: (A) rerun interleaved and post the table in the quest's PR; (B) give the maintainer SSH access to the Pi 5; (C) take #187's numbers. Recommendation: A, since the rule needs a `main` column and `main` has moved. Check: the PR body holds the table.

## Related

- [aarch64's eight-way AES-192-GCM kernels are proven](/quest/m4/verified/aes-gcm-aarch64-192.md) - the proof of the kernels this one sits beside, widened if this is taken
