# [XS] Ask pyca/verified-garbage for looped variants of its largest x86_64 routines

## Goal

pyca/verified-garbage has an issue from rind asking for looped (smaller) variants of the unrolled routines that make up most of what an x86_64 `rustls + rind-rustls` client still carries over `aws-lc-rs`'s, with the sizes that motivate it.

## Plan

Decided 2026-11-24 (maintainer, [kixel-ai/rind#1008](https://github.com/kixel-ai/rind/pull/1008#issuecomment-7140848735)): ✅ ask upstream for looped variants (rejected: dropping an x86_64 tier's RSA or P-256 routine for a lower tier's; swapping `VG_P384_COMB` for rind's smaller table, or benchmarking that swap now).

- Measured 2026-11-26 on main b0cae69, x86_64 Linux: the stripped client is 5.27 MB in a default release against 4.11 MB over `aws-lc-rs`, and rind's part is 3.84 MB in the one-codegen-unit build `admin/binary-size` measures. Measure with `nm -S --size-sort -C target/binary-size/x86_64-unknown-linux-gnu/release/build-cost-rustls` after `admin/binary-size`.
- rind pins pyca/verified-garbage at 0aa40d6 (2026-11-17), and upstream has since shrunk these routines by sharing code ([#6449](https://github.com/pyca/verified-garbage/pull/6449), [#6510](https://github.com/pyca/verified-garbage/pull/6510), [#6282](https://github.com/pyca/verified-garbage/pull/6282)). So the issue cites upstream main's sizes, taken by assembling each routine's `.s` in `crates/verified-garbage-asm-x86_64/assembly`, which matches rind's `nm` at the pin to within 64 bytes.
- What to ask about, by size at upstream 71dee94: the IFMA RSA routines, 273 KB, down from 380 KB at the pin (`vg_rsa_public_precomputed_checked_ifma` 117 KB, `vg_rsa_private_crt_precomputed_ifma` 38 KB and its `ifma512` twin 55 KB, and their shared `vg_rsa_crt_ifma_3072`/`_4096` 64 KB); P-256 ECDSA verification, 158 KB, down from 234 KB (92 KB with IFMA, 53 KB with ADX, and 13 KB of parts they share). Only upstream can shrink them without rind leaving a tier. Say that rind takes a variant only where it measures as fast, so a loop that costs speed does not help.
- Not asked: `VG_P384_COMB`, 338 KB, since a smaller table is a speed trade upstream already made.
- No existing request: searched 2026-11-26; the nearest is [pyca/verified-garbage#2208](https://github.com/pyca/verified-garbage/issues/2208), which rolled SHA-512's rounds, and the draft cites it as precedent.
- What upstream ships arrives through [the upstream run](/quest/m2/upstream-updates.md)'s re-pin, whose PR check's job summary shows the gain against its base; this quest finishes once the issue is filed, and that run's baseline links it.

## Waiting

- Maintainer: post the draft issue in this quest's PR to pyca/verified-garbage, which is outside the orgs agents may post in? Upstream has already shrunk these routines by 183 KB since rind's pin, and the draft asks for looped forms of the 431 KB that remain.
  - Post it as drafted (Recommended) - the largest routines are still 117 KB and 92 KB; upstream has taken rind's reports before (pyca/verified-garbage#5321) and acts on size (pyca/verified-garbage#2208).
  - Wait for the re-pin - take upstream's own 183 KB first and decide after re-measuring, at the risk of asking later.
  - Drop the request - accept the remaining size.

## Related

- [Take what rind's upstreams changed since their pins](/quest/m2/upstream-updates.md)
